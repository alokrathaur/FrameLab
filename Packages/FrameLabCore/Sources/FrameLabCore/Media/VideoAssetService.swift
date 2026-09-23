import Foundation
import AVFoundation
import CoreMedia

/// Service responsible for loading and extracting structured metadata from AVAsset instances.
public final class VideoAssetService: Sendable {
    public init() {}

    /// Extracts VideoMetadata from a given local video URL.
    public func extractMetadata(from url: URL) async throws -> VideoMetadata {
        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        return try await extractMetadata(from: asset, fileURL: url)
    }

    /// Extracts VideoMetadata from an AVAsset.
    public func extractMetadata(from asset: AVAsset, fileURL: URL? = nil) async throws -> VideoMetadata {
        // Load duration and tracks asynchronously using modern AVFoundation concurrency
        let duration = try await asset.load(.duration)
        let tracks = try await asset.loadTracks(withMediaType: .video)

        guard let videoTrack = tracks.first else {
            throw FrameLabError.missingVideoTrack
        }

        async let naturalSizeTask = videoTrack.load(.naturalSize)
        async let frameRateTask = videoTrack.load(.nominalFrameRate)
        async let bitrateTask = videoTrack.load(.estimatedDataRate)
        async let formatDescriptionsTask = videoTrack.load(.formatDescriptions)
        async let transformTask = videoTrack.load(.preferredTransform)

        let naturalSize = try await naturalSizeTask
        let nominalFPS = try await frameRateTask
        let estimatedBitrate = try await bitrateTask
        let formatDescriptions = try await formatDescriptionsTask
        let transform = try await transformTask

        // Handle video orientation transform (e.g. portrait video recorded on iPhone)
        let transformedSize: CGSize
        if transform.a == 0 && (transform.b == 1.0 || transform.b == -1.0) {
            transformedSize = CGSize(width: abs(naturalSize.height), height: abs(naturalSize.width))
        } else {
            transformedSize = CGSize(width: abs(naturalSize.width), height: abs(naturalSize.height))
        }

        // Decode codec and pixel format from format descriptions
        var codecName = "Unknown"
        let pixelFormatName = "kCVPixelFormatType_32BGRA"
        var colorSpaceName = "BT.709"

        if let firstDesc = formatDescriptions.first {
            let mediaSubType = CMFormatDescriptionGetMediaSubType(firstDesc)
            codecName = Self.fourCCToCodecName(mediaSubType)

            // Inspect color primaries if available
            if let extensions = CMFormatDescriptionGetExtensions(firstDesc) as? [String: Any] {
                if let primaries = extensions[kCVImageBufferColorPrimariesKey as String] as? String {
                    colorSpaceName = primaries.replacingOccurrences(of: "kCVImageBufferColorPrimaries_", with: "")
                }
            }
        }

        // Calculate file size if fileURL is available
        var fileSize: Int64 = 0
        if let fileURL = fileURL, let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path) {
            fileSize = (attrs[.size] as? NSNumber)?.int64Value ?? 0
        }

        let fileName = fileURL?.lastPathComponent ?? "video_stream.mp4"

        return VideoMetadata(
            fileURL: fileURL,
            fileName: fileName,
            fileSizeInBytes: fileSize,
            duration: duration,
            dimensions: transformedSize,
            nominalFrameRate: nominalFPS > 0 ? nominalFPS : 30.0,
            videoCodec: codecName,
            estimatedBitrate: Double(estimatedBitrate),
            pixelFormat: pixelFormatName,
            colorSpace: colorSpaceName
        )
    }

    /// Converts FourCC OSType to a human-readable codec string.
    public static func fourCCToCodecName(_ code: OSType) -> String {
        switch code {
        case kCMVideoCodecType_H264:
            return "H.264 / AVC"
        case kCMVideoCodecType_HEVC:
            return "H.265 / HEVC"
        case kCMVideoCodecType_HEVCWithAlpha:
            return "HEVC with Alpha"
        case kCMVideoCodecType_AppleProRes422:
            return "Apple ProRes 422"
        case kCMVideoCodecType_AppleProRes4444:
            return "Apple ProRes 4444"
        case kCMVideoCodecType_AppleProRes422HQ:
            return "Apple ProRes 422 HQ"
        case kCMVideoCodecType_AppleProRes422LT:
            return "Apple ProRes 422 LT"
        case kCMVideoCodecType_AppleProRes422Proxy:
            return "Apple ProRes 422 Proxy"
        case kCMVideoCodecType_JPEG:
            return "Motion JPEG"
        default:
            let bytes: [CChar] = [
                CChar((code >> 24) & 0xff),
                CChar((code >> 16) & 0xff),
                CChar((code >> 8) & 0xff),
                CChar(code & 0xff),
                0
            ]
            let codeString = String(cString: bytes).trimmingCharacters(in: .whitespacesAndNewlines)
            return codeString.isEmpty ? "Codec 0x\(String(code, radix: 16))" : codeString
        }
    }
}
