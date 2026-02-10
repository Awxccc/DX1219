Shader "Custom/Glitch"
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
        // Render as opaque geometry in the main geometry queue
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }

        Cull Off

        Pass
        {
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

                float2 uv : TEXCOORD0;

                float3 normal : NORMAL;
            };

            struct v2f
            {
                // Clip-space position for rasterization
                float4 pos : SV_POSITION;

                // Transformed texture coordinates
                float2 uv : TEXCOORD0;

                // World-space normal for lighting
                float3 normal : NORMAL;

                // World-space position for point and spot lighting
                float3 worldPos : TEXCOORD1;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _GlitchColor;
            float _GlitchAmount;
            float _GlitchSpeed;
            float _GlitchFrequency;

            float random(float2 seed)
            {
                // Hash-based pseudo-random generator
                return frac(sin(dot(seed, float2(12.9898, 78.233))) * 43758.5453);
            }

            v2f vert (appdata v)
            {
                v2f o;

                // Generate time-stepped noise to create horizontal glitch bands
                float timeVal = floor(_Time.y * _GlitchSpeed);
                float noise = random(float2(timeVal, v.vertex.y));

                // Default displacement is zero
                float3 displacement = float3(0, 0, 0);

                // Apply displacement only when noise exceeds frequency threshold
                if (noise > (1.0 - _GlitchFrequency))
                {
                    // Push vertices along their normal direction
                    displacement = v.normal * (noise * 2.0 - 1.0) * _GlitchAmount;

                    // Add additional horizontal distortion for visual instability
                    displacement.x += sin(_Time.y * 50.0) * _GlitchAmount * 0.5;
                }

                // Modify vertex position to create glitch geometry distortion
                v.vertex.xyz += displacement;

                // Transform vertex to clip space
                o.pos = UnityObjectToClipPos(v.vertex);

                // Compute world-space position
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

                // Convert normal to world space
                o.normal = UnityObjectToWorldNormal(v.normal);

                // Apply texture tiling and offset
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);

                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                // Apply chromatic aberration by offsetting texture samples per color channel
                float2 uv = i.uv;
                float shift = _GlitchAmount * 0.1 * sin(_Time.y * 20.0);

                float r = tex2D(_MainTex, uv + float2(shift, 0)).r;
                float g = tex2D(_MainTex, uv).g;
                float b = tex2D(_MainTex, uv - float2(shift, 0)).b;

                float3 col = float3(r, g, b);

                // Overlay glitch color during active glitch bands
                float noise = random(float2(floor(_Time.y * _GlitchSpeed), i.worldPos.y));
                if (noise > (1.0 - _GlitchFrequency))
                {
                    col = lerp(col, _GlitchColor.rgb, 0.5);
                }

                // Accumulates lighting contribution from all lights
                float3 totalLight = float3(0, 0, 0);

                // Loop through active custom lights
                for (int k = 0; k < MAX_LIGHTS; k++)
                {
                    if (k >= _ActiveLightCount)
                        break;

                    // Skip lights with no contribution
                    if (length(_GlobalLightCol[k].rgb) <= 0.0)
                        continue;

                    float3 lightColor = _GlobalLightCol[k].rgb;

                    // Light type encoded in alpha channel
                    int type = (int)_GlobalLightCol[k].a;

                    float3 L;
                    float attenuation = 1.0;

                    // Directional lights use a constant direction
                    if (type == 0)
                    {
                        L = normalize(-_GlobalLightDir[k].xyz);
                    }
                    // Point and spot lights depend on distance
                    else
                    {
                        float3 distVec = _GlobalLightPos[k].xyz - i.worldPos;
                        float dist = length(distVec);
                        L = normalize(distVec);

                        // Distance attenuation using constant, linear, and quadratic terms
                        float3 attParams = _GlobalLightAtten[k].xyz;
                        if (length(attParams) == 0)
                            attParams = float3(1, 0.09, 0.032);

                        attenuation = 1.0 / (attParams.x + attParams.y * dist + attParams.z * dist * dist);

                        // Apply spotlight cone attenuation
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

                    // Lambertian diffuse lighting
                    float diff = max(dot(normalize(i.normal), L), 0.0);
                    totalLight += col * diff * lightColor * attenuation;
                }

                // Output final lit color
                return float4(totalLight, 1.0);
            }

            ENDHLSL
        }
    }
}
