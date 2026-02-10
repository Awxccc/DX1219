Shader "Hidden/Custom/VolumetricFogGlobal"
{
    Properties
    {
        _MainTex("Source", 2D) = "white" {}
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }
        LOD 100
        ZWrite Off Cull Off ZTest Always

        Pass
        {
            Name "VolumetricFogPass"

            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"

            #pragma vertex Vert
            #pragma fragment Frag

            TEXTURE2D(_BlitTexture);
            SAMPLER(sampler_BlitTexture);

            // --- Uniforms from C# ---
            float _Intensity;
            float4 _FogColor;
            float4 _InsanityColor;
            float _FogDensity;
            float _NoiseScale;
            float _Speed;
            float _HeightFalloff; // How fast fog fades as you go up
            float _BaseHeight;    // The y-level where fog is thickest
            float _MaxDistance;   // Max distance to raymarch
            
            // Global variable from SanityController
            uniform float _GlobalSanity; 

            struct Attributes
            {
                uint vertexID : SV_VertexID;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 viewVector : TEXCOORD1;
            };

            Varyings Vert(Attributes input)
            {
                Varyings output;
                UNITY_SETUP_INSTANCE_ID(input);
                output.positionCS = GetFullScreenTriangleVertexPosition(input.vertexID);
                output.uv = GetFullScreenTriangleTexCoord(input.vertexID);
                
                // Calculate View Vector for World Position Reconstruction
                // This allows us to get the world position of every pixel cheaply
                float3 viewVector = mul(unity_CameraInvProjection, float4(output.uv * 2.0 - 1.0, 0.0, -1.0)).xyz;
                output.viewVector = mul(unity_CameraToWorld, float4(viewVector, 0.0)).xyz;
                
                return output;
            }

            // --- Procedural 3D Noise Function ---
            // A simple 3D hash function to simulate volumetric noise without a texture
            float Hash(float3 p)
            {
                p = frac(p * 0.3183099 + 0.1);
                p *= 17.0;
                return frac(p.x * p.y * p.z * (p.x + p.y + p.z));
            }

            float Noise3D(float3 x)
            {
                float3 i = floor(x);
                float3 f = frac(x);
                f = f * f * (3.0 - 2.0 * f);
                
                return lerp(lerp(lerp(Hash(i + float3(0,0,0)), Hash(i + float3(1,0,0)), f.x),
                                 lerp(Hash(i + float3(0,1,0)), Hash(i + float3(1,1,0)), f.x), f.y),
                            lerp(lerp(Hash(i + float3(0,0,1)), Hash(i + float3(1,0,1)), f.x),
                                 lerp(Hash(i + float3(0,1,1)), Hash(i + float3(1,1,1)), f.x), f.y), f.z);
            }

            // FBM (Fractal Brownian Motion) for fluffier clouds
            float FBM(float3 p)
            {
                float f = 0.0;
                float w = 0.5;
                for (int i = 0; i < 3; i++) // 3 Octaves
                {
                    f += w * Noise3D(p);
                    p *= 2.0;
                    w *= 0.5;
                }
                return f;
            }

            half4 Frag(Varyings input) : SV_Target
            {
                // 1. Reconstruct World Position
                float depth = SampleSceneDepth(input.uv);
                float linearDepth = Linear01Depth(depth, _ZBufferParams);

                // If depth is skybox (usually 0 or 1 depending on platform), clamp distance
                // We create a "virtual" far plane for the fog if looking at the sky
                float viewLength = length(input.viewVector);
                float3 viewDir = input.viewVector / viewLength;
                
                // Actual distance to the pixel surface
                float pixelDistance = LinearEyeDepth(depth, _ZBufferParams);
                
                // Raymarch Setup
                float3 camPos = _WorldSpaceCameraPos;
                
                // Optimization: Don't march further than _MaxDistance
                float marchLimit = min(pixelDistance, _MaxDistance);
                
                // Sanity Logic
                float insanity = clamp(_GlobalSanity, 0, 1);
                float3 targetFogColor = lerp(_FogColor.rgb, _InsanityColor.rgb, insanity);
                
                // Raymarch Loop
                int steps = 12; // Keep low for full-screen performance
                float stepSize = marchLimit / steps;
                float3 currentPos = camPos;
                
                float accumulatedDensity = 0.0;
                
                // Random offset to remove banding (Dithering)
                float dither = frac(sin(dot(input.uv, float2(12.9898, 78.233))) * 43758.5453);
                currentPos += viewDir * stepSize * dither;

                [unroll]
                for(int i = 0; i < steps; i++)
                {
                    if(distance(camPos, currentPos) > marchLimit) break;

                    // --- Height Fog Logic ---
                    // Calculate height factor: exp(-(y - base) * falloff)
                    float heightFactor = exp(-(currentPos.y - _BaseHeight) * _HeightFalloff);
                    heightFactor = saturate(heightFactor); // Clamp 0-1

                    // --- 3D Noise Logic ---
                    float3 noisePos = currentPos * _NoiseScale + float3(_Time.y * _Speed, 0, 0);
                    // Warp noise based on sanity (world gets chaotic)
                    if(insanity > 0.5) noisePos += Noise3D(noisePos * 2.0) * insanity;
                    
                    float noise = FBM(noisePos);
                    
                    // Combine
                    float localDensity = heightFactor * noise * _FogDensity;
                    
                    // Accumulate
                    accumulatedDensity += localDensity * stepSize;
                    
                    // March forward
                    currentPos += viewDir * stepSize;
                }

                // Beer's Law for Transmittance
                float transmittance = exp(-accumulatedDensity * _Intensity);
                
                // Sample original screen color
                float4 sceneColor = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, input.uv);
                
                // Final blend
                // We blend the fog color based on how much light got blocked (transmittance)
                float3 finalColor = lerp(targetFogColor, sceneColor.rgb, transmittance);

                return float4(finalColor, 1.0);
            }
            ENDHLSL
        }
    }
}