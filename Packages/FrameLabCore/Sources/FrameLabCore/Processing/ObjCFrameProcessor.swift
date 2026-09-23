import Foundation
import CoreVideo
import CoreMedia
import FrameLabObjC

/// Processor wrapping the Objective-C native bridge.
public final class ObjCFrameProcessor: FrameProcessor, @unchecked Sendable {
    public let name = "Objective-C Wrapper"
    public let filterType: FilterType = .objc
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

        // Lock both buffers
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

        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        do {
            try FrameLabObjCProcessor.processBGRABytes(
                srcBase.assumingMemoryBound(to: UInt8.self),
                output: dstBase.assumingMemoryBound(to: UInt8.self),
                width: width,
                height: height,
                bytesPerRow: bytesPerRow
            )
        } catch {
            throw FrameLabError.objcProcessingFailed(error.localizedDescription)
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
