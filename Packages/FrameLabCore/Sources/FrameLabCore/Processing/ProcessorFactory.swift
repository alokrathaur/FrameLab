import Foundation
import CoreVideo
import CoreMedia

/// A passthrough processor that forwards the unaltered pixel buffer for original preview.
public final class PassthroughFrameProcessor: FrameProcessor, @unchecked Sendable {
    public let name = "Original (Passthrough)"
    public let filterType: FilterType = .original

    public init() {}

    public func process(_ pixelBuffer: CVPixelBuffer, presentationTime: CMTime) async throws -> ProcessedFrame {
        return ProcessedFrame(
            pixelBuffer: pixelBuffer,
            presentationTime: presentationTime,
            processingLatencyMs: 0.0,
            processorName: name,
            filterType: filterType
        )
    }
}

/// Factory for creating and managing FrameProcessor instances.
public final class ProcessorFactory: Sendable {
    public static func makeProcessor(for type: FilterType) -> any FrameProcessor {
        switch type {
        case .original:
            return PassthroughFrameProcessor()
        case .metal:
            return MetalFrameProcessor()
        case .accelerate:
            return AccelerateFrameProcessor()
        case .c:
            return CFrameProcessor()
        case .objc:
            return ObjCFrameProcessor()
        case .swift:
            return SwiftFrameProcessor()
        }
    }
}
