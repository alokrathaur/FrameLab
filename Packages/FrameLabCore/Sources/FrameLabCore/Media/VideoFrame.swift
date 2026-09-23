import Foundation
import CoreMedia
import CoreVideo

/// A video frame holding its underlying CVPixelBuffer and canonical presentation timestamp.
public final class VideoFrame: @unchecked Sendable {
    public let pixelBuffer: CVPixelBuffer
    public let presentationTime: CMTime
    public let duration: CMTime
    public let frameIndex: Int64

    public init(
        pixelBuffer: CVPixelBuffer,
        presentationTime: CMTime,
        duration: CMTime = .invalid,
        frameIndex: Int64 = 0
    ) {
        self.pixelBuffer = pixelBuffer
        self.presentationTime = presentationTime
        self.duration = duration
        self.frameIndex = frameIndex
    }

    public var width: Int {
        CVPixelBufferGetWidth(pixelBuffer)
    }

    public var height: Int {
        CVPixelBufferGetHeight(pixelBuffer)
    }

    public var bytesPerRow: Int {
        CVPixelBufferGetBytesPerRow(pixelBuffer)
    }

    public var pixelFormatType: OSType {
        CVPixelBufferGetPixelFormatType(pixelBuffer)
    }

    public var formattedTimestamp: String {
        presentationTime.formattedTimeString
    }

    public var seconds: Double {
        presentationTime.isValid ? presentationTime.seconds : 0.0
    }
}
