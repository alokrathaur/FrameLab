import Foundation
import CoreVideo
import CoreMedia
import AVFoundation

/// Utilities for creating synthetic test pixel buffers and test video assets.
public final class PixelBufferTestUtilities: Sendable {

    /// Creates a 32BGRA CVPixelBuffer filled with a solid color.
    public static func createSolidColorBuffer(
        width: Int,
        height: Int,
        blue: UInt8,
        green: UInt8,
        red: UInt8,
        alpha: UInt8 = 255,
        format: OSType = kCVPixelFormatType_32BGRA
    ) -> CVPixelBuffer? {
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
            format,
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

        for y in 0..<height {
            let row = baseAddress.advanced(by: y * bytesPerRow).assumingMemoryBound(to: UInt8.self)
            for x in 0..<width {
                let offset = x * 4
                if format == kCVPixelFormatType_32BGRA {
                    row[offset + 0] = blue
                    row[offset + 1] = green
                    row[offset + 2] = red
                    row[offset + 3] = alpha
                } else {
                    row[offset + 0] = red
                    row[offset + 1] = green
                    row[offset + 2] = blue
                    row[offset + 3] = alpha
                }
            }
        }

        return buffer
    }

    /// Creates a 32BGRA CVPixelBuffer rendered with color bars (White, Yellow, Cyan, Green, Magenta, Red, Blue, Black).
    public static func createColorBarsBuffer(width: Int = 640, height: Int = 360) -> CVPixelBuffer? {
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

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)

        // 8 standard SMPTE color bars: (B, G, R)
        let colors: [(b: UInt8, g: UInt8, r: UInt8)] = [
            (255, 255, 255), // White
            (0, 255, 255),   // Yellow
            (255, 255, 0),   // Cyan
            (0, 255, 0),     // Green
            (255, 0, 255),   // Magenta
            (0, 0, 255),     // Red
            (255, 0, 0),     // Blue
            (0, 0, 0)        // Black
        ]

        let barWidth = max(1, width / colors.count)

        for y in 0..<height {
            let row = baseAddress.advanced(by: y * bytesPerRow).assumingMemoryBound(to: UInt8.self)
            for x in 0..<width {
                let colorIndex = min(x / barWidth, colors.count - 1)
                let c = colors[colorIndex]
                let offset = x * 4
                row[offset + 0] = c.b
                row[offset + 1] = c.g
                row[offset + 2] = c.r
                row[offset + 3] = 255
            }
        }

        return buffer
    }

    /// Reads pixel color components (B, G, R, A) from a locked 32BGRA buffer.
    public static func readBGRA(from buffer: CVPixelBuffer, x: Int, y: Int) -> (b: UInt8, g: UInt8, r: UInt8, a: UInt8)? {
        guard x >= 0 && x < CVPixelBufferGetWidth(buffer) && y >= 0 && y < CVPixelBufferGetHeight(buffer) else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let row = baseAddress.advanced(by: y * bytesPerRow).assumingMemoryBound(to: UInt8.self)
        let offset = x * 4

        return (row[offset + 0], row[offset + 1], row[offset + 2], row[offset + 3])
    }

    /// Creates a valid synthetic .mp4 video file using AVAssetWriter.
    public static func createSyntheticVideo(
        at outputURL: URL,
        durationSeconds: Double = 1.0,
        fps: Int32 = 30,
        width: Int = 320,
        height: Int = 240
    ) async throws -> URL {
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }

        let assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ]

        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerInput.expectsMediaDataInRealTime = false

        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height
        ]

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: sourcePixelBufferAttributes
        )

        guard assetWriter.canAdd(writerInput) else {
            throw FrameLabError.invalidAsset("Cannot add input to AVAssetWriter.")
        }
        assetWriter.add(writerInput)

        guard assetWriter.startWriting() else {
            throw FrameLabError.invalidAsset(assetWriter.error?.localizedDescription ?? "Start writing failed.")
        }

        assetWriter.startSession(atSourceTime: .zero)

        let totalFrames = Int(durationSeconds * Double(fps))

        for frameNumber in 0..<totalFrames {
            while !writerInput.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 5_000_000)
            }

            guard let buffer = createColorBarsBuffer(width: width, height: height) else {
                continue
            }

            let presentationTime = CMTime(value: CMTimeValue(frameNumber), timescale: fps)
            adaptor.append(buffer, withPresentationTime: presentationTime)
        }

        writerInput.markAsFinished()
        await assetWriter.finishWriting()

        guard assetWriter.status == .completed else {
            throw FrameLabError.invalidAsset(assetWriter.error?.localizedDescription ?? "Finish writing failed.")
        }

        return outputURL
    }
}
