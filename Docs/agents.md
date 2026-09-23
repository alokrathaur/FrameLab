# AGENTS.md

## Mission

Build FrameLab as a clean, technically credible macOS + iOS video-engineering sample.

## Rules

1. Prefer Swift and SwiftUI.
2. Keep platform-specific UI separate from shared media-processing logic.
3. Never block the main actor with frame processing.
4. Treat `CMTime` as the canonical media time representation.
5. Validate `CVPixelBuffer` format before processing.
6. Avoid unnecessary pixel-buffer copies.
7. Make buffer ownership/lifetime obvious.
8. Use Metal for GPU work and Accelerate for CPU-optimized operations.
9. Keep C/Objective-C interoperability small and purposeful.
10. Add tests for every processing implementation.
11. Do not introduce a third-party dependency unless there is a clear reason.
12. Do not upload or persist user videos.
13. Do not log raw video data.
14. Do not commit generated media files.
15. Keep APIs small and documented.

## Before changing architecture

Read:
- prd.md
- architecture.md
- systemdesign.md
- design.md

## Coding conventions

- Swift naming conventions.
- One primary type per file where practical.
- Protocols for processing abstractions.
- Typed errors.
- `@MainActor` only for UI/application state.
- Prefer structured concurrency over detached tasks.
- Use GCD when interacting with APIs that are naturally queue/callback based.

## Performance

When processing video:
- avoid per-frame heap allocations when practical
- reuse buffers
- measure before optimizing
- use Instruments for CPU, memory and Metal analysis

## Testing

Every processor should have:
- correctness test
- edge-case test
- performance/benchmark test where practical
