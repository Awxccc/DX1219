Shader "Hidden/Custom/Bloom"
{
    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        
        TEXTURE2D_X(_BlitTexture);
        SAMPLER(sampler_BlitTexture);
        TEXTURE2D_X(_SourceTexture);
        SAMPLER(sampler_SourceTexture);

        float _Threshold;
        float _Intensity;
        
        struct appdata { uint vertexID : SV_VertexID; };
        struct v2f { float4 positionHCS : SV_POSITION; float2 uv : TEXCOORD0; };

        v2f Vert(appdata input)
        {
            v2f o;
            float2 uv = float2((input.vertexID << 1) & 2, input.vertexID & 2);
            o.uv = uv;
            o.positionHCS = float4(uv * 2.0 - 1.0, 0.0, 1.0);
            #if UNITY_UV_STARTS_AT_TOP
            o.uv.y = 1.0 - o.uv.y;
            #endif
            return o;
        }
        ENDHLSL

        // Pass 0: Threshold (Extract Bright Areas)
        Pass
        {
            Name "Bloom Threshold"
            ZTest Always ZWrite Off Cull Off
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment FragThreshold

            half4 FragThreshold(v2f i) : SV_Target
            {
                float4 col = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv);
                float brightness = max(col.r, max(col.g, col.b));
                float contribution = max(0, brightness - _Threshold);
                return col * contribution;
            }
            ENDHLSL
        }

        // Pass 1: Combine (Add Bloom to Original)
        Pass
        {
            Name "Bloom Combine"
            ZTest Always ZWrite Off Cull Off
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment FragCombine

            half4 FragCombine(v2f i) : SV_Target
            {
                float4 original = SAMPLE_TEXTURE2D_X(_SourceTexture, sampler_SourceTexture, i.uv);
                float4 bloom = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv);
                return original + (bloom * _Intensity);
            }
            ENDHLSL
        }
    }
}