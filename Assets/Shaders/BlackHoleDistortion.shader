Shader "Custom/BlackHoleDistortion"
{
    Properties
    {
        _DistortionStrength ("Distortion Strength", Range(-2, 2)) = 1.0
        _Radius ("Radius", Range(0, 1)) = 0.5

        _Darkness ("Center Darkness", Range(0, 1)) = 0.8
    }

    SubShader
    {
        Tags
        {
            "Queue"="Transparent"
            "RenderType"="Transparent"
            "IgnoreProjector"="True"
        }

        Pass
        {
            // Forward rendering pass compatible with URP
            Tags { "LightMode" = "UniversalForward" }

            // to avoid blocking background sampling
            ZWrite Off

            Cull Off

            HLSLPROGRAM

            #include "UnityCG.cginc"
            #pragma vertex vert
            #pragma fragment frag

            struct appdata
            {
                float4 vertex : POSITION;

                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                // Clip-space position for rasterization
                float4 pos : SV_POSITION;

                // Object UVs passed to fragment stage
                float2 uv : TEXCOORD0;

                // Screen-space position used for background sampling
                float4 screenPos : TEXCOORD1;
            };

            float _DistortionStrength;
            float _Radius;
            float _Darkness;

            // Camera opaque texture containing the already-rendered scene
            sampler2D _CameraOpaqueTexture;

            v2f vert (appdata v)
            {
                v2f o;

                // Transform vertex to clip space
                o.pos = UnityObjectToClipPos(v.vertex);

                // Pass through object UVs
                o.uv = v.uv;

                // Compute screen-space position for texture projection
                o.screenPos = ComputeScreenPos(o.pos);

                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                // Convert projected screen position into normalized screen UVs
                float2 screenUV = i.screenPos.xy / i.screenPos.w;

                // Define the center of distortion in object UV space
                float2 center = float2(0.5, 0.5);

                // Vector from center to current fragment
                float2 dir = i.uv - center;

                // Distance from the distortion center
                float dist = length(dir);

                // Compute distortion force based on distance from center
                float force = (_Radius - dist) * _DistortionStrength;
                force = max(0.0, force);

                // Offset sampling position toward the center
                float2 offset = normalize(dir) * force;
                float2 distortedUV = screenUV - offset;

                // Sample the background scene with the distorted coordinates
                float4 bg = tex2D(_CameraOpaqueTexture, distortedUV);

                // Darken pixels near the center to simulate an event horizon
                float hole = smoothstep(0.1, 0.0, dist);
                bg.rgb = lerp(bg.rgb, float3(0, 0, 0), hole * _Darkness);

                return bg;
            }

            ENDHLSL
        }
    }
}
