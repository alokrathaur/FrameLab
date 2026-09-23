import Foundation
import os

/// Instruments signposts and telemetry for Apple Instruments (Points of Interest / Time Profiler).
public final class FrameLabSignpost: Sendable {
    public static let shared = FrameLabSignpost()

    private let logger = Logger(subsystem: "com.framelab.app", category: "Telemetry")
    private let signposter = OSSignposter(subsystem: "com.framelab.app", category: "ProcessingPipeline")

    public func beginDecode(frameIndex: Int64) -> OSSignpostIntervalState {
        signposter.beginInterval("FrameDecode", id: signposter.makeSignpostID(), "Frame \(frameIndex)")
    }

    public func endDecode(_ state: OSSignpostIntervalState) {
        signposter.endInterval("FrameDecode", state)
    }

    public func beginProcessing(name: String, frameIndex: Int64) -> OSSignpostIntervalState {
        signposter.beginInterval("FrameProcessing", id: signposter.makeSignpostID(), "\(name) on frame \(frameIndex)")
    }

    public func endProcessing(_ state: OSSignpostIntervalState) {
        signposter.endInterval("FrameProcessing", state)
    }

    public func beginRender(frameIndex: Int64) -> OSSignpostIntervalState {
        signposter.beginInterval("RenderDisplay", id: signposter.makeSignpostID(), "Render frame \(frameIndex)")
    }

    public func endRender(_ state: OSSignpostIntervalState) {
        signposter.endInterval("RenderDisplay", state)
    }

    public func logDropFrame(index: Int64, reason: String) {
        logger.warning("Dropped frame \(index): \(reason, privacy: .public)")
    }
}
