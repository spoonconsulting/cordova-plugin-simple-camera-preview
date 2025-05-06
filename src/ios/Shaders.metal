#include <metal_stdlib>
using namespace metal;

struct Vertex {
    float4 position [[position]];
    float2 texCoord;
};

vertex Vertex vertex_main(const uint vertexID [[vertex_id]]) {
    float4 positions[4] = {
        float4(-1.0, -1.0, 0.0, 1.0), // bottom-left
        float4( 1.0, -1.0, 0.0, 1.0), // bottom-right
        float4(-1.0,  1.0, 0.0, 1.0), // top-left
        float4( 1.0,  1.0, 0.0, 1.0), // top-right
    };

    float2 texCoords[4] = {
        float2(0.0, 1.0), // bottom-left
        float2(1.0, 1.0), // bottom-right
        float2(0.0, 0.0), // top-left
        float2(1.0, 0.0), // top-right
    };

    Vertex out;
    out.position = positions[vertexID];
    out.texCoord = texCoords[vertexID];
    return out;
}

fragment float4 fragment_main(Vertex in [[stage_in]],
                              texture2d<float> cameraTexture [[texture(0)]]) {
    constexpr sampler textureSampler (mag_filter::linear, min_filter::linear);
    return cameraTexture.sample(textureSampler, in.texCoord);
}
