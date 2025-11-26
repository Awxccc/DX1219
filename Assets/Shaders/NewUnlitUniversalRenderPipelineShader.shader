Shader "Custom/NewUnlitUniversalRenderPipelineShader"
{
    SubShader
    {
        Pass
        {
            HLSLPROGRAM
            #include "UnityCG.cginc"

            #pragma vertex MyVertexShader
            #pragma fragment MyFragmentShader
            float4 _tint;

            struct vertexData
            {
                float4 position: POSITION;
                float2 uv: TEXCOORD0;
            };

            struct vertex2Fragment
            {
                float4 position: SV_POSITION;
                float2 uv: TEXCOORD0;
            };

            vertex2Fragment MyVertexShader(vertexData vd)
            {
                vertex2Fragment v2f;
                v2f.position = UnityObjectToClipPos(vd.position);
                v2f.uv = vd.uv;
                return v2f;
            }

            float4 MyFragmentShader(vertex2Fragment v2f) : SV_TARGET
            {
                for(int i = 0;v2f.uv.x < 0.01; i++)
                {
                    return _tint;
                }
                if(v2f.uv.x > 0.5)
                {
                    return _tint;
                }
                else
                return float4(v2f.uv,10.0,1.0f);
            }

            ENDHLSL
        }
    }
}
