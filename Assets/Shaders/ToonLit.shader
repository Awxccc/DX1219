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
            uniform float4 _GlobalLightCol[MAX_LIGHTS];
            uniform float4 _GlobalLightDir[MAX_LIGHTS];
            uniform float4 _GlobalLightPos[MAX_LIGHTS];
            uniform float4 _GlobalLightAtten[MAX_LIGHTS];
            uniform float4 _GlobalSpotParams[MAX_LIGHTS];
            uniform int _ActiveLightCount;

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
    float3 worldPos : TEXCOORD1; // Add this
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
    o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz; // Add this
    return o;
}

            float4 frag (v2f i) : SV_Target
        {
            float3 normal = normalize(i.normal);
            float3 totalLight = float3(0,0,0);
            float4 albedo = tex2D(_MainTex, i.uv) * _Color;

            for(int k = 0; k < MAX_LIGHTS; k++)
            {
                if(k >= _ActiveLightCount) break;
                if(length(_GlobalLightCol[k].rgb) <= 0.0) continue;

                float3 lightColor = _GlobalLightCol[k].rgb;
                int type = (int)_GlobalLightCol[k].a;

                float3 L;
                float attenuation = 1.0;

                if(type == 0) // Dir
                {
                    L = normalize(-_GlobalLightDir[k].xyz);
                }
                else // Point/Spot
                {
                    float3 distVec = _GlobalLightPos[k].xyz - i.worldPos;
                    float dist = length(distVec);
                    L = normalize(distVec);

                    // Attenuation
                    float3 att = _GlobalLightAtten[k].xyz;
                    attenuation = 1.0 / (att.x + att.y * dist + att.z * dist * dist);

                    if(type == 2) // Spot
                    {
                        float theta = dot(L, normalize(-_GlobalLightDir[k].xyz));
                        float outer = _GlobalSpotParams[k].x;
                        float inner = _GlobalSpotParams[k].y;
                        float epsilon = inner - outer;
                        float intensity = clamp((theta - outer) / epsilon, 0.0, 1.0);
                        attenuation *= intensity;
                    }
                }

                // Cel Shading Math (Per light)
                float NdotL = dot(normal, L);
                float intensity = smoothstep(_RampThreshold - _RampSmoothness, _RampThreshold + _RampSmoothness, NdotL);

                totalLight += albedo.rgb * lightColor * intensity * attenuation;
            }

            return float4(totalLight, 1.0);
            }
            ENDHLSL
        }
    }
}