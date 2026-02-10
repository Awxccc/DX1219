Shader "Hidden/Custom/Psychosis"
{
    Properties
    {
        _MainTex ("Source", 2D) = "white" {}
        _Intensity ("Intensity", Float) = 0
        _GrainStrength ("Grain Strength", Float) = 0.5
        _VignetteStrength ("Vignette Strength", Float) = 0.5
        _AberrationStrength ("Aberration Strength", Float) = 0.5
        _BreathingSpeed ("Breathing Speed", Float) = 2.0
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }
        LOD 100
        ZWrite Off Cull Off ZTest Always

        Pass
        {
            Name "PsychosisPass"

            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"

            #pragma vertex Vert
            #pragma fragment Frag

            TEXTURE2D(_BlitTexture);
            SAMPLER(sampler_BlitTexture);

            float _Intensity;
            float _GrainStrength;
            float _VignetteStrength;
            float _AberrationStrength;
            float _BreathingSpeed;

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

            half4 Frag(Varyings input) : SV_Target
            {
                float2 uv = input.uv;

                // --- 1. Breathing / Warping Effect ---
                // Simulates the screen expanding and contracting like a panicked lung
                float2 center = float2(0.5, 0.5);
                float2 dir = uv - center;
                float dist = length(dir);
                
                // Sin wave based on time for pulsing
                float breath = sin(_Time.y * _BreathingSpeed) * 0.03 * _Intensity;
                
                // Warp the UVs away from center based on breath
                float2 warpedUV = center + dir * (1.0 - breath * dist);

                // --- 2. Chromatic Aberration ---
                // Split RGB channels based on distance from center
                float aberration = _AberrationStrength * _Intensity * 0.05 * (1.0 + dist);
                
                float4 colorR = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, warpedUV - float2(aberration, 0));
                float4 colorG = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, warpedUV);
                float4 colorB = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, warpedUV + float2(aberration, 0));
                
                float4 finalColor = float4(colorR.r, colorG.g, colorB.b, 1.0);

                // --- 3. Desaturation (Losing color as you go insane) ---
                float luminance = Luminance(finalColor.rgb);
                float3 bwColor = float3(luminance, luminance, luminance);
                // We mix based on intensity, but keep some color (0.8 instead of 1.0) for style
                finalColor.rgb = lerp(finalColor.rgb, bwColor, _Intensity * 0.8);

                // --- 4. Vignette ---
                float2 coord = (uv - 0.5) * 2.0;
                float rf = sqrt(dot(coord, coord)) * _VignetteStrength * (1.0 + _Intensity); 
                float rf2_1 = rf * rf + 1.0;
                float e = 1.0 / (rf2_1 * rf2_1);
                finalColor.rgb *= e;

                // --- 5. Film Grain ---
                float noise = Random(uv + _Time.y);
                float3 grain = float3(noise, noise, noise);
                // Grain is added, not multiplied, for a grittier overlay
                finalColor.rgb += grain * _GrainStrength * _Intensity * 0.15;

                return finalColor;
            }
            ENDHLSL
        }
    }
}