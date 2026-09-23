# FrameLab UI/UX Design

## 1. Design principles

- Technical but simple.
- One primary workflow.
- Minimal controls.
- Make engineering data visible.
- Avoid unnecessary animations during video processing.
- Keep macOS and iOS interaction patterns platform-appropriate.

## 2. Main screen

### macOS

```text
┌───────────────────────────────────────────────────────────────┐
│ FrameLab                                         Open Video   │
├───────────────────────────────────────────────────────────────┤
│                                                               │
│                  Video Preview                                │
│                                                               │
│                                                               │
├───────────────────────────────────────────────────────────────┤
│ 00:04.250 / 00:20.000          ───────●────────────           │
├───────────────────────────────────────────────────────────────┤
│ Filter: [Original] [Metal] [Accelerate] [C]                  │
├───────────────────────────────┬───────────────────────────────┤
│ Video                         │ Processing                    │
│ 1920 × 1080                   │ Method: Metal                 │
│ 60 FPS                        │ Latency: 3.2 ms               │
│ HEVC                          │ Frames: 254                   │
│ Duration: 20.0 s              │ Status: Processing            │
├───────────────────────────────┴───────────────────────────────┤
│ [Export Frame]                            [Benchmark]         │
└───────────────────────────────────────────────────────────────┘
```

### iOS

Use a NavigationStack with:
- video preview
- timeline/scrubber
- filter segmented control
- metadata sheet
- export action

## 3. States

### Empty

Show:
- app title
- "Open Video"
- short explanation

### Loading

Show:
- spinner/progress
- filename
- cancellation

### Ready

Show preview and metadata.

### Processing

Show:
- selected processor
- frame timestamp
- current latency
- cancel

### Error

Show a human-readable message and recovery action.

## 4. Visual hierarchy

1. Video preview
2. Playback/scrubbing
3. Filter selection
4. Metadata
5. Processing metrics
6. Secondary actions

## 5. Accessibility

Every interactive control must have an accessibility label.

Example:
- "Open video"
- "Metal grayscale filter"
- "Export current frame"
- "Cancel processing"

## 6. Platform differences

Do not force identical UI.

macOS:
- toolbar
- menu commands
- drag/drop
- keyboard shortcuts
- split view

iOS:
- NavigationStack
- sheets
- Photos picker
- touch-first controls
