Shader "Custom/CrystalGlass"
{
    Properties
    {
        _BumpMap ("Normal Map", 2D) = "bump" {}
        _Distortion ("Refraction Strength", Range(0, 1)) = 0.1
        _Color ("Tint", Color) = (1,1,1,0.5)
        _Smoothness ("Smoothness", Range(0, 1)) = 0.9
    }
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" }
        ZWrite Off

        Pass
        {
            Tags { "LightMode" = "UniversalForward" }
            
            HLSLPROGRAM
            #include "UnityCG.cginc"
            #pragma vertex vert
            #pragma fragment frag

            // Global Lighting (for Specular)
            #define MAX_LIGHTS 4
            uniform float4 _GlobalLightDir[MAX_LIGHTS];
            uniform float4 _GlobalLightCol[MAX_LIGHTS];

            struct appdata { float4 vertex : POSITION; float3 normal : NORMAL; float2 uv : TEXCOORD0; };
            struct v2f { float4 pos : SV_POSITION; float4 screenPos : TEXCOORD0; float3 normal : NORMAL; float2 uv : TEXCOORD1; float3 worldPos : TEXCOORD3; };

            sampler2D _CameraOpaqueTexture; // Needs URP Opaque Texture ON
            sampler2D _BumpMap;
            float _Distortion;
            float4 _Color;
            float _Smoothness;

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.screenPos = ComputeScreenPos(o.pos);
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.uv = v.uv;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float2 screenUV = i.screenPos.xy / i.screenPos.w;
                float3 normal = UnpackNormal(tex2D(_BumpMap, i.uv));
                
                // 1. Refraction (Warp screen UVs by normal)
                float2 offset = normal.xy * _Distortion;
                float3 bg = tex2D(_CameraOpaqueTexture, screenUV + offset).rgb;

                // 2. Specular Light (Sun)
                float3 lightDir = normalize(-_GlobalLightDir[0].xyz);
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
                float3 H = normalize(lightDir + viewDir);
                float spec = pow(max(dot(i.normal, H), 0.0), _Smoothness * 100);
                
                float3 finalCol = lerp(bg, _Color.rgb, _Color.a); // Tint
                finalCol += spec * _GlobalLightCol[0].rgb; // Add Shine

                return float4(finalCol, 1.0);
            }
            ENDHLSL
        }
    }
}