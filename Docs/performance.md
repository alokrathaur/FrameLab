# Performance Plan

## Goal

Demonstrate understanding of CPU/GPU video-processing tradeoffs rather than claiming arbitrary performance numbers.

## Metrics

Measure:
- frame processing time
- average latency
- median latency
- p95 latency
- dropped frames
- memory footprint
- CPU utilization
- GPU utilization when available

## Benchmark methodology

1. Use the same input frames.
2. Warm up the implementation.
3. Run multiple iterations.
4. Ignore initial setup time when measuring steady state.
5. Report device, OS and build configuration.
6. Compare implementations only under the same conditions.

## Implementations

```text
Swift baseline
C
Accelerate/vImage
Metal
```

## Avoid premature optimization

First make:
1. correct output
2. safe memory behavior
3. cancellation
4. stable rendering

Then optimize.

## Instruments

Use:
- Time Profiler
- Allocations
- Leaks
- Memory Graph
- Metal System Trace
- Points of Interest / os_signpost

## os_signpost

Add signposts around:
- frame decode
- CPU processing
- Metal processing
- render completion

This allows frame-level profiling without printing large logs.
