import XCTest
import CoreVideo
import CoreMedia
@testable import FrameLabCore

final class ProcessingCorrectnessTests: XCTestCase {

    func testSwiftBaselineCorrectness() async throws {
        // Red pixel in BGRA: B=0, G=0, R=255
        guard let redBuffer = PixelBufferTestUtilities.createSolidColorBuffer(
            width: 16, height: 16, blue: 0, green: 0, red: 255
        ) else {
            XCTFail("Failed to allocate test buffer")
            return
        }

        let processor = SwiftFrameProcessor()
        let result = try await processor.process(redBuffer, presentationTime: .zero)

        let pixel = PixelBufferTestUtilities.readBGRA(from: result.pixelBuffer, x: 0, y: 0)
        XCTAssertNotNil(pixel)
        // BT.601: (77 * 255) >> 8 = 76
        XCTAssertEqual(pixel?.b, 76)
        XCTAssertEqual(pixel?.g, 76)
        XCTAssertEqual(pixel?.r, 76)
        XCTAssertEqual(pixel?.a, 255)
    }

    func testCNativeCorrectness() async throws {
        // Green pixel in BGRA: B=0, G=255, R=0
        guard let greenBuffer = PixelBufferTestUtilities.createSolidColorBuffer(
            width: 16, height: 16, blue: 0, green: 255, red: 0
        ) else {
            XCTFail("Failed to allocate test buffer")
            return
        }

        let processor = CFrameProcessor()
        let result = try await processor.process(greenBuffer, presentationTime: .zero)

        let pixel = PixelBufferTestUtilities.readBGRA(from: result.pixelBuffer, x: 0, y: 0)
        XCTAssertNotNil(pixel)
        // BT.601: (150 * 255) >> 8 = 149
        XCTAssertEqual(pixel?.b, 149)
        XCTAssertEqual(pixel?.g, 149)
        XCTAssertEqual(pixel?.r, 149)
    }

    func testObjCCorrectness() async throws {
        // Blue pixel in BGRA: B=255, G=0, R=0
        guard let blueBuffer = PixelBufferTestUtilities.createSolidColorBuffer(
            width: 16, height: 16, blue: 255, green: 0, red: 0
        ) else {
            XCTFail("Failed to allocate test buffer")
            return
        }

        let processor = ObjCFrameProcessor()
        let result = try await processor.process(blueBuffer, presentationTime: .zero)

        let pixel = PixelBufferTestUtilities.readBGRA(from: result.pixelBuffer, x: 0, y: 0)
        XCTAssertNotNil(pixel)
        // BT.601: (29 * 255) >> 8 = 28
        XCTAssertEqual(pixel?.b, 28)
        XCTAssertEqual(pixel?.g, 28)
        XCTAssertEqual(pixel?.r, 28)
    }

    func testAccelerateCorrectness() async throws {
        // White pixel in BGRA: B=255, G=255, R=255
        guard let whiteBuffer = PixelBufferTestUtilities.createSolidColorBuffer(
            width: 32, height: 32, blue: 255, green: 255, red: 255
        ) else {
            XCTFail("Failed to allocate test buffer")
            return
        }

        let processor = AccelerateFrameProcessor()
        let result = try await processor.process(whiteBuffer, presentationTime: .zero)

        let pixel = PixelBufferTestUtilities.readBGRA(from: result.pixelBuffer, x: 0, y: 0)
        XCTAssertNotNil(pixel)
        // White should map to 255 or 254 (integer rounding)
        XCTAssertGreaterThanOrEqual(pixel?.b ?? 0, 254)
        XCTAssertGreaterThanOrEqual(pixel?.g ?? 0, 254)
        XCTAssertGreaterThanOrEqual(pixel?.r ?? 0, 254)
    }

    func testMetalProcessorCorrectness() async throws {
        guard MetalContext.shared.device != nil else {
            print("Skipping Metal test: No Metal device on this host.")
            return
        }

        guard let whiteBuffer = PixelBufferTestUtilities.createSolidColorBuffer(
            width: 32, height: 32, blue: 255, green: 255, red: 255
        ) else {
            XCTFail("Failed to allocate test buffer")
            return
        }

        let processor = MetalFrameProcessor()
        let result = try await processor.process(whiteBuffer, presentationTime: .zero)

        let pixel = PixelBufferTestUtilities.readBGRA(from: result.pixelBuffer, x: 0, y: 0)
        XCTAssertNotNil(pixel)
        XCTAssertGreaterThanOrEqual(pixel?.b ?? 0, 250)
        XCTAssertGreaterThanOrEqual(pixel?.g ?? 0, 250)
        XCTAssertGreaterThanOrEqual(pixel?.r ?? 0, 250)
    }
}
