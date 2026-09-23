# Implementation Plan

## Phase 0 — Project setup

Create:
- macOS target
- iOS target
- shared Swift Package
- Metal shader target/resources
- unit-test targets

## Phase 1 — Video metadata

Implement:

```text
VideoAssetService
MetadataReader
```

Read:
- duration
- dimensions
- frame rate
- format description

## Phase 2 — Frame reader

Implement `VideoFrameReader`.

Responsibilities:
- create AVAssetReader
- select video track
- configure output settings
- read CMSampleBuffer
- expose CMTime
- expose CVPixelBuffer

Suggested API:

```swift
struct VideoFrame {
    let pixelBuffer: CVPixelBuffer
    let presentationTime: CMTime
}

protocol VideoFrameReading {
    func frames() async throws -> AsyncThrowingStream<VideoFrame, Error>
}
```

Adjust API after prototype testing because `AVAssetReader` is callback/iterator-oriented.

## Phase 3 — Metal

Create:
- `MetalContext`
- `MetalFrameProcessor`
- grayscale shader
- texture cache
- command queue

Shader goal:
- read input texture
- calculate luminance
- write grayscale output

## Phase 4 — SwiftUI preview

Create:
- `VideoPreview`
- `VideoViewModel`
- platform-specific video selection

## Phase 5 — Concurrency

Implement:
- task cancellation
- bounded frame processing
- MainActor UI updates
- no unbounded `Task` creation

## Phase 6 — GCD

Add a small queue-based adapter where it makes sense.

Document why GCD is used rather than replacing every queue with async/await.

## Phase 7 — Accelerate

Implement a vImage grayscale or resize processor.

## Phase 8 — C

Implement a tiny C grayscale routine.

Add correctness tests against a known pixel buffer.

## Phase 9 — Objective-C

Add an isolated Objective-C wrapper around the C/native processing routine.

## Phase 10 — Export

Use ImageIO/Core Graphics to write the processed frame.

## Phase 11 — Benchmark

For the same input frame:
- warm up
- process N frames
- measure median/average
- record min/max
- optionally p95

## Phase 12 — Testing

Add unit, integration, cancellation, malformed-input and performance tests.

## Phase 13 — Instruments

Profile:
- Time Profiler
- Allocations
- Memory Graph
- Metal
- energy where relevant
