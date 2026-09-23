# Testing Strategy

## 1. Unit tests

### Metadata

Test:
- valid video
- missing track
- invalid asset

### Timing

Test:
- CMTime conversion
- frame ordering
- timestamp preservation

### Pixel buffers

Test:
- supported pixel format
- unsupported format
- zero/invalid dimensions

### Metal

Test:
- shader output against expected grayscale values
- resource creation failures

### Accelerate

Compare known input/output.

### C

Test fixed input pixels.

## 2. Integration tests

Pipeline:

```text
video → sample buffer → pixel buffer → processor → output
```

Verify:
- frames are produced
- timestamps increase
- output dimensions match
- output is valid

## 3. Cancellation test

Start processing a longer video and cancel.

Expected:
- processing stops promptly
- no UI deadlock
- no leaked resources

## 4. Performance test

Run a fixed test video.

Record:
- total time
- per-frame latency
- memory
- dropped frames for preview mode

## 5. Manual test matrix

| Scenario | macOS | iOS |
|---|---|---|
| MP4/H.264 | ✓ | ✓ |
| HEVC | ✓ | ✓ |
| 1080p | ✓ | ✓ |
| 4K | optional | optional |
| 30 FPS | ✓ | ✓ |
| 60 FPS | ✓ | ✓ |
| cancellation | ✓ | ✓ |
| export | ✓ | ✓ |
| unsupported media | ✓ | ✓ |
