Shader "Hidden/Custom/Glitch"
{
    Properties
    {
        _MainTex ("Source", 2D) = "white" {}
        _Intensity ("Intensity", Float) = 0
        _ScanlineStrength ("Scanline", Float) = 0.5
        _NoiseScale ("Noise Scale", Float) = 10
        _ColorDrift ("Color Drift", Float) = 0.02
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }
        LOD 100
        ZWrite Off Cull Off ZTest Always

        Pass
        {
            Name "GlitchPass"

            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"

            #pragma vertex Vert
            #pragma fragment Frag

            TEXTURE2D(_BlitTexture);
            SAMPLER(sampler_BlitTexture);

            float _Intensity;
            float _ScanlineStrength;
            float _NoiseScale;
            float _ColorDrift;

            struct Attributes
            {
                uint vertexID : SV_VertexID;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            Varyings Vert(Attributes input)
            {
                Varyings output;
                UNITY_SETUP_INSTANCE_ID(input);
                output.positionCS = GetFullScreenTriangleVertexPosition(input.vertexID);
                output.uv = GetFullScreenTriangleTexCoord(input.vertexID);
                return output;
            }

            float Random(float2 uv)
            {
                return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453123);
            }

            // A noise function that snaps to a grid (Blocky)
            float BlockNoise(float2 uv, float scale, float time)
            {
                float2 blockPos = floor(uv * scale) / scale;
                return Random(blockPos + time);
            }

            half4 Frag(Varyings input) : SV_Target
            {
                float2 uv = input.uv;
                float time = _Time.y;

                // 1. Calculate Block Displacements
                // We create large blocks that shift the screen horizontally
                float noiseVal = BlockNoise(uv, _NoiseScale, floor(time * 20.0)); // Stuttery time
                
                // Only displace if noise is high (create gaps)
                float displacement = 0.0;
                if(noiseVal > (1.0 - _Intensity * 0.7)) // More intensity = more frequent blocks
                {
                    displacement = (noiseVal - 0.5) * _Intensity * 0.2;
                }
                
                float2 displacedUV = uv;
                displacedUV.x += displacement;

                // 2. Vertical Jitter (V-Sync failure)
                // Occasionally jump the Y coordinate
                float jump = Random(float2(time, time)) * _Intensity;
                if(jump > 0.8) displacedUV.y += jump * 0.05;

                // 3. RGB Color Drift (The "Tearing" effect)
                // Instead of sampling once, we sample 3 times with vertical/horizontal offsets
                float drift = _ColorDrift * _Intensity;
                
                float r = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, displacedUV + float2(drift, 0)).r;
                float g = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, displacedUV).g;
                float b = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, displacedUV - float2(drift, 0)).b;

                // 4. Scanlines
                float scanline = sin(uv.y * 800.0 + time * 10.0) * 0.5 + 0.5;
                float3 finalColor = float3(r, g, b);
                
                // Darken scanlines based on intensity
                finalColor -= scanline * _ScanlineStrength * _Intensity * 0.5;

                return float4(finalColor, 1.0);
            }
            ENDHLSL
        }
    }
}