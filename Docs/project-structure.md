# Recommended Xcode Project Structure

```text
FrameLab/
├── Apps/
│   ├── FrameLabMac/
│   │   ├── FrameLabMacApp.swift
│   │   ├── ContentView.swift
│   │   └── MacVideoPicker.swift
│   └── FrameLabIOS/
│       ├── FrameLabIOSApp.swift
│       ├── ContentView.swift
│       └── IOSVideoPicker.swift
│
├── Packages/
│   └── FrameLabCore/
│       ├── Sources/
│       │   └── FrameLabCore/
│       │       ├── Media/
│       │       │   ├── VideoAssetService.swift
│       │       │   ├── VideoFrameReader.swift
│       │       │   └── VideoMetadata.swift
│       │       ├── Processing/
│       │       │   ├── FrameProcessor.swift
│       │       │   ├── MetalFrameProcessor.swift
│       │       │   ├── AccelerateFrameProcessor.swift
│       │       │   └── CFrameProcessor.swift
│       │       ├── Timing/
│       │       │   └── FrameTiming.swift
│       │       └── Benchmark/
│       │           └── BenchmarkRunner.swift
│       └── Tests/
│
├── Metal/
│   └── FrameLabShaders.metal
│
├── C/
│   ├── FrameLabC.h
│   └── FrameLabC.c
│
├── ObjectiveC/
│   ├── FrameLabObjC.h
│   └── FrameLabObjC.m
│
└── Docs/
    └── ...
```

## Important implementation note

Start with a video-file pipeline before adding camera capture. Once the file pipeline is stable, the camera path becomes an alternate source that produces the same `CMSampleBuffer → CVPixelBuffer → processor` flow.
