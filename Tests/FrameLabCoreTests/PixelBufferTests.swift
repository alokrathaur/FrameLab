import XCTest
import CoreVideo
@testable import FrameLabCore

final class PixelBufferTests: XCTestCase {

    func testPixelBufferCreationAndStride() {
        let buffer = PixelBufferTestUtilities.createSolidColorBuffer(
            width: 100,
            height: 50,
            blue: 200,
            green: 150,
            red: 100
        )
        XCTAssertNotNil(buffer)

        guard let buf = buffer else { return }
        XCTAssertEqual(CVPixelBufferGetWidth(buf), 100)
        XCTAssertEqual(CVPixelBufferGetHeight(buf), 50)
        XCTAssertGreaterThanOrEqual(CVPixelBufferGetBytesPerRow(buf), 400)

        let pixel = PixelBufferTestUtilities.readBGRA(from: buf, x: 10, y: 10)
        XCTAssertNotNil(pixel)
        XCTAssertEqual(pixel?.b, 200)
        XCTAssertEqual(pixel?.g, 150)
        XCTAssertEqual(pixel?.r, 100)
        XCTAssertEqual(pixel?.a, 255)
    }

    func testPixelBufferPoolReuse() {
        let pool = PixelBufferPool(width: 320, height: 240)
        let buf1 = pool.createPixelBuffer()
        XCTAssertNotNil(buf1)

        let buf2 = pool.createPixelBuffer()
        XCTAssertNotNil(buf2)

        pool.flush()
    }
}
