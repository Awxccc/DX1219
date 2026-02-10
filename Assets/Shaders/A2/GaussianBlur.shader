Shader "Hidden/Custom/GaussianBlur"
{
    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" }
        
        Pass
        {
            Name "GaussianBlur"
            ZTest Always
            ZWrite Off
            Cull Off

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"

            TEXTURE2D_X(_BlitTexture);
            SAMPLER(sampler_BlitTexture);

            float _Intensity;
            float4 _Direction; 
            float4 _TexelSize; 
            float _Radius;

            struct appdata
            {
                uint vertexID : SV_VertexID;
            };

            struct v2f
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            float GaussianWeight(float x, float sigma)
            {
                float s2 = max(sigma * sigma, 1e-5);
                return exp(-(x * x) / (2.0 * s2));
            }

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

            half4 Frag(v2f i) : SV_Target
            {
                float4 src = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv);
                float t = saturate(_Intensity);
                
                if (t <= 0.0001)
                    return src;

                const int MAX_RADIUS = 16;
                int radius = (int)round(clamp(_Radius, 0.0, (float)MAX_RADIUS));

                if (radius <= 0)
                    return src;

                float sigma = max(radius / 2.0, 1.0);
                float2 stepUV = _Direction.xy * _TexelSize.xy;

                float4 sum = src;
                float wsum = 1.0;

                for (int k = 1; k <= MAX_RADIUS; k++)
                {
                    if (k > radius)
                        break;

                    float w = GaussianWeight((float)k, sigma);
                    float2 o = stepUV * (float)k;

                    sum += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv + o) * w;
                    sum += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv - o) * w;
                    wsum += 2.0 * w;
                }

                float4 blur = sum / max(wsum, 1e-5);
                return lerp(src, blur, t);
            }
            ENDHLSL
        }
    }
    Fallback Off
}