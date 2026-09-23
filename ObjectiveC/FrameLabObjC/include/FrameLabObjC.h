#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const FrameLabObjCErrorDomain;

typedef NS_ERROR_ENUM(FrameLabObjCErrorDomain, FrameLabObjCErrorCode) {
    FrameLabObjCErrorInvalidPixelBuffer = 1001,
    FrameLabObjCErrorLockFailed         = 1002,
    FrameLabObjCErrorUnsupportedFormat  = 1003,
    FrameLabObjCErrorInvalidDimensions  = 1004
};

@interface FrameLabObjCProcessor : NSObject

/**
 * Returns the version string of the Objective-C wrapper.
 */
+ (NSString *)versionString;

/**
 * Processes an in-memory 32BGRA CVPixelBuffer in-place using the C core routine.
 * Handles locking/unlocking the base address safely.
 *
 * @param pixelBuffer The CVPixelBuffer to process.
 * @param error Out parameter for error reporting.
 * @return YES if successful, NO otherwise.
 */
+ (BOOL)processPixelBuffer:(CVPixelBufferRef)pixelBuffer error:(NSError **)error;

/**
 * Processes raw 32BGRA bytes into an output buffer.
 */
+ (BOOL)processBGRABytes:(const uint8_t *)input
                  output:(uint8_t *)output
                   width:(NSInteger)width
                  height:(NSInteger)height
             bytesPerRow:(NSInteger)bytesPerRow
                   error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
