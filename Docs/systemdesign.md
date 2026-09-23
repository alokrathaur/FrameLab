# FrameLab System Design

## 1. System objective

Build a local video-processing pipeline capable of moving frames from media input through Apple's media abstractions into CPU/GPU processing and finally into a SwiftUI presentation layer.

## 2. Pipeline

```text
Video URL
   ↓
AVAsset
   ↓
AVAssetReader
   ↓
CMSampleBuffer
   ├── CMTime presentation timestamp
   └── CVPixelBuffer
          ↓
     Frame Processor
       ├── Metal
       ├── Accelerate
       ├── C
       └── Swift
          ↓
    ProcessedPixelBuffer
          ↓
     Renderer / Preview
          ↓
        SwiftUI
```

## 3. Frame lifecycle

1. Reader obtains a media sample.
2. Read presentation timestamp.
3. Obtain image buffer.
4. Validate pixel format.
5. Select processing implementation.
6. Process frame.
7. Attach timestamp to the result.
8. Render.
9. Release/reuse resources.

## 4. Timing model

Use `CMTime` rather than `Double` as the canonical media time.

Store:
- presentation timestamp
- duration
- nominal frame rate

Use conversion to seconds only at the UI boundary.

## 5. Pixel buffer model

Expected MVP formats should be explicitly defined.

Example:
- 32BGRA for Metal preview path.

If input is another format:
- convert through VideoToolbox/Core Image/Accelerate as appropriate.

## 6. Metal design

Metal pipeline:

```text
CVPixelBuffer
      ↓
CVMetalTextureCache
      ↓
MTLTexture
      ↓
MTLCommandBuffer
      ↓
Compute/Render Pipeline
      ↓
Output Texture
      ↓
Output CVPixelBuffer / Render Target
```

The grayscale shader should operate per pixel.

## 7. Accelerate design

Use vImage for at least one operation.

Requirements:
- create/obtain vImage buffers
- perform operation
- manage row bytes correctly
- avoid invalid memory access
- benchmark against Metal

## 8. C interoperability

C API should be intentionally tiny.

Example conceptual interface:

```c
void fl_grayscale_rgba(
    const uint8_t *input,
    uint8_t *output,
    int width,
    int height,
    int bytesPerRow
);
```

Swift calls through a bridging/header/module interface.

## 9. Objective-C interoperability

Objective-C is optional but recommended for the interview demonstration.

Use an Objective-C wrapper around one native processing function.

Keep it isolated so the main codebase remains Swift-first.

## 10. Backpressure

Do not allow the UI to queue unlimited frames.

For real-time preview:
- process latest requested frame
- cancel stale work
- bound the number of in-flight frames

For offline benchmark:
- sequential or bounded concurrency

## 11. Memory

Avoid copying full frames unnecessarily.

Track:
- pixel buffer allocation
- texture allocation
- buffer pool reuse
- autorelease behavior on Apple media APIs

## 12. Export

For a selected frame:
- process it
- convert to a standard image representation
- write PNG/JPEG using ImageIO/Core Graphics.

## 13. Platform model

### macOS

Input:
- NSOpenPanel
- drag/drop
- local files

Output:
- SwiftUI preview
- save panel

### iOS

Input:
- PhotosPicker/document picker

Output:
- share sheet/photos export where appropriate

## 14. Future camera path

```text
AVCaptureSession
 ↓
AVCaptureVideoDataOutput
 ↓
CMSampleBuffer
 ↓
CVPixelBuffer
 ↓
Metal
 ↓
SwiftUI preview
```

This can later demonstrate live video processing.
