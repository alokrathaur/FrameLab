import XCTest
import CoreMedia
@testable import FrameLabCore

final class TimingTests: XCTestCase {

    func testCMTimeFormatting() {
        let t1 = CMTime(seconds: 4.25, preferredTimescale: 1000)
        XCTAssertEqual(t1.formattedTimeString, "00:04.250")

        let t2 = CMTime(seconds: 65.5, preferredTimescale: 1000)
        XCTAssertEqual(t2.formattedTimeString, "01:05.500")

        let tZero = CMTime.zero
        XCTAssertEqual(tZero.formattedTimeString, "00:00.000")

        let tInvalid = CMTime.invalid
        XCTAssertEqual(tInvalid.formattedTimeString, "--:--.---")
    }

    func testTimecodeFormatting() {
        let t1 = CMTime(seconds: 4.5, preferredTimescale: 600)
        // At 30 FPS, 4.5 seconds = 135 frames -> 00:00:04:15
        XCTAssertEqual(t1.timecodeString(frameRate: 30.0), "00:00:04:15")
    }

    func testFrameTimingProgress() {
        let current = CMTime(seconds: 5.0, preferredTimescale: 600)
        let total = CMTime(seconds: 20.0, preferredTimescale: 600)

        let timing = FrameTimingInfo(presentationTimestamp: current, duration: CMTime(seconds: 0.033, preferredTimescale: 600))
        let progress = timing.progressFraction(totalDuration: total)

        XCTAssertEqual(progress, 0.25, accuracy: 0.0001)
    }
}
