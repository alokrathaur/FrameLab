#include <metal_stdlib>
using namespace metal;

// MARK: - Compute Pipeline (Grayscale Filter)

/**
 * Metal Compute Kernel for high-performance grayscale conversion.
 * Processes each pixel in parallel across GPU execution units.
 * Supports BGRA and RGBA color layouts.
 */
kernel void grayscale_compute(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= inTexture.get_width() || gid.y >= inTexture.get_height()) {
        return;
    }

    float4 color = inTexture.read(gid);

    // Standard ITU-R BT.709 HDTV Luminance coefficients
    // Y = 0.2126 * R + 0.7152 * G + 0.0722 * B
    float luminance = dot(color.rgb, float3(0.2126f, 0.7152f, 0.0722f));

    outTexture.write(float4(luminance, luminance, luminance, color.a), gid);
}

// MARK: - Render Pipeline (for MetalKit View display)

struct VertexIn {
    float4 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct RasterizerData {
    float4 position [[position]];
    float2 texCoord;
};

vertex RasterizerData preview_vertex(
    uint vertexID [[vertex_id]],
    constant float4 *positions [[buffer(0)]],
    constant float2 *texCoords [[buffer(1)]]
) {
    RasterizerData out;
    out.position = positions[vertexID];
    out.texCoord = texCoords[vertexID];
    return out;
}

fragment float4 preview_fragment(
    RasterizerData in [[stage_in]],
    texture2d<float> texture [[texture(0)]]
) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    return texture.sample(textureSampler, in.texCoord);
}
