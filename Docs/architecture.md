# FrameLab Architecture

## 1. Architecture style

Use a layered architecture with a shared Swift Package.

```text
┌─────────────────────────────────────────────────────────────┐
│                     PRESENTATION LAYER                      │
│                                                             │
│   ┌───────────────────────────┐ ┌───────────────────────┐   │
│   │   FrameLabMacApp (macOS)  │ │  FrameLabIOSApp (iOS) │   │
│   │  Toolbar, Drag&Drop, HUD  │ │ PhotosPicker, NavStack│   │
│   └─────────────┬─────────────┘ └───────────┬───────────┘   │
│                 │                           │               │
│                 └─────────────┬─────────────┘               │
│                               ▼                             │
│                  VideoPlayerViewModel (@MainActor)          │
│       [Playback Loop | State Machine | Scrubber | Metrics]  │
└───────────────────────────────┬─────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────┐
│                   CORE MEDIA ENGINE LAYER                   │
│                        (FrameLabCore)                       │
│                                                             │
│   VideoAssetService  │  VideoFrameReader  │   FrameTiming   │
│  (Metadata / Codec)  │(AVAssetReader/PTS) │ (CMTime Rational)
└───────────────────────────────┬─────────────────────────────┘
                                │ VideoFrame (CVPixelBuffer)
                                ▼
┌─────────────────────────────────────────────────────────────┐
│                   FRAME PROCESSING LAYER                    │
│                                                             │
│     ┌────────────┬────────────┬────────────┬────────────┐   │
│     ▼            ▼            ▼            ▼            ▼   │
│  [Metal]    [Accelerate]  [C Native]  [Objective-C]  [Swift]│
│  Compute      vImage      Fixed-Point    Bridge     Baseline│
│  (Zero-Copy)  (SIMD)       (>> 8)      (NSError**)   (CPU)  │
└───────────────────────────────┬─────────────────────────────┘
                                │ ProcessedFrame
                                ▼
┌─────────────────────────────────────────────────────────────┐
│                  RENDER & EXPORT PIPELINE                   │
│                                                             │
│         SwiftUI Viewport          │   FrameExporter         │
│     (Letterbox CGImage Display)   │   (ImageIO PNG/JPEG)    │
└───────────────────────────────────┴─────────────────────────┘
```

## 2. Layers

### App layer

Platform-specific SwiftUI screens.

### Application layer

Coordinates workflows:
- import
- playback
- processing
- benchmark
- export

### Media layer

Owns:
- AVAsset
- AVAssetReader
- CMSampleBuffer
- CMTime
- video format descriptions

### Processing layer

Defines a protocol:

```swift
protocol FrameProcessor {
    var name: String { get }
    func process(_ pixelBuffer: CVPixelBuffer) async throws -> ProcessedFrame
}
```

Implementations:
- MetalFrameProcessor
- AccelerateFrameProcessor
- CFrameProcessor
- SwiftFrameProcessor

### Rendering layer

Converts processed pixel buffers/textures into UI-renderable output.

## 3. Dependency rule

UI must not directly manipulate low-level pixel memory.

Preferred:

```text
View → ViewModel → Service → Processor
```

Avoid:

```text
View → CVPixelBuffer → Metal
```

## 4. Ownership

- UI owns presentation state.
- VideoReader owns media reading.
- Processor owns processing resources.
- Metal processor owns `MTLDevice`, command queue, pipeline state.
- Buffer lifetime must be explicit.

## 5. Threading

Main actor:
- UI state
- user actions
- lightweight metadata

Background:
- video reading
- CPU processing
- Metal command submission where appropriate
- benchmark operations

## 6. Error model

Use typed errors:

```swift
enum FrameLabError: Error {
    case invalidAsset
    case unsupportedFormat
    case missingPixelBuffer
    case processingFailed
    case cancelled
    case exportFailed
}
```
