Shader "Custom/HexagonShield"
{
    Properties
    {
        _MainColor ("Shield Color", Color) = (0, 1, 0, 1)
        _GridColor ("Grid Color", Color) = (1, 1, 1, 1)
        _Scale ("Grid Scale", Float) = 10.0
        _Thickness ("Line Thickness", Range(0, 0.5)) = 0.05
        _RimPower ("Rim Power", Range(0.5, 8.0)) = 3.0
    }
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" }
        Blend SrcAlpha One
        ZWrite Off

        Pass
        {
            HLSLPROGRAM
            #include "UnityCG.cginc"
            #pragma vertex vert
            #pragma fragment frag

            struct appdata { float4 vertex : POSITION; float3 normal : NORMAL; float2 uv : TEXCOORD0; };
            struct v2f { float4 pos : SV_POSITION; float3 worldPos : TEXCOORD0; float3 normal : NORMAL; float2 uv : TEXCOORD1; };

            float4 _MainColor;
            float4 _GridColor;
            float _Scale;
            float _Thickness;
            float _RimPower;

            // Mathematical Hexagon Function
            float HexDist(float2 p) 
            {
                p = abs(p);
                float c = dot(p, normalize(float2(1, 1.73)));
                c = max(c, p.x);
                return c;
            }

            float4 HexCoords(float2 uv) 
            {
                float2 r = float2(1, 1.73);
                float2 h = r * 0.5;
                float2 a = fmod(uv, r) - h;
                float2 b = fmod(uv - h, r) - h;
                float2 gv = dot(a, a) < dot(b, b) ? a : b;
                return float4(gv.x, gv.y, 0, 0); // Local hex coords
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.uv = v.uv * _Scale; // Scale UVs for grid
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                // 1. Generate Hexagon Grid
                float4 hex = HexCoords(i.uv);
                float dist = HexDist(hex.xy);
                
                // Pulse effect
                float pulse = sin(_Time.y * 2.0 + i.worldPos.y) * 0.5 + 0.5;
                
                // Draw Lines
                float grid = smoothstep(0.5 - _Thickness, 0.5, dist);
                
                // 2. Rim Light
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
                float rim = pow(1.0 - saturate(dot(i.normal, viewDir)), _RimPower);

                float4 finalColor = _MainColor * (pulse * 0.5 + 0.5);
                finalColor += _GridColor * grid * 2.0; // Add glowing grid
                finalColor *= rim; // Fade edges based on view angle

                return finalColor;
            }
            ENDHLSL
        }
    }
}