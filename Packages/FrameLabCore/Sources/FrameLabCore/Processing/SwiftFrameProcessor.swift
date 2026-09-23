import Foundation
import CoreVideo
import CoreMedia

/// Baseline CPU processor implemented in pure Swift.
public final class SwiftFrameProcessor: FrameProcessor, @unchecked Sendable {
    public let name = "Swift CPU Baseline"
    public let filterType: FilterType = .swift
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

        let srcBytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let dstBytesPerRow = CVPixelBufferGetBytesPerRow(outputBuffer)
        let isBGRA = (format == kCVPixelFormatType_32BGRA)

        for y in 0..<height {
            let srcRow = srcBase.advanced(by: y * srcBytesPerRow).assumingMemoryBound(to: UInt8.self)
            let dstRow = dstBase.advanced(by: y * dstBytesPerRow).assumingMemoryBound(to: UInt8.self)

            for x in 0..<width {
                let offset = x * 4
                let c0 = UInt32(srcRow[offset + 0])
                let c1 = UInt32(srcRow[offset + 1])
                let c2 = UInt32(srcRow[offset + 2])
                let a  = srcRow[offset + 3]

                let gray: UInt8
                if isBGRA {
                    // c0 = Blue, c1 = Green, c2 = Red
                    gray = UInt8((29 * c0 + 150 * c1 + 77 * c2) >> 8)
                } else {
                    // c0 = Red, c1 = Green, c2 = Blue
                    gray = UInt8((77 * c0 + 150 * c1 + 29 * c2) >> 8)
                }

                dstRow[offset + 0] = gray
                dstRow[offset + 1] = gray
                dstRow[offset + 2] = gray
                dstRow[offset + 3] = a
            }
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
