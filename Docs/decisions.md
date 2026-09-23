# Architecture Decision Records

## ADR-001: SwiftUI

Decision: Use SwiftUI for both platforms.

Reason:
- shared declarative UI concepts
- native macOS and iOS support
- matches job requirement

## ADR-002: Shared Swift Package

Decision: Put media-processing abstractions in a shared package.

Reason:
- prevents duplicated business logic
- makes platform differences explicit
- improves testability

## ADR-003: Metal for GPU filter

Decision: Use Metal for grayscale.

Reason:
- demonstrates actual shader work
- maps naturally to per-pixel operations
- useful for video engineering discussion

## ADR-004: CMTime as canonical time

Decision: Keep `CMTime` internally.

Reason:
- media timing requires precise rational representation
- avoid repeated floating-point conversion

## ADR-005: Local-only processing

Decision: Process all media locally.

Reason:
- simpler
- privacy-preserving
- no backend needed

## ADR-006: Multiple processors

Decision: Use a processor protocol.

Reason:
- allows Metal, Accelerate and C implementations to be compared without changing UI logic
