#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>

#if __has_include("include/FrameLabObjC.h")
#import "include/FrameLabObjC.h"
#elif __has_include("FrameLabObjC.h")
#import "FrameLabObjC.h"
#endif

#if __has_include("../../C/FrameLabC/include/FrameLabC.h")
#import "../../C/FrameLabC/include/FrameLabC.h"
#elif __has_include("FrameLabC.h")
#import "FrameLabC.h"
#endif


NSErrorDomain const FrameLabObjCErrorDomain = @"com.framelab.objc.error";

@implementation FrameLabObjCProcessor

+ (NSString *)versionString {
    return [NSString stringWithFormat:@"FrameLab Obj-C Wrapper around %s", fl_c_version()];
}

+ (BOOL)processPixelBuffer:(CVPixelBufferRef)pixelBuffer error:(NSError **)error {
    if (!pixelBuffer) {
        if (error) {
            *error = [NSError errorWithDomain:FrameLabObjCErrorDomain
                                         code:FrameLabObjCErrorInvalidPixelBuffer
                                     userInfo:@{NSLocalizedDescriptionKey: @"Null CVPixelBuffer reference provided."}];
        }
        return NO;
    }

    OSType pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
    if (pixelFormat != kCVPixelFormatType_32BGRA && pixelFormat != kCVPixelFormatType_32RGBA) {
        if (error) {
            *error = [NSError errorWithDomain:FrameLabObjCErrorDomain
                                         code:FrameLabObjCErrorUnsupportedFormat
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Unsupported pixel format: %u", (unsigned int)pixelFormat]}];
        }
        return NO;
    }

    CVReturn lockResult = CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    if (lockResult != kCVReturnSuccess) {
        if (error) {
            *error = [NSError errorWithDomain:FrameLabObjCErrorDomain
                                         code:FrameLabObjCErrorLockFailed
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to lock pixel buffer base address: %d", lockResult]}];
        }
        return NO;
    }

    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(pixelBuffer);
    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);

    if (pixelFormat == kCVPixelFormatType_32BGRA) {
        fl_grayscale_bgra(baseAddress, baseAddress, (int32_t)width, (int32_t)height, (int32_t)bytesPerRow);
    } else {
        fl_grayscale_rgba(baseAddress, baseAddress, (int32_t)width, (int32_t)height, (int32_t)bytesPerRow);
    }

    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    return YES;
}

+ (BOOL)processBGRABytes:(const uint8_t *)input
                  output:(uint8_t *)output
                   width:(NSInteger)width
                  height:(NSInteger)height
             bytesPerRow:(NSInteger)bytesPerRow
                   error:(NSError **)error {
    if (!input || !output) {
        if (error) {
            *error = [NSError errorWithDomain:FrameLabObjCErrorDomain
                                         code:FrameLabObjCErrorInvalidPixelBuffer
                                     userInfo:@{NSLocalizedDescriptionKey: @"Input or output pointer is null."}];
        }
        return NO;
    }
    if (width <= 0 || height <= 0 || bytesPerRow <= 0) {
        if (error) {
            *error = [NSError errorWithDomain:FrameLabObjCErrorDomain
                                         code:FrameLabObjCErrorInvalidDimensions
                                     userInfo:@{NSLocalizedDescriptionKey: @"Invalid buffer dimensions."}];
        }
        return NO;
    }

    fl_grayscale_bgra(input, output, (int32_t)width, (int32_t)height, (int32_t)bytesPerRow);
    return YES;
}

@end
