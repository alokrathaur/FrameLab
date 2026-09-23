# Interview Preparation — FrameLab

## 30-second explanation

"FrameLab is a cross-platform macOS and iOS video-processing application. It reads video samples with AVFoundation, uses CMSampleBuffer and CMTime for media samples and timing, extracts CVPixelBuffer for raw pixel access, and processes frames through Metal, Accelerate and C implementations. SwiftUI renders the result, while Swift Concurrency and GCD keep processing off the UI thread."

## Explain CMSampleBuffer

"CMSampleBuffer is a Core Media container representing a media sample. For video, it can contain a video image buffer plus timing and format information."

## Explain CVPixelBuffer

"CVPixelBuffer represents the actual pixel storage for a video frame. It gives access to image dimensions, pixel format and pixel memory."

## Explain CMTime

"CMTime is Apple's precise media-time representation. I use it for presentation timestamps and durations instead of relying on floating-point seconds internally."

## Explain the relationship

```text
CMSampleBuffer
 ├── CMTime
 └── CVPixelBuffer
```

CMSampleBuffer is the media sample container.
CMTime represents when the sample belongs in the timeline.
CVPixelBuffer represents the image pixels.

## Why Metal?

"Metal allows suitable image operations to execute on the GPU, which can be valuable for processing many pixels per frame."

## Why Accelerate?

"Accelerate provides optimized CPU implementations for numerical and image-processing workloads."

## Why GCD if Swift Concurrency exists?

"GCD remains useful for queue-based APIs and existing callback-driven frameworks. I prefer structured concurrency for new asynchronous workflows, but I use GCD where its queue semantics are appropriate."

## How would you avoid blocking UI?

"UI state stays on MainActor. Video reading and frame processing happen outside the main actor. I use cancellation and bounded work so the application doesn't accumulate stale frames."

## How would you process live camera video?

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
Preview
```

## What happens if processing is slower than the camera?

Don't queue every frame indefinitely. Use a bounded/latest-frame strategy, drop stale frames when appropriate, and preserve responsiveness.

## What would you optimize first?

Measure first. Check:
- CPU time
- GPU time
- memory copies
- buffer allocation
- texture conversion
- synchronization

Then optimize the actual bottleneck.
