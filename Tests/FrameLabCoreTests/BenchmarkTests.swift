import XCTest
import CoreVideo
@testable import FrameLabCore

final class BenchmarkTests: XCTestCase {

    func testBenchmarkRunnerExecution() async throws {
        guard let buffer = PixelBufferTestUtilities.createSolidColorBuffer(
            width: 64, height: 64, blue: 120, green: 120, red: 120
        ) else {
            XCTFail("Failed to allocate test buffer")
            return
        }

        let runner = BenchmarkRunner()
        var progressValues: [Double] = []

        let report = try await runner.run(
            on: buffer,
            iterations: 5,
            warmupIterations: 2,
            progress: { p in
                progressValues.append(p)
            }
        )

        XCTAssertFalse(report.results.isEmpty)
        XCTAssertEqual(report.imageDimensions.width, 64)
        XCTAssertEqual(report.imageDimensions.height, 64)
        XCTAssertFalse(progressValues.isEmpty)

        for result in report.results {
            XCTAssertGreaterThanOrEqual(result.minLatencyMs, 0.0)
            XCTAssertGreaterThanOrEqual(result.maxLatencyMs, result.minLatencyMs)
            XCTAssertGreaterThanOrEqual(result.averageLatencyMs, 0.0)
            XCTAssertGreaterThanOrEqual(result.medianLatencyMs, 0.0)
            XCTAssertGreaterThanOrEqual(result.p95LatencyMs, 0.0)
            XCTAssertGreaterThan(result.estimatedFPS, 0.0)
        }
    }
}
