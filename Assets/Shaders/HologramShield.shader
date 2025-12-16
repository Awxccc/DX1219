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
        Tags
        {
            "Queue"="Transparent"
            "RenderType"="Transparent"
        }

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
                // Clip-space position
                float4 pos : SV_POSITION;

                // View direction in world space
                float3 viewDir : TEXCOORD0;

                // World-space surface normal
                float3 normal : NORMAL;

                // UV coordinates
                float2 uv : TEXCOORD1;

                // World-space position
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

                // Periodic vertex displacement to simulate hologram instability
                float glitch = sin(_Time.y * 50.0 + v.vertex.y * 10.0) * _GlitchIntensity;

                // Apply glitch only during brief time windows
                if (sin(_Time.y * 10.0) > 0.95)
                {
                    v.vertex.xyz += v.normal * glitch;
                }

                // Transform vertex to clip space
                o.pos = UnityObjectToClipPos(v.vertex);

                // Compute world-space position and normal
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.normal = UnityObjectToWorldNormal(v.normal);

                // Compute view direction from camera to fragment
                o.viewDir = normalize(_WorldSpaceCameraPos - o.worldPos);

                // Pass through UVs
                o.uv = v.uv;

                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                // Fresnel term for rim-lighting effect
                float NdotV = 1.0 - saturate(dot(i.normal, i.viewDir));
                float rim = pow(NdotV, _RimPower);

                // Generate scrolling scanlines using world-space height
                float scanPos = i.worldPos.y * _ScanDensity - _Time.y * _ScanSpeed;
                float scanLine = tex2D(_ScanTexture, float2(0.5, scanPos)).r;

                // Combine rim glow and scanline emission
                float3 emission = _MainColor.rgb * rim;
                emission += _MainColor.rgb * scanLine * 0.5;

                // Alpha driven by rim strength and scanline visibility
                float alpha = rim + (scanLine * 0.2);

                return float4(emission, saturate(alpha));
            }

            ENDHLSL
        }
    }
}
