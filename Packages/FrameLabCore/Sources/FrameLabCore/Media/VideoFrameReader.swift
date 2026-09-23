import Foundation
import AVFoundation
import CoreMedia
import CoreVideo

/// Protocol defining the contract for streaming or seeking video frames.
public protocol VideoFrameReading: Sendable {
    func frames(timeRange: CMTimeRange?) -> AsyncThrowingStream<VideoFrame, Error>
    func seekFrame(at time: CMTime) async throws -> VideoFrame?
    func cancel()
}

/// Robust, asynchronous video frame reader wrapping AVAssetReader and AVAssetImageGenerator.
public final class VideoFrameReader: VideoFrameReading, @unchecked Sendable {
    private let asset: AVAsset
    private let lock = NSLock()
    private var activeAssetReader: AVAssetReader?

    public init(asset: AVAsset) {
        self.asset = asset
    }

    public convenience init(url: URL) {
        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        self.init(asset: asset)
    }

    /// Streams video frames sequentially starting from timeRange (or start of video).
    public func frames(timeRange: CMTimeRange? = nil) -> AsyncThrowingStream<VideoFrame, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let tracks = try await self.asset.loadTracks(withMediaType: .video)
                    guard let videoTrack = tracks.first else {
                        continuation.finish(throwing: FrameLabError.missingVideoTrack)
                        return
                    }

                    let reader = try AVAssetReader(asset: self.asset)
                    if let range = timeRange, range.start.isValid {
                        reader.timeRange = range
                    }

                    // Request 32BGRA pixel buffers with IOSurface backing for zero-copy Metal binding
                    let outputSettings: [String: Any] = [
                        kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                        kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any]
                    ]

                    let trackOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: outputSettings)
                    trackOutput.alwaysCopiesSampleData = false // Avoid unnecessary buffer copies

                    guard reader.canAdd(trackOutput) else {
                        continuation.finish(throwing: FrameLabError.readerFailed("Cannot add track output to AVAssetReader."))
                        return
                    }

                    reader.add(trackOutput)
                    self.setActiveReader(reader)

                    guard reader.startReading() else {
                        let reason = reader.error?.localizedDescription ?? "Failed to start reading."
                        continuation.finish(throwing: FrameLabError.readerFailed(reason))
                        return
                    }

                    var frameIndex: Int64 = 0

                    while !Task.isCancelled && reader.status == .reading {
                        guard let sampleBuffer = trackOutput.copyNextSampleBuffer() else {
                            break
                        }

                        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                        let duration = CMSampleBufferGetDuration(sampleBuffer)

                        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                            let frame = VideoFrame(
                                pixelBuffer: pixelBuffer,
                                presentationTime: pts,
                                duration: duration,
                                frameIndex: frameIndex
                            )
                            continuation.yield(frame)
                            frameIndex += 1
                        }
                    }

                    if Task.isCancelled {
                        reader.cancelReading()
                        continuation.finish(throwing: FrameLabError.cancelled)
                    } else if reader.status == .completed {
                        continuation.finish()
                    } else if reader.status == .failed {
                        let err = reader.error?.localizedDescription ?? "Unknown AVAssetReader failure"
                        continuation.finish(throwing: FrameLabError.readerFailed(err))
                    } else {
                        continuation.finish()
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { [weak self] _ in
                task.cancel()
                self?.cancel()
            }
        }
    }

    /// Random access: seek to an arbitrary frame timestamp using AVAssetImageGenerator.
    public func seekFrame(at time: CMTime) async throws -> VideoFrame? {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        let (cgImage, actualTime) = try await generator.image(at: time)
        guard let pixelBuffer = Self.createPixelBuffer(from: cgImage) else {
            throw FrameLabError.missingPixelBuffer
        }

        return VideoFrame(
            pixelBuffer: pixelBuffer,
            presentationTime: actualTime,
            frameIndex: 0
        )
    }

    private func setActiveReader(_ reader: AVAssetReader?) {
        lock.lock()
        defer { lock.unlock() }
        self.activeAssetReader = reader
    }

    /// Cancels any currently reading asset reader.
    public func cancel() {
        lock.lock()
        defer { lock.unlock() }
        if let reader = activeAssetReader, reader.status == .reading {
            reader.cancelReading()
        }
        activeAssetReader = nil
    }

    /// Converts a CGImage to a 32BGRA CVPixelBuffer.
    public static func createPixelBuffer(from cgImage: CGImage) -> CVPixelBuffer? {
        let width = cgImage.width
        let height = cgImage.height

        var pixelBuffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:] as [String: Any]
        ]

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else {
            return nil
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue // BGRA
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return buffer
    }
}
