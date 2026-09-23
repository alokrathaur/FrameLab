import Foundation
import CoreVideo
import CoreMedia
import Accelerate

/// Highly optimized SIMD vector processor utilizing Apple's Accelerate (vImage) framework.
public final class AccelerateFrameProcessor: FrameProcessor, @unchecked Sendable {
    public let name = "Accelerate (vImage)"
    public let filterType: FilterType = .accelerate
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

        var srcVImage = vImage_Buffer(
            data: srcBase,
            height: vImagePixelCount(height),
            width: vImagePixelCount(width),
            rowBytes: CVPixelBufferGetBytesPerRow(pixelBuffer)
        )

        var dstVImage = vImage_Buffer(
            data: dstBase,
            height: vImagePixelCount(height),
            width: vImagePixelCount(width),
            rowBytes: CVPixelBufferGetBytesPerRow(outputBuffer)
        )

        // In vImageMatrixMultiply_ARGB8888, the matrix is organized in column-major order:
        // matrix[0..3]   = source channel 0 weights (Dest B, G, R, A)
        // matrix[4..7]   = source channel 1 weights (Dest B, G, R, A)
        // matrix[8..11]  = source channel 2 weights (Dest B, G, R, A)
        // matrix[12..15] = source channel 3 weights (Dest B, G, R, A)
        let matrix: [Int16]
        if format == kCVPixelFormatType_32BGRA {
            // Source: 0:B, 1:G, 2:R, 3:A
            matrix = [
                29,  29,  29,   0,   // Source B -> (Dest B, G, R, A)
                150, 150, 150,   0,   // Source G -> (Dest B, G, R, A)
                77,  77,  77,   0,   // Source R -> (Dest B, G, R, A)
                0,    0,   0, 256    // Source A -> (Dest B, G, R, A)
            ]
        } else {
            // Source: 0:R, 1:G, 2:B, 3:A
            matrix = [
                77,  77,  77,   0,   // Source R -> (Dest R, G, B, A)
                150, 150, 150,   0,   // Source G -> (Dest R, G, B, A)
                29,  29,  29,   0,   // Source B -> (Dest R, G, B, A)
                0,    0,   0, 256    // Source A -> (Dest R, G, B, A)
            ]
        }

        let divisor: Int32 = 256
        let error = vImageMatrixMultiply_ARGB8888(
            &srcVImage,
            &dstVImage,
            matrix,
            divisor,
            nil,
            nil,
            vImage_Flags(kvImageNoFlags)
        )

        guard error == kvImageNoError else {
            throw FrameLabError.accelerateError(Int(error))
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
