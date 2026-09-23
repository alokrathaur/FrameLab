import Foundation
import CoreVideo

/// High-performance CVPixelBufferPool wrapper to eliminate per-frame heap allocations.
public final class PixelBufferPool: @unchecked Sendable {
    private var poolRef: CVPixelBufferPool?
    private let lock = NSLock()
    public let width: Int
    public let height: Int
    public let pixelFormat: OSType

    public init(width: Int, height: Int, pixelFormat: OSType = kCVPixelFormatType_32BGRA) {
        self.width = width
        self.height = height
        self.pixelFormat = pixelFormat
        self.poolRef = Self.createPool(width: width, height: height, pixelFormat: pixelFormat)
    }

    deinit {
        // CVPixelBufferPool is CFTypeRef, ARC handles CFRelease automatically in Swift
    }

    /// Obtains a retained CVPixelBuffer from the pool.
    public func createPixelBuffer() -> CVPixelBuffer? {
        lock.lock()
        defer { lock.unlock() }

        guard let pool = poolRef else { return nil }

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)

        if status == kCVReturnSuccess, let buffer = pixelBuffer {
            return buffer
        }
        return nil
    }

    /// Flushes any idle unreferenced buffers in the pool.
    public func flush() {
        lock.lock()
        defer { lock.unlock() }
        if let pool = poolRef {
            CVPixelBufferPoolFlush(pool, .excessBuffers)
        }
    }

    private static func createPool(width: Int, height: Int, pixelFormat: OSType) -> CVPixelBufferPool? {
        let poolAttributes: [CFString: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey: 3,
            kCVPixelBufferPoolMaximumBufferAgeKey: 1.0
        ]

        let pixelBufferAttributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: pixelFormat,
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:] as [String: Any] // Enable zero-copy GPU mapping
        ]

        var pool: CVPixelBufferPool?
        let status = CVPixelBufferPoolCreate(
            kCFAllocatorDefault,
            poolAttributes as CFDictionary,
            pixelBufferAttributes as CFDictionary,
            &pool
        )

        return (status == kCVReturnSuccess) ? pool : nil
    }
}
