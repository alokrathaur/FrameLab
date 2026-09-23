import Foundation
import CoreMedia

public extension CMTime {
    /// Canonical media-time representation formatted as MM:SS.mmm
    var formattedTimeString: String {
        guard self.isValid && !self.isIndefinite else { return "--:--.---" }
        let totalSeconds = self.seconds
        guard !totalSeconds.isNaN && !totalSeconds.isInfinite && totalSeconds >= 0 else { return "00:00.000" }

        let totalMs = Int((totalSeconds * 1000.0).rounded())
        let ms = totalMs % 1000
        let s = (totalMs / 1000) % 60
        let m = (totalMs / 60000)

        return String(format: "%02d:%02d.%03d", m, s, ms)
    }

    /// Format as HH:MM:SS:FF standard SMPTE timecode at specified frame rate
    func timecodeString(frameRate: Float = 30.0) -> String {
        guard self.isValid && !self.isIndefinite && frameRate > 0 else { return "00:00:00:00" }
        let totalSeconds = max(0.0, self.seconds)
        let totalFrames = Int64((totalSeconds * Double(frameRate)).rounded())

        let fpsInt = Int64(frameRate.rounded())
        let frames = totalFrames % max(1, fpsInt)
        let totalSecs = totalFrames / max(1, fpsInt)
        let secs = totalSecs % 60
        let mins = (totalSecs / 60) % 60
        let hours = totalSecs / 3600

        return String(format: "%02lld:%02lld:%02lld:%02lld", hours, mins, secs, frames)
    }
}

/// Timing information encapsulating a video frame's position and duration in media space.
public struct FrameTimingInfo: Sendable, Equatable {
    public let presentationTimestamp: CMTime
    public let duration: CMTime
    public let nominalFrameRate: Float
    public let frameIndex: Int64

    public init(
        presentationTimestamp: CMTime,
        duration: CMTime = .invalid,
        nominalFrameRate: Float = 30.0,
        frameIndex: Int64 = 0
    ) {
        self.presentationTimestamp = presentationTimestamp
        self.duration = duration
        self.nominalFrameRate = nominalFrameRate
        self.frameIndex = frameIndex
    }

    public var formattedTimestamp: String {
        presentationTimestamp.formattedTimeString
    }

    public var seconds: Double {
        presentationTimestamp.isValid ? presentationTimestamp.seconds : 0.0
    }

    public func progressFraction(totalDuration: CMTime) -> Double {
        guard presentationTimestamp.isValid && totalDuration.isValid && totalDuration.seconds > 0 else {
            return 0.0
        }
        return min(max(0.0, presentationTimestamp.seconds / totalDuration.seconds), 1.0)
    }
}
