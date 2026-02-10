Shader "Hidden/Custom/NightmareGlitch"
{
    Properties
    {
        _MainTex ("Source", 2D) = "white" {}
        _Intensity ("Glitch Intensity", Range(0, 1)) = 0
        _ScanlineIntensity ("Scanline Strength", Range(0, 1)) = 0.5
        _NoiseScale ("Noise Scale", Float) = 10
        _ChromaticAberration ("Chromatic Aberration", Range(0, 50)) = 10
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }
        LOD 100
        ZTest Always ZWrite Off Cull Off

        Pass
        {
            Name "NightmareGlitchPass"

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            float _Intensity;
            float _ScanlineIntensity;
            float _NoiseScale;
            float _ChromaticAberration;

            // Simple noise function
            float random(float2 uv)
            {
                return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453123);
            }

            Varyings Vert(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = input.uv;
                return output;
            }

            float4 Frag(Varyings input) : SV_Target
            {
                float2 uv = input.uv;
                float time = _Time.y;

                // 1. Vertical Jump (Twitching)
                float jump = lerp(0, 0.2, _Intensity) * step(0.95, random(float2(time * 10, 0)));
                uv.y += jump;

                // 2. Horizontal Shake (Tearing)
                float shake = (random(float2(time, uv.y * _NoiseScale)) - 0.5) * _Intensity * 0.1;
                uv.x += shake;

                // 3. Chromatic Aberration (Splitting Colors)
                float aberration = _ChromaticAberration * _Intensity * 0.01;
                float2 rOffset = float2(aberration, 0);
                float2 bOffset = float2(-aberration, 0);

                float r = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + rOffset).r;
                float g = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv).g;
                float b = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + bOffset).b;

                // 4. Scanlines
                float scanline = sin(input.uv.y * 800.0) * 0.5 + 0.5;
                float3 color = float3(r, g, b);
                
                // Blend scanlines based on intensity
                color = lerp(color, color * scanline, _ScanlineIntensity * _Intensity);

                // 5. Noise Grain in dark areas (Horror atmosphere)
                float noise = random(uv * time) * _Intensity * 0.2;
                color += noise;

                return float4(color, 1.0);
            }
            ENDHLSL
        }
    }
}