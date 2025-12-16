Shader "Custom/HologramShield"
{
    Properties
    {
        _MainColor ("Holo Color", Color) = (0, 1, 1, 1)
        _RimPower ("Rim Power", Range(0.5, 8.0)) = 3.0
        _ScanTexture ("Scanline Pattern", 2D) = "white" {}
        _ScanSpeed ("Scan Speed", Float) = 1.0
        _ScanDensity ("Scan Density", Float) = 10.0
        _GlitchIntensity ("Glitch Intensity", Range(0, 0.1)) = 0.02
    }
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" }
        // Additive Blending makes it look like light
        Blend SrcAlpha One
        ZWrite Off

        Pass
        {
            HLSLPROGRAM
            #include "UnityCG.cginc"
            #pragma vertex vert
            #pragma fragment frag

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 viewDir : TEXCOORD0;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD1;
                float3 worldPos : TEXCOORD3;
            };

            float4 _MainColor;
            float _RimPower;
            sampler2D _ScanTexture;
            float _ScanSpeed;
            float _ScanDensity;
            float _GlitchIntensity;

            v2f vert (appdata v)
            {
                v2f o;
                
                // Vertex Jitter (Glitch Effect)
                float glitch = sin(_Time.y * 50.0 + v.vertex.y * 10.0) * _GlitchIntensity;
                // Only glitch occasionally
                if(sin(_Time.y * 10.0) > 0.95)
                {
                    v.vertex.xyz += v.normal * glitch;
                }

                o.pos = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.viewDir = normalize(_WorldSpaceCameraPos - o.worldPos);
                o.uv = v.uv;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                // 1. Fresnel / Rim Effect
                float NdotV = 1.0 - saturate(dot(i.normal, i.viewDir));
                float rim = pow(NdotV, _RimPower);

                // 2. Scanlines
                // Use World Position Y to create horizontal bars independent of UV
                float scanPos = i.worldPos.y * _ScanDensity - _Time.y * _ScanSpeed;
                float scanLine = tex2D(_ScanTexture, float2(0.5, scanPos)).r;
                
                // Combine
                float3 emission = _MainColor.rgb * rim;
                emission += _MainColor.rgb * scanLine * 0.5; // Add scanlines

                // Fade out center (Hologram style)
                float alpha = rim + (scanLine * 0.2);
                
                return float4(emission, saturate(alpha));
            }
            ENDHLSL
        }
    }
}