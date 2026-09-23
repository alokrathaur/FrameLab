import Foundation
import CoreVideo
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Image export formats supported by FrameLab.
public enum ImageExportFormat: String, CaseIterable, Identifiable, Sendable {
    case png = "PNG"
    case jpeg = "JPEG"

    public var id: String { rawValue }

    public var fileExtension: String {
        switch self {
        case .png: return "png"
        case .jpeg: return "jpg"
        }
    }

    public var utType: UTType {
        switch self {
        case .png: return .png
        case .jpeg: return .jpeg
        }
    }
}

/// Service for converting and exporting CVPixelBuffer frames to standard image formats (PNG/JPEG).
public final class FrameExporter: Sendable {
    public init() {}

    /// Exports a CVPixelBuffer to an encoded image file on disk.
    public func export(
        pixelBuffer: CVPixelBuffer,
        to destinationURL: URL,
        format: ImageExportFormat = .png,
        compressionQuality: CGFloat = 0.95
    ) throws {
        guard let cgImage = createCGImage(from: pixelBuffer) else {
            throw FrameLabError.exportFailed("Could not create CGImage from pixel buffer.")
        }

        guard let destination = CGImageDestinationCreateWithURL(
            destinationURL as CFURL,
            format.utType.identifier as CFString,
            1,
            nil
        ) else {
            throw FrameLabError.exportFailed("Could not initialize CGImageDestination.")
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: compressionQuality
        ]

        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw FrameLabError.exportFailed("CGImageDestinationFinalize failed to write file.")
        }
    }

    /// Exports a CVPixelBuffer to an in-memory Data object.
    public func exportToData(
        pixelBuffer: CVPixelBuffer,
        format: ImageExportFormat = .png,
        compressionQuality: CGFloat = 0.95
    ) throws -> Data {
        guard let cgImage = createCGImage(from: pixelBuffer) else {
            throw FrameLabError.exportFailed("Could not create CGImage from pixel buffer.")
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            format.utType.identifier as CFString,
            1,
            nil
        ) else {
            throw FrameLabError.exportFailed("Could not initialize CGImageDestination with data buffer.")
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: compressionQuality
        ]

        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw FrameLabError.exportFailed("CGImageDestinationFinalize failed.")
        }

        return data as Data
    }

    /// Converts a 32BGRA or 32RGBA CVPixelBuffer into a CGImage.
    public func createCGImage(from pixelBuffer: CVPixelBuffer) -> CGImage? {
        let format = CVPixelBufferGetPixelFormatType(pixelBuffer)
        guard format == kCVPixelFormatType_32BGRA || format == kCVPixelFormatType_32RGBA else {
            return nil
        }

        let lockStatus = CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        guard lockStatus == kCVReturnSuccess else { return nil }
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        let bitmapInfo: CGBitmapInfo
        if format == kCVPixelFormatType_32BGRA {
            bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
        } else {
            bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue)
        }

        guard let context = CGContext(
            data: nil, // Allocate backing memory for independent CGImage lifetime
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }

        // Draw source pixel buffer data into CGContext
        if let directContext = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ), let tempImage = directContext.makeImage() {
            context.draw(tempImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return context.makeImage()
        }

        return nil
    }
}
