Shader "Hidden/Custom/BlackAndWhite"
{
    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            Name "BlackAndWhite"
            ZTest Always
            ZWrite Off
            Cull Off

            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            TEXTURE2D_X(_BlitTexture);
            SAMPLER(sampler_BlitTexture);

            float _Intensity;

            struct appData
            {
                uint vertexID : SV_VertexID;
            };

            struct v2f
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            v2f Vert(appData input)
            {
                v2f o;

                //Fullscreen triangle UV from vertexID (0,1,2)
                float2 uv = float2((input.vertexID << 1) & 2,input.vertexID & 2);
                o.uv = uv;
                o.positionHCS = float4(uv * 2.0f - 1.0f, 0.0f, 1.0f);
                #if UNITY_UV_STARTS_AT_TOP
                o.uv.y = 1.0f - o.uv.y;
                #endif
                return o;
                }

            half4 frag(v2f i) : SV_Target
            {
                //Sample camera color
                float4 col = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv);
                
                //Luminance (Rec.709)
                float gray = dot(col.rgb,float3(0.2126,0.7152, 0.0722));

                float bw = float3(gray,gray, gray);

                //Blend based on volume intensity
                float t = saturate(_Intensity);
                float3 outRgb = lerp(col.rgb, bw, t);

                return float4(outRgb, col.a);
            }
            ENDHLSL
        }
    }
}
