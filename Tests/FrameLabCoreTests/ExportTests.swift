import XCTest
import CoreVideo
import CoreGraphics
import ImageIO
@testable import FrameLabCore

final class ExportTests: XCTestCase {

    func testExportToPNGData() throws {
        guard let buffer = PixelBufferTestUtilities.createColorBarsBuffer(width: 120, height: 80) else {
            XCTFail("Failed to allocate color bars buffer")
            return
        }

        let exporter = FrameExporter()
        let data = try exporter.exportToData(pixelBuffer: buffer, format: .png)

        XCTAssertFalse(data.isEmpty)
        // PNG magic number: 0x89 0x50 0x4E 0x47
        let header = [UInt8](data.prefix(4))
        XCTAssertEqual(header, [0x89, 0x50, 0x4E, 0x47])
    }

    func testExportToJPEGFile() throws {
        guard let buffer = PixelBufferTestUtilities.createColorBarsBuffer(width: 120, height: 80) else {
            XCTFail("Failed to allocate color bars buffer")
            return
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_export_\(UUID().uuidString).jpg")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let exporter = FrameExporter()
        try exporter.export(pixelBuffer: buffer, to: tempURL, format: .jpeg, compressionQuality: 0.9)

        XCTAssertTrue(FileManager.default.fileExists(atPath: tempURL.path))
        let attributes = try FileManager.default.attributesOfItem(atPath: tempURL.path)
        let size = (attributes[.size] as? NSNumber)?.intValue ?? 0
        XCTAssertGreaterThan(size, 0)
    }
}
