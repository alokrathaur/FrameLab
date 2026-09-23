# Security and Privacy

## Principles

FrameLab processes media locally.

## Data handling

- No account system.
- No cloud upload.
- No analytics required for the demo.
- No raw video logging.
- Temporary files should be removed after use.
- Export only when explicitly requested.

## File access

Request the minimum permissions needed.

macOS:
- use user-selected file URLs
- respect sandbox/security-scoped access where applicable.

iOS:
- use PhotosPicker/document picker APIs.

## Logging

Do not log:
- pixel data
- full video contents
- private file contents

Safe logging:
- processing duration
- frame count
- selected processing method
- non-sensitive errors

## Memory safety

C code must:
- validate pointers
- validate width/height
- validate row stride
- prevent integer overflow
- never read/write outside the provided buffer

## Threats

Potential issues:
- malformed media files
- unexpectedly huge resolution
- memory exhaustion
- invalid pixel formats
- corrupted files

Mitigations:
- validate dimensions
- reject unsupported formats
- bound memory usage
- fail gracefully
- cancel work
