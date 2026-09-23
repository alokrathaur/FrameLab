import Foundation
import CoreMedia
import CoreGraphics

/// Comprehensive metadata extracted from an AVAsset video file.
public struct VideoMetadata: Identifiable, Sendable, Equatable {
    public var id: String { fileName + "_" + "\(duration.value)" }

    public let fileURL: URL?
    public let fileName: String
    public let fileSizeInBytes: Int64
    public let duration: CMTime
    public let durationSeconds: Double
    public let dimensions: CGSize
    public let nominalFrameRate: Float
    public let videoCodec: String
    public let estimatedBitrate: Double // in bits per second
    public let pixelFormat: String
    public let colorSpace: String
    public let estimatedFrameCount: Int64

    public init(
        fileURL: URL?,
        fileName: String,
        fileSizeInBytes: Int64 = 0,
        duration: CMTime,
        dimensions: CGSize,
        nominalFrameRate: Float,
        videoCodec: String,
        estimatedBitrate: Double,
        pixelFormat: String,
        colorSpace: String = "BT.709",
        estimatedFrameCount: Int64 = 0
    ) {
        self.fileURL = fileURL
        self.fileName = fileName
        self.fileSizeInBytes = fileSizeInBytes
        self.duration = duration
        self.durationSeconds = duration.isValid ? max(0.0, duration.seconds) : 0.0
        self.dimensions = dimensions
        self.nominalFrameRate = nominalFrameRate
        self.videoCodec = videoCodec
        self.estimatedBitrate = estimatedBitrate
        self.pixelFormat = pixelFormat
        self.colorSpace = colorSpace
        self.estimatedFrameCount = estimatedFrameCount > 0
            ? estimatedFrameCount
            : Int64((self.durationSeconds * Double(max(1.0, nominalFrameRate))).rounded())
    }

    /// Formatted display duration "MM:SS.mmm"
    public var formattedDuration: String {
        duration.formattedTimeString
    }

    /// Formatted resolution "1920 × 1080"
    public var resolutionString: String {
        "\(Int(dimensions.width)) × \(Int(dimensions.height))"
    }

    /// Formatted bitrate "8.5 Mbps"
    public var formattedBitrate: String {
        if estimatedBitrate >= 1_000_000 {
            return String(format: "%.1f Mbps", estimatedBitrate / 1_000_000.0)
        } else if estimatedBitrate >= 1_000 {
            return String(format: "%.0f kbps", estimatedBitrate / 1_000.0)
        } else {
            return "\(Int(estimatedBitrate)) bps"
        }
    }

    /// Formatted frame rate "60.00 FPS"
    public var formattedFrameRate: String {
        String(format: "%.2f FPS", nominalFrameRate)
    }

    /// Human readable file size "45.2 MB"
    public var formattedFileSize: String {
        guard fileSizeInBytes > 0 else { return "Unknown" }
        return ByteCountFormatter.string(fromByteCount: fileSizeInBytes, countStyle: .file)
    }
}
