#ifndef FRAMELAB_C_H
#define FRAMELAB_C_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Returns the version string of the C processing core.
 */
const char* fl_c_version(void);

/**
 * Converts a 32-bit BGRA pixel buffer into 32-bit grayscale in-place or out-of-place.
 * Uses standard ITU-R BT.601 integer coefficients: (77*R + 150*G + 29*B) >> 8.
 *
 * @param input Pointer to the source pixel buffer base address.
 * @param output Pointer to the destination pixel buffer base address (can be equal to input for in-place).
 * @param width Number of pixels per row.
 * @param height Number of rows.
 * @param bytesPerRow Row stride in bytes (must account for padding).
 */
void fl_grayscale_bgra(
    const uint8_t *input,
    uint8_t *output,
    int32_t width,
    int32_t height,
    int32_t bytesPerRow
);

/**
 * Converts a 32-bit RGBA pixel buffer into 32-bit grayscale.
 *
 * @param input Pointer to the source pixel buffer base address.
 * @param output Pointer to the destination pixel buffer base address.
 * @param width Number of pixels per row.
 * @param height Number of rows.
 * @param bytesPerRow Row stride in bytes.
 */
void fl_grayscale_rgba(
    const uint8_t *input,
    uint8_t *output,
    int32_t width,
    int32_t height,
    int32_t bytesPerRow
);

#ifdef __cplusplus
}
#endif

#endif /* FRAMELAB_C_H */
