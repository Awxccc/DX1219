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
        // Render as opaque geometry in the main geometry queue
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }
        LOD 100

        Pass
        {
            // Forward rendering pass compatible with URP
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM

            #include "UnityCG.cginc"
            #pragma vertex vert
            #pragma fragment frag
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
                // Clip-space position for rasterization
                float4 pos : SV_POSITION;

                // World-space normal used for lighting
                float3 normal : NORMAL;

                // Transformed texture coordinates
                float2 uv : TEXCOORD0;

                // World-space position used for point and spot lights
                float3 worldPos : TEXCOORD1;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _Color;
            float _RampThreshold;
            float _RampSmoothness;

            v2f vert (appdata v)
            {
                v2f o;

                // Transform vertex position to clip space
                o.pos = UnityObjectToClipPos(v.vertex);

                // Convert normal from object space to world space
                o.normal = UnityObjectToWorldNormal(v.normal);

                // Apply texture tiling and offset
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);

                // Compute world-space position for lighting calculations
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                // Normalize interpolated surface normal
                float3 normal = normalize(i.normal);

                // Accumulates lighting contribution from all lights
                float3 totalLight = float3(0, 0, 0);

                // Sample base color and apply tint
                float4 albedo = tex2D(_MainTex, i.uv) * _Color;

                // Loop through all active custom lights
                for (int k = 0; k < MAX_LIGHTS; k++)
                {
                    if (k >= _ActiveLightCount)
                        break;

                    // Skip lights with zero contribution
                    if (length(_GlobalLightCol[k].rgb) <= 0.0)
                        continue;

                    float3 lightColor = _GlobalLightCol[k].rgb;

                    // Light type is encoded in the alpha channel
                    int type = (int)_GlobalLightCol[k].a;

                    float3 L;
                    float attenuation = 1.0;

                    // Directional light uses a constant direction
                    if (type == 0)
                    {
                        L = normalize(-_GlobalLightDir[k].xyz);
                    }
                    // Point and spot lights depend on distance and position
                    else
                    {
                        float3 distVec = _GlobalLightPos[k].xyz - i.worldPos;
                        float dist = length(distVec);
                        L = normalize(distVec);

                        // Distance attenuation using constant, linear, and quadratic terms
                        float3 att = _GlobalLightAtten[k].xyz;
                        attenuation = 1.0 / (att.x + att.y * dist + att.z * dist * dist);

                        // Additional angular attenuation for spot lights
                        if (type == 2)
                        {
                            float theta = dot(L, normalize(-_GlobalLightDir[k].xyz));
                            float outer = _GlobalSpotParams[k].x;
                            float inner = _GlobalSpotParams[k].y;
                            float epsilon = inner - outer;

                            float spotIntensity = clamp((theta - outer) / epsilon, 0.0, 1.0);
                            attenuation *= spotIntensity;
                        }
                    }

                    // Toon shading: convert smooth lighting into hard bands
                    float NdotL = dot(normal, L);
                    float intensity = smoothstep(
                        _RampThreshold - _RampSmoothness,
                        _RampThreshold + _RampSmoothness,
                        NdotL
                    );

                    // Accumulate final lighting contribution
                    totalLight += albedo.rgb * lightColor * intensity * attenuation;
                }

                // Output final shaded color with full opacity
                return float4(totalLight, 1.0);
            }

            ENDHLSL
        }
    }
}
