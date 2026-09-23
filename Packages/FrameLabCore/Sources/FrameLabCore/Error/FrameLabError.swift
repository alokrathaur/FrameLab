import Foundation
import CoreMedia

/// Typed errors for the FrameLab media processing core.
public enum FrameLabError: LocalizedError, Sendable {
    case invalidAsset(String)
    case missingVideoTrack
    case readerFailed(String)
    case unsupportedPixelFormat(OSType)
    case missingPixelBuffer
    case bufferLockFailed(Int32)
    case metalDeviceUnavailable
    case metalCompilationFailed(String)
    case metalBufferCreationFailed
    case metalTextureCreationFailed
    case accelerateError(Int)
    case cProcessingFailed(String)
    case objcProcessingFailed(String)
    case processingFailed(String)
    case exportFailed(String)
    case cancelled
    case invalidDimensions(width: Int, height: Int)

    public var errorDescription: String? {
        switch self {
        case .invalidAsset(let reason):
            return "Invalid video asset: \(reason)"
        case .missingVideoTrack:
            return "Video asset does not contain a readable video track."
        case .readerFailed(let reason):
            return "AVAssetReader failed: \(reason)"
        case .unsupportedPixelFormat(let format):
            let formatString = Self.fourCCToString(format)
            return "Unsupported pixel buffer format: 0x\(String(format, radix: 16)) ('\(formatString)'). Only 32BGRA and 32RGBA are currently supported."
        case .missingPixelBuffer:
            return "CMSampleBuffer does not contain an image buffer (CVPixelBuffer)."
        case .bufferLockFailed(let status):
            return "Failed to lock CVPixelBuffer base address with status: \(status)."
        case .metalDeviceUnavailable:
            return "Default Metal device (MTLDevice) is unavailable on this hardware."
        case .metalCompilationFailed(let reason):
            return "Metal shader compilation failed: \(reason)"
        case .metalBufferCreationFailed:
            return "Failed to create Metal texture from CVPixelBuffer via CVMetalTextureCache."
        case .metalTextureCreationFailed:
            return "Failed to instantiate Metal texture descriptor or allocate texture."
        case .accelerateError(let code):
            return "Accelerate vImage operation failed with error code: \(code)."
        case .cProcessingFailed(let reason):
            return "C native processing failed: \(reason)"
        case .objcProcessingFailed(let reason):
            return "Objective-C native processing failed: \(reason)"
        case .processingFailed(let reason):
            return "Frame processing failed: \(reason)"
        case .exportFailed(let reason):
            return "Frame export failed: \(reason)"
        case .cancelled:
            return "Frame processing was cancelled."
        case .invalidDimensions(let width, let height):
            return "Invalid pixel buffer dimensions: \(width)x\(height)."
        }
    }

    private static func fourCCToString(_ code: OSType) -> String {
        let bytes: [CChar] = [
            CChar((code >> 24) & 0xff),
            CChar((code >> 16) & 0xff),
            CChar((code >> 8) & 0xff),
            CChar(code & 0xff),
            0
        ]
        return String(cString: bytes)
    }
}
