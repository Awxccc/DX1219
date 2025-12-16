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
        // Must be Transparent to see behind it
        Tags { "Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True" }
        
        Pass
        {
            Tags { "LightMode" = "UniversalForward" }
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
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 screenPos : TEXCOORD1;
            };

            float _DistortionStrength;
            float _Radius;
            float _Darkness;

            // URP Camera Texture Declaration
            // Note: In strict URP HLSL we might use macros, but for UnityCG compatibility in custom pipeline:
            sampler2D _CameraOpaqueTexture; 

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.screenPos = ComputeScreenPos(o.pos);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                // 1. Calculate Screen Coordinates
                float2 screenUV = i.screenPos.xy / i.screenPos.w;

                // 2. Calculate vector from center of object UVs (assuming Quad/Sphere mapping)
                // Center is 0.5, 0.5
                float2 center = float2(0.5, 0.5);
                float2 dir = i.uv - center;
                float dist = length(dir);

                // 3. Warp Logic
                // Strength decreases as we get further from center
                float force = (_Radius - dist) * _DistortionStrength;
                force = max(0, force); // Clamp so it doesn't warp backwards outside radius

                // Offset the screen sampling coordinate
                float2 offset = normalize(dir) * force;
                float2 distortedUV = screenUV - offset;

                // 4. Sample the Background
                // Note: You must enable "Opaque Texture" in your URP Asset settings for this to work!
                float4 bg = tex2D(_CameraOpaqueTexture, distortedUV);

                // 5. Darken Center (Event Horizon)
                float hole = smoothstep(0.1, 0.0, dist);
                bg.rgb = lerp(bg.rgb, float3(0,0,0), hole * _Darkness);

                return bg;
            }
            ENDHLSL
        }
    }
}