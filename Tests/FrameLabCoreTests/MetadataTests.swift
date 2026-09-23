import XCTest
import CoreMedia
import AVFoundation
@testable import FrameLabCore

final class MetadataTests: XCTestCase {

    func testCodecNameDecoding() {
        XCTAssertEqual(VideoAssetService.fourCCToCodecName(kCMVideoCodecType_H264), "H.264 / AVC")
        XCTAssertEqual(VideoAssetService.fourCCToCodecName(kCMVideoCodecType_HEVC), "H.265 / HEVC")
        XCTAssertEqual(VideoAssetService.fourCCToCodecName(kCMVideoCodecType_AppleProRes422), "Apple ProRes 422")
    }

    func testSyntheticVideoMetadataExtraction() async throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_meta_\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        _ = try await PixelBufferTestUtilities.createSyntheticVideo(
            at: tempURL,
            durationSeconds: 1.0,
            fps: 30,
            width: 320,
            height: 240
        )

        let service = VideoAssetService()
        let metadata = try await service.extractMetadata(from: tempURL)

        XCTAssertEqual(metadata.dimensions.width, 320)
        XCTAssertEqual(metadata.dimensions.height, 240)
        XCTAssertEqual(metadata.nominalFrameRate, 30.0, accuracy: 1.0)
        XCTAssertEqual(metadata.durationSeconds, 1.0, accuracy: 0.1)
        XCTAssertEqual(metadata.videoCodec, "H.264 / AVC")
        XCTAssertEqual(metadata.resolutionString, "320 × 240")
    }

    func testVideoFrameReaderStreaming() async throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_read_\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        _ = try await PixelBufferTestUtilities.createSyntheticVideo(
            at: tempURL,
            durationSeconds: 0.5,
            fps: 30,
            width: 160,
            height: 120
        )

        let reader = VideoFrameReader(url: tempURL)
        var count = 0

        for try await frame in reader.frames() {
            XCTAssertNotNil(frame.pixelBuffer)
            XCTAssertTrue(frame.presentationTime.isValid)
            count += 1
        }

        // At 30 FPS for 0.5s, should read ~15 frames
        XCTAssertGreaterThanOrEqual(count, 14)
    }
}
