#include <metal_stdlib>
using namespace metal;

struct Vertex {
    float4 position [[position]];
    float2 texCoord;
};

vertex Vertex vertex_main(const uint vertexID [[vertex_id]], constant bool &flipHorizontal [[buffer(0)]]) {
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

    float2 flippedTexCoords[4] = {
        float2(1.0, 1.0),
        float2(0.0, 1.0),
        float2(1.0, 0.0),
        float2(0.0, 0.0),
    };

    Vertex out;
    out.position = positions[vertexID];
    out.texCoord = flipHorizontal ? flippedTexCoords[vertexID] : texCoords[vertexID];
    return out;
}

fragment float4 fragment_main(Vertex in [[stage_in]],
                              texture2d<float> cameraTexture [[texture(0)]]) {
    constexpr sampler textureSampler (mag_filter::linear, min_filter::linear);
    return cameraTexture.sample(textureSampler, in.texCoord);
}

// MARK: - Video Mixing Shaders

struct MixerParameters
{
    float2 pipPosition;
    float2 pipSize;
};

constant sampler kBilinearSampler(filter::linear,  coord::pixel, address::clamp_to_edge);

// Compute kernel for picture-in-picture video mixing
kernel void reporterMixer(texture2d<half, access::read>        fullScreenInput        [[ texture(0) ]],
                          texture2d<half, access::sample>    pipInput            [[ texture(1) ]],
                          texture2d<half, access::write>    outputTexture        [[ texture(2) ]],
                          const device    MixerParameters&    mixerParameters        [[ buffer(0) ]],
                          uint2 gid [[thread_position_in_grid]])

{
    uint2 pipPosition = uint2(mixerParameters.pipPosition);
    uint2 pipSize = uint2(mixerParameters.pipSize);

    half4 output;

    // Check if the output pixel should be from full screen or PIP
    if ( (gid.x >= pipPosition.x) && (gid.y >= pipPosition.y) &&
         (gid.x < (pipPosition.x + pipSize.x)) && (gid.y < (pipPosition.y + pipSize.y)) )
    {
        // Position and scale the PIP window
        float2 pipSamplingCoord =  float2(gid - pipPosition) * float2(pipInput.get_width(), pipInput.get_height()) / float2(pipSize);
        output = pipInput.sample(kBilinearSampler, pipSamplingCoord + 0.5);
    }
    else
    {
        output = fullScreenInput.read(gid);
    }

    outputTexture.write(output, gid);
}
