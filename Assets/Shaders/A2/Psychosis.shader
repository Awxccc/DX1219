Shader "Hidden/Custom/Psychosis"
{
    Properties
    {
        _MainTex ("Source", 2D) = "white" {}
        _Intensity ("Intensity", Float) = 0
        _GrainStrength ("Grain Strength", Float) = 0.5
        _VignetteStrength ("Vignette Strength", Float) = 0.5
        _AberrationStrength ("Aberration Strength", Float) = 0.5
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
            float _GrainStrength;
            float _VignetteStrength;
            float _AberrationStrength;

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
                
                float aberration = _AberrationStrength * _Intensity * 0.02;
                float4 colorR = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv - float2(aberration, 0));
                float4 colorG = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
                float4 colorB = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(aberration, 0));
                
                float4 finalColor = float4(colorR.r, colorG.g, colorB.b, 1.0);

                float luminance = Luminance(finalColor.rgb);
                float3 bwColor = float3(luminance, luminance, luminance);
                finalColor.rgb = lerp(finalColor.rgb, bwColor, _Intensity);

                float2 coord = (uv - 0.5) * 2.0;
                float rf = sqrt(dot(coord, coord)) * _VignetteStrength * _Intensity;
                float rf2_1 = rf * rf + 1.0;
                float e = 1.0 / (rf2_1 * rf2_1);
                finalColor.rgb *= e;

                float noise = Random(uv + _Time.y);
                float3 grain = float3(noise, noise, noise);
                finalColor.rgb += grain * _GrainStrength * _Intensity * 0.1;

                return finalColor;
            }
            ENDHLSL
        }
    }
}