import Foundation
import CoreVideo
import CoreMedia

/// Supported frame filtering algorithms and processing pipelines.
public enum FilterType: String, CaseIterable, Identifiable, Sendable {
    case original = "Original"
    case metal = "Metal (GPU)"
    case accelerate = "Accelerate (vImage)"
    case c = "C (Native)"
    case objc = "Objective-C"
    case swift = "Swift (Baseline)"

    public var id: String { rawValue }

    public var shortName: String {
        switch self {
        case .original: return "Original"
        case .metal: return "Metal"
        case .accelerate: return "Accelerate"
        case .c: return "C"
        case .objc: return "Obj-C"
        case .swift: return "Swift"
        }
    }
}

/// Encapsulates the output of a frame processing step with execution timing.
public final class ProcessedFrame: @unchecked Sendable {
    public let pixelBuffer: CVPixelBuffer
    public let presentationTime: CMTime
    public let processingLatencyMs: Double
    public let processorName: String
    public let filterType: FilterType

    public init(
        pixelBuffer: CVPixelBuffer,
        presentationTime: CMTime = .invalid,
        processingLatencyMs: Double = 0.0,
        processorName: String,
        filterType: FilterType
    ) {
        self.pixelBuffer = pixelBuffer
        self.presentationTime = presentationTime
        self.processingLatencyMs = processingLatencyMs
        self.processorName = processorName
        self.filterType = filterType
    }

    public var width: Int {
        CVPixelBufferGetWidth(pixelBuffer)
    }

    public var height: Int {
        CVPixelBufferGetHeight(pixelBuffer)
    }

    public var formattedLatency: String {
        String(format: "%.2f ms", processingLatencyMs)
    }
}

/// Primary abstraction protocol for video frame processing.
public protocol FrameProcessor: Sendable {
    var name: String { get }
    var filterType: FilterType { get }

    /// Processes an input pixel buffer and returns the processed frame.
    func process(_ pixelBuffer: CVPixelBuffer, presentationTime: CMTime) async throws -> ProcessedFrame
}

public extension FrameProcessor {
    func process(_ pixelBuffer: CVPixelBuffer) async throws -> ProcessedFrame {
        try await process(pixelBuffer, presentationTime: .invalid)
    }
}
