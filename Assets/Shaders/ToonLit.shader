Shader "Custom/ToonLit"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color ("Color", Color) = (1,1,1,1)
        _RampThreshold ("Ramp Threshold", Range(0,1)) = 0.5
        _RampSmoothness ("Ramp Smoothness", Range(0,0.1)) = 0.01
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }
        LOD 100

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" } // Important for URP

            HLSLPROGRAM
            #include "UnityCG.cginc"
            #pragma vertex vert
            #pragma fragment frag

            // Use our Global Lighting System
            #define MAX_LIGHTS 4
            uniform float4 _GlobalLightDir[MAX_LIGHTS];
            uniform float4 _GlobalLightCol[MAX_LIGHTS];

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            sampler2D _MainTex; float4 _MainTex_ST;
            float4 _Color;
            float _RampThreshold;
            float _RampSmoothness;

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float3 normal = normalize(i.normal);
                
                // Lighting from Light 0 (Sun)
                float3 lightDir = normalize(-_GlobalLightDir[0].xyz);
                float NdotL = dot(normal, lightDir);
                
                // Cel Shading Math
                float intensity = smoothstep(_RampThreshold - _RampSmoothness, _RampThreshold + _RampSmoothness, NdotL);
                float3 lightCol = _GlobalLightCol[0].rgb * (intensity * 0.8 + 0.2); // +0.2 Ambient

                float4 col = tex2D(_MainTex, i.uv) * _Color;
                return float4(col.rgb * lightCol, 1.0);
            }
            ENDHLSL
        }
    }
}