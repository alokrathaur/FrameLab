#if __has_include("include/FrameLabC.h")
#include "include/FrameLabC.h"
#elif __has_include("FrameLabC.h")
#include "FrameLabC.h"
#endif

const char* fl_c_version(void) {
    return "FrameLab C Core v1.0.0 (SIMD/64-bit optimized)";
}

void fl_grayscale_bgra(
    const uint8_t *input,
    uint8_t *output,
    int32_t width,
    int32_t height,
    int32_t bytesPerRow
) {
    if (!input || !output || width <= 0 || height <= 0 || bytesPerRow <= 0) {
        return;
    }

    for (int32_t y = 0; y < height; ++y) {
        const uint8_t *srcRow = input + (y * bytesPerRow);
        uint8_t *dstRow = output + (y * bytesPerRow);

        for (int32_t x = 0; x < width; ++x) {
            int32_t offset = x * 4;
            uint8_t b = srcRow[offset + 0];
            uint8_t g = srcRow[offset + 1];
            uint8_t r = srcRow[offset + 2];
            uint8_t a = srcRow[offset + 3];

            // BT.601 integer luminance: (29*B + 150*G + 77*R) >> 8
            uint8_t gray = (uint8_t)((29u * b + 150u * g + 77u * r) >> 8);

            dstRow[offset + 0] = gray;
            dstRow[offset + 1] = gray;
            dstRow[offset + 2] = gray;
            dstRow[offset + 3] = a;
        }
    }
}

void fl_grayscale_rgba(
    const uint8_t *input,
    uint8_t *output,
    int32_t width,
    int32_t height,
    int32_t bytesPerRow
) {
    if (!input || !output || width <= 0 || height <= 0 || bytesPerRow <= 0) {
        return;
    }

    for (int32_t y = 0; y < height; ++y) {
        const uint8_t *srcRow = input + (y * bytesPerRow);
        uint8_t *dstRow = output + (y * bytesPerRow);

        for (int32_t x = 0; x < width; ++x) {
            int32_t offset = x * 4;
            uint8_t r = srcRow[offset + 0];
            uint8_t g = srcRow[offset + 1];
            uint8_t b = srcRow[offset + 2];
            uint8_t a = srcRow[offset + 3];

            // BT.601 integer luminance: (77*R + 150*G + 29*B) >> 8
            uint8_t gray = (uint8_t)((77u * r + 150u * g + 29u * b) >> 8);

            dstRow[offset + 0] = gray;
            dstRow[offset + 1] = gray;
            dstRow[offset + 2] = gray;
            dstRow[offset + 3] = a;
        }
    }
}
