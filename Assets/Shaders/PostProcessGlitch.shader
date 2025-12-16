Shader "Custom/GlitchSurface3D"
{
    Properties
    {
        _MainTex ("Albedo", 2D) = "white" {}
        _GlitchColor ("Glitch Color", Color) = (1, 0, 1, 1)
        _GlitchAmount ("Glitch Intensity", Range(0, 0.5)) = 0.1
        _GlitchSpeed ("Glitch Speed", Range(0, 50)) = 10.0
        _GlitchFrequency ("Frequency", Range(0, 1)) = 0.5
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }
        Cull Off

        Pass
        {
            HLSLPROGRAM
            #include "UnityCG.cginc"
            #pragma vertex vert
            #pragma fragment frag

            // Global Lighting
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
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float3 worldPos : TEXCOORD1;
            };

            sampler2D _MainTex; float4 _MainTex_ST;
            float4 _GlitchColor;
            float _GlitchAmount;
            float _GlitchSpeed;
            float _GlitchFrequency;

            float random(float2 seed)
            {
                return frac(sin(dot(seed, float2(12.9898, 78.233))) * 43758.5453);
            }

            v2f vert (appdata v)
            {
                v2f o;
                
                // 1. Calculate Random Jitter
                // Use time and vertex Y position to create "bands" of glitch
                float timeVal = floor(_Time.y * _GlitchSpeed);
                float noise = random(float2(timeVal, v.vertex.y));
                
                // Only glitch if noise is above frequency threshold
                float3 displacement = float3(0,0,0);
                if(noise > (1.0 - _GlitchFrequency))
                {
                    displacement = v.normal * (noise * 2.0 - 1.0) * _GlitchAmount;
                    // Stretch geometry
                    displacement.x += sin(_Time.y * 50.0) * _GlitchAmount * 0.5;
                }

                v.vertex.xyz += displacement;

                o.pos = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                // 2. Chromatic Aberration on Surface
                // Sample texture with slight offsets for R and B channels
                float2 uv = i.uv;
                float shift = _GlitchAmount * 0.1 * sin(_Time.y * 20.0);
                
                float r = tex2D(_MainTex, uv + float2(shift, 0)).r;
                float g = tex2D(_MainTex, uv).g;
                float b = tex2D(_MainTex, uv - float2(shift, 0)).b;
                
                float3 col = float3(r,g,b);

                // Add Glitch Color Overlay on glitch "bands"
                float noise = random(float2(floor(_Time.y * _GlitchSpeed), i.worldPos.y));
                if(noise > (1.0 - _GlitchFrequency))
                {
                    col = lerp(col, _GlitchColor.rgb, 0.5);
                }

                float3 totalLight = float3(0,0,0);
                
                // Make sure to add 'uniform int _ActiveLightCount;' at the top of the HLSLPROGRAM if missing!
                for(int k = 0; k < MAX_LIGHTS; k++)
                {
                    // Skip inactive lights (black color or active count check)
                    if(length(_GlobalLightCol[k].rgb) <= 0.0) continue;

                    float3 lightColor = _GlobalLightCol[k].rgb;
                    int type = (int)_GlobalLightCol[k].a; // 0=Dir, 1=Point, 2=Spot

                    float3 L;
                    float attenuation = 1.0;

                    if(type == 0) // Directional
                    {
                        L = normalize(-_GlobalLightDir[k].xyz);
                    }
                    else // Point or Spot
                    {
                        if(type == 2) // Spot
                        {
                            float theta = dot(L, normalize(-_GlobalLightDir[k].xyz));
                            float outer = _GlobalSpotParams[k].x; // Needs uniform float4 _GlobalSpotParams[MAX_LIGHTS];
                            float inner = _GlobalSpotParams[k].y;
                            float epsilon = inner - outer;
                            float intensity = clamp((theta - outer) / epsilon, 0.0, 1.0);
                            attenuation *= intensity;
                        }
                        // Calculate vector from Light to Pixel
                        float3 distVec = _GlobalLightPos[k].xyz - i.worldPos;
                        float dist = length(distVec);
                        L = normalize(distVec);
                        
                        // Simple Attenuation (1 / distance^2)
                        // You can tweak these values (1.0, 0.09, 0.032) to match your light script
                        attenuation = 1.0 / (1.0 + 0.09 * dist + 0.032 * dist * dist);
                    }

                    // Diffuse Calculation
                    float diff = max(dot(i.normal, L), 0.0);
                    
                    // Add this light's contribution
                    totalLight += col * diff * lightColor * attenuation;
                }
                
                return float4(totalLight, 1.0);
            }
            ENDHLSL
        }
    }
}