import XCTest
import CoreMedia
@testable import FrameLabCore

final class ConcurrencyTests: XCTestCase {

    func testBoundedPipelineBackpressure() async throws {
        let processor = SwiftFrameProcessor()
        let pipeline = BoundedFramePipeline(processor: processor)

        guard let buffer = PixelBufferTestUtilities.createSolidColorBuffer(
            width: 16, height: 16, blue: 10, green: 20, red: 30
        ) else {
            XCTFail("Failed to allocate buffer")
            return
        }

        let frame1 = VideoFrame(pixelBuffer: buffer, presentationTime: CMTime(seconds: 0.1, preferredTimescale: 600))
        let frame2 = VideoFrame(pixelBuffer: buffer, presentationTime: CMTime(seconds: 0.2, preferredTimescale: 600))
        let frame3 = VideoFrame(pixelBuffer: buffer, presentationTime: CMTime(seconds: 0.3, preferredTimescale: 600))

        // First frame submitted when idle
        let (p1, d1) = await pipeline.submit(frame: frame1)
        XCTAssertTrue(p1)
        XCTAssertFalse(d1)

        // Second frame submitted while first is processing
        let (p2, d2) = await pipeline.submit(frame: frame2)
        XCTAssertFalse(p2)
        XCTAssertFalse(d2)

        // Third frame submitted replaces second frame (drop)
        let (p3, d3) = await pipeline.submit(frame: frame3)
        XCTAssertFalse(p3)
        XCTAssertTrue(d3)

        let dropped = await pipeline.framesDropped
        XCTAssertEqual(dropped, 1)

        let next = await pipeline.popNextOrIdle()
        XCTAssertEqual(next?.presentationTime.seconds, 0.3)
    }

    func testGCDFramePipeline() async throws {
        let gcdPipeline = GCDFramePipeline(maxConcurrentFrames: 1)
        let processor = CFrameProcessor()

        guard let buffer = PixelBufferTestUtilities.createSolidColorBuffer(
            width: 16, height: 16, blue: 50, green: 50, red: 50
        ) else {
            XCTFail("Failed to allocate buffer")
            return
        }

        let frame = VideoFrame(pixelBuffer: buffer, presentationTime: .zero)
        let result = try await gcdPipeline.processAsync(frame: frame, processor: processor)

        XCTAssertNotNil(result.pixelBuffer)
        XCTAssertEqual(result.processorName, processor.name)
    }
}
