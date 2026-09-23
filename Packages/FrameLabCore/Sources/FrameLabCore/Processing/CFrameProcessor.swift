import Foundation
import CoreVideo
import CoreMedia
import FrameLabC

/// High-speed native CPU processor calling C routines directly from Swift.
public final class CFrameProcessor: FrameProcessor, @unchecked Sendable {
    public let name = "C Native Processor"
    public let filterType: FilterType = .c
    private var bufferPool: PixelBufferPool?
    private let lock = NSLock()

    public init() {}

    public func process(_ pixelBuffer: CVPixelBuffer, presentationTime: CMTime) async throws -> ProcessedFrame {
        let startTime = ContinuousClock.now

        let format = CVPixelBufferGetPixelFormatType(pixelBuffer)
        guard format == kCVPixelFormatType_32BGRA || format == kCVPixelFormatType_32RGBA else {
            throw FrameLabError.unsupportedPixelFormat(format)
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        guard width > 0 && height > 0 else {
            throw FrameLabError.invalidDimensions(width: width, height: height)
        }

        let outputBuffer = try getOrCreateOutputBuffer(width: width, height: height, format: format)

        let lockStatusSrc = CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        guard lockStatusSrc == kCVReturnSuccess else {
            throw FrameLabError.bufferLockFailed(lockStatusSrc)
        }
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let lockStatusDst = CVPixelBufferLockBaseAddress(outputBuffer, [])
        guard lockStatusDst == kCVReturnSuccess else {
            throw FrameLabError.bufferLockFailed(lockStatusDst)
        }
        defer { CVPixelBufferUnlockBaseAddress(outputBuffer, []) }

        guard let srcBase = CVPixelBufferGetBaseAddress(pixelBuffer),
              let dstBase = CVPixelBufferGetBaseAddress(outputBuffer) else {
            throw FrameLabError.missingPixelBuffer
        }

        let bytesPerRow = Int32(CVPixelBufferGetBytesPerRow(pixelBuffer))

        if format == kCVPixelFormatType_32BGRA {
            fl_grayscale_bgra(
                srcBase.assumingMemoryBound(to: UInt8.self),
                dstBase.assumingMemoryBound(to: UInt8.self),
                Int32(width),
                Int32(height),
                bytesPerRow
            )
        } else {
            fl_grayscale_rgba(
                srcBase.assumingMemoryBound(to: UInt8.self),
                dstBase.assumingMemoryBound(to: UInt8.self),
                Int32(width),
                Int32(height),
                bytesPerRow
            )
        }

        let elapsedTime = ContinuousClock.now - startTime
        let latencyMs = Double(elapsedTime.components.attoseconds) / 1_000_000_000_000_000.0 + Double(elapsedTime.components.seconds) * 1000.0

        return ProcessedFrame(
            pixelBuffer: outputBuffer,
            presentationTime: presentationTime,
            processingLatencyMs: latencyMs,
            processorName: name,
            filterType: filterType
        )
    }

    private func getOrCreateOutputBuffer(width: Int, height: Int, format: OSType) throws -> CVPixelBuffer {
        lock.lock()
        defer { lock.unlock() }

        if let pool = bufferPool, pool.width == width, pool.height == height, pool.pixelFormat == format {
            if let buf = pool.createPixelBuffer() {
                return buf
            }
        }

        let newPool = PixelBufferPool(width: width, height: height, pixelFormat: format)
        self.bufferPool = newPool
        if let buf = newPool.createPixelBuffer() {
            return buf
        }

        throw FrameLabError.missingPixelBuffer
    }
}
