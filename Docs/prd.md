# FrameLab Product Requirements Document

## 1. Overview

FrameLab is a technical video-processing application for macOS and iOS. It provides a minimal user interface around a real media-processing pipeline.

The primary goal is engineering demonstration rather than consumer-market breadth.

## 2. Problem

Video engineering concepts are difficult to demonstrate with a conventional CRUD application. A small video tool can provide a concrete place to demonstrate frame timing, sample buffers, pixel buffers, CPU/GPU processing, concurrency, and platform differences.

## 3. Goals

### Primary goals

1. Build one shared video-processing core used by macOS and iOS.
2. Load a local video.
3. Read video frames.
4. Expose frame timing through `CMTime`.
5. Work with `CMSampleBuffer`.
6. extract `CVPixelBuffer`.
7. Apply a Metal grayscale shader.
8. Provide an Accelerate/vImage processing path.
9. Provide a small C processing path.
10. Keep processing off the main UI thread.
11. Display processing latency and basic metadata.
12. Export a processed frame.
13. Demonstrate clean SwiftUI architecture.

### Secondary goals

- Camera capture on iOS.
- macOS drag-and-drop.
- VideoToolbox metadata/decoding investigation.
- Audio metadata using AVFoundation/AudioToolbox.
- Objective-C interoperability sample.
- Cancellation and backpressure.
- Benchmark mode.

## 4. Non-goals

- Full video editor.
- Timeline editing.
- Multi-track editing.
- Cloud upload.
- Social sharing.
- User accounts.
- AI video generation.
- Production-grade transcoding.
- Full codec implementation.

## 5. Target users

### Primary

Interviewers and engineers evaluating Mac/iOS/video engineering skills.

### Secondary

Developers learning Apple's media stack.

## 6. Core user journey

1. Launch FrameLab.
2. Select a video.
3. View metadata.
4. Press Play or Scrub.
5. Select Original, Metal, Accelerate, or C filter.
6. Observe processed frames.
7. Observe frame timestamp and processing time.
8. Export the current frame.
9. Optionally run a benchmark.
10. Compare CPU and GPU processing.

## 7. Functional requirements

### FR-01 Video import

The application must allow a user to select a local video.

macOS:
- Open panel.
- Drag and drop.

iOS:
- Photos/media picker or document picker.

### FR-02 Video metadata

Display:
- URL/file name
- duration
- dimensions
- nominal frame rate
- video codec when available
- estimated bitrate when available
- pixel format when available

### FR-03 Frame extraction

The processing layer must be capable of reading video samples and obtaining the associated pixel buffer.

### FR-04 CMSampleBuffer

The frame-processing pipeline must accept or produce `CMSampleBuffer` at the media boundary.

### FR-05 CMTime

Each processed frame should preserve or expose its presentation timestamp.

### FR-06 CVPixelBuffer

The processing layer must safely obtain and process the `CVPixelBuffer` associated with a video sample.

### FR-07 Metal filter

Implement a grayscale Metal shader.

Input:
- BGRA/RGBA-compatible texture where supported.

Output:
- grayscale frame.

### FR-08 Accelerate path

Implement at least one Accelerate/vImage operation, preferably grayscale or resize.

### FR-09 C path

Provide one small C pixel-processing routine callable from Swift.

### FR-10 Concurrency

Frame processing must not block the main actor.

Requirements:
- use `async/await`
- support cancellation
- avoid unbounded task creation
- isolate UI state on `@MainActor`

### FR-11 GCD

Use GCD where it is technically appropriate, such as wrapping legacy callback APIs or controlling a serial processing queue.

### FR-12 Preview

Display processed video/frame output in SwiftUI.

### FR-13 Export

Export the current processed frame to an image.

### FR-14 Benchmark

Measure processing time for:
- Swift baseline if implemented
- C
- Accelerate
- Metal

Show average and optionally p95 processing latency.

### FR-15 Platform support

The shared processing core must build on both macOS and iOS.

## 8. Non-functional requirements

### Performance

- UI must remain responsive during processing.
- Avoid unnecessary pixel-buffer copies.
- Reuse Metal resources where possible.
- Prefer pooled/reused buffers for repeated processing.
- Avoid processing frames that can no longer be displayed.

### Reliability

- Handle unsupported formats.
- Handle missing pixel buffers.
- Handle cancellation.
- Handle corrupt/unreadable files.
- Handle memory pressure.

### Accessibility

- VoiceOver labels.
- Keyboard navigation on macOS.
- Dynamic Type where practical.
- Clear status text for processing state.

### Privacy

All processing is local by default.
No video should leave the device.

## 9. MVP

MVP contains:

- Video import
- Metadata
- Frame extraction
- CMSampleBuffer
- CMTime
- CVPixelBuffer
- Metal grayscale filter
- SwiftUI preview
- Async processing
- GCD demonstration
- Frame export
- Basic performance metrics

## 10. V2

- Accelerate path
- C path
- Objective-C wrapper
- Camera capture
- Benchmark screen
- VideoToolbox investigation

## 11. Acceptance criteria

A build is MVP-complete when:

1. A supported video opens on macOS and iOS.
2. Metadata is displayed.
3. Frames can be decoded/read.
4. Frame timestamps are visible.
5. A `CVPixelBuffer` is successfully obtained.
6. Metal grayscale output is visibly correct.
7. Processing does not freeze the UI.
8. Cancellation works.
9. A frame can be exported.
10. Tests cover core frame-processing logic.
