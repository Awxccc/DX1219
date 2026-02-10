Shader "Hidden/Custom/Glitch"
{
    Properties
    {
        _MainTex ("Source", 2D) = "white" {}
        _Intensity ("Intensity", Float) = 0
        _ScanlineStrength ("Scanline", Float) = 0.5
        _NoiseScale ("Noise Scale", Float) = 10
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

            #pragma vertex Vert
            #pragma fragment Frag

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
            float _ScanlineStrength;
            float _NoiseScale;

            Varyings Vert(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = input.uv;
                return output;
            }

            float Random(float2 uv)
            {
                return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453123);
            }

            half4 Frag(Varyings input) : SV_Target
            {
                float2 uv = input.uv;
                float time = _Time.y;

                float splitAmount = _Intensity * 0.05;
                float2 blockNoise = floor(uv * _NoiseScale) / _NoiseScale;
                float displacement = Random(blockNoise + time) * _Intensity * 0.1;
                
                if(displacement > 0.05) uv.x += displacement;

                float r = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(splitAmount, 0)).r;
                float g = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv).g;
                float b = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv - float2(splitAmount, 0)).b;

                float scanline = sin(input.uv.y * 800.0 + time * 10.0) * 0.5 + 0.5;
                float3 finalColor = float3(r, g, b);
                
                finalColor -= scanline * _ScanlineStrength * _Intensity;

                return float4(finalColor, 1.0);
            }
            ENDHLSL
        }
    }
}