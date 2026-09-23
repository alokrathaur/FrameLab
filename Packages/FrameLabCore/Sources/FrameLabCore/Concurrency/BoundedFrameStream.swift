import Foundation
import CoreMedia

/// Actor managing backpressure and cooperative frame dropping for real-time video playback.
public actor BoundedFramePipeline {
    private var isProcessing = false
    private var pendingFrame: VideoFrame?
    private var processor: any FrameProcessor

    public private(set) var totalFramesRead: Int64 = 0
    public private(set) var framesProcessed: Int64 = 0
    public private(set) var framesDropped: Int64 = 0

    public init(processor: any FrameProcessor) {
        self.processor = processor
    }

    /// Updates the active processor.
    public func setProcessor(_ newProcessor: any FrameProcessor) {
        self.processor = newProcessor
    }

    /// Enqueues a candidate frame. If a frame is currently processing, replaces any stale
    /// pending frame with the latest frame, effectively dropping stale intermediate frames.
    public func submit(frame: VideoFrame) -> (shouldProcessImmediately: Bool, dropped: Bool) {
        totalFramesRead += 1

        if isProcessing {
            var dropped = false
            if pendingFrame != nil {
                framesDropped += 1
                dropped = true
            }
            pendingFrame = frame
            return (false, dropped)
        } else {
            isProcessing = true
            return (true, false)
        }
    }

    /// Retrieves the next frame to process, or marks the pipeline idle if none pending.
    public func popNextOrIdle() -> VideoFrame? {
        if let next = pendingFrame {
            pendingFrame = nil
            isProcessing = true
            return next
        } else {
            isProcessing = false
            return nil
        }
    }

    /// Processes a frame and yields the result. Loops while newer pending frames exist.
    public func process(frame: VideoFrame) async throws -> ProcessedFrame {
        defer {
            framesProcessed += 1
        }
        return try await processor.process(frame.pixelBuffer, presentationTime: frame.presentationTime)
    }

    /// Resets all counters and queued frames upon seek or stop.
    public func reset() {
        pendingFrame = nil
        isProcessing = false
        totalFramesRead = 0
        framesProcessed = 0
        framesDropped = 0
    }
}
