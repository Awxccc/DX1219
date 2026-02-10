Shader "Custom/VolumetricFog"
{
    Properties
    {
        _FogColor ("Fog Color", Color) = (1,1,1,1)

        _Density ("Density", Range(0, 2)) = 0.5

        _StepSize ("Step Size", Range(0.01, 0.5)) = 0.1

        _NoiseTex ("Noise Texture (3D Look)", 2D) = "white" {}

        _ScrollSpeed ("Flow Speed", Vector) = (0.1, 0.05, 0, 0)
    }

    SubShader
    {
        Tags { "Queue"="Transparent+100" "RenderType"="Transparent" }

        // Standard alpha blending for volumetric accumulation
        Blend SrcAlpha OneMinusSrcAlpha

        // Disable depth writing so fog does not occlude geometry
        ZWrite Off

        Cull Front

        Pass
        {
            HLSLPROGRAM

            #include "UnityCG.cginc"
            #pragma vertex vert
            #pragma fragment frag

            #define MAX_LIGHTS 4

            uniform float4 _GlobalLightPos[MAX_LIGHTS];
            uniform float4 _GlobalLightCol[MAX_LIGHTS];
            uniform float4 _GlobalLightDir[MAX_LIGHTS];
            uniform float4 _GlobalLightAtten[MAX_LIGHTS];

            struct appdata
            {
                // Object-space vertex position
                float4 vertex : POSITION;
            };

            struct v2f
            {
                // Clip-space position for rasterization
                float4 pos : SV_POSITION;

                // Object-space position used for volume bounds
                float3 localPos : TEXCOORD0;

                // World-space position for lighting and ray setup
                float3 worldPos : TEXCOORD1;
            };

            float4 _FogColor;
            float _Density;
            float _StepSize;
            sampler2D _NoiseTex;
            float4 _NoiseTex_ST;
            float4 _ScrollSpeed;

            v2f vert (appdata v)
            {
                v2f o;

                // Transform vertex to clip space
                o.pos = UnityObjectToClipPos(v.vertex);

                // Store object-space position for ray-box intersection
                o.localPos = v.vertex.xyz;

                // Compute world-space position
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

                return o;
            }

            // Computes the distance from the ray origin to the entry point of the box and the distance the ray travels inside the box
            float2 RayBoxDst(
                float3 boundsMin,
                float3 boundsMax,
                float3 rayOrigin,
                float3 rayDir
            )
            {
                float3 t0 = (boundsMin - rayOrigin) / rayDir;
                float3 t1 = (boundsMax - rayOrigin) / rayDir;

                float3 tmin = min(t0, t1);
                float3 tmax = max(t0, t1);

                float dstA = max(max(tmin.x, tmin.y), tmin.z);
                float dstB = min(min(tmax.x, tmax.y), tmax.z);

                float dstToBox = max(0, dstA);
                float dstInsideBox = max(0, dstB - dstToBox);

                return float2(dstToBox, dstInsideBox);
            }

            float4 frag (v2f i) : SV_Target
            {
                // Convert camera position into object space
                float3 rayOrigin = mul(
                    unity_WorldToObject,
                    float4(_WorldSpaceCameraPos, 1)
                ).xyz;

                // Direction from camera to current fragment inside the volume
                float3 rayDir = normalize(i.localPos - rayOrigin);

                // Compute ray entry and travel distance inside the volume cube
                float2 intersection = RayBoxDst(
                    float3(-0.5, -0.5, -0.5),
                    float3(0.5, 0.5, 0.5),
                    rayOrigin,
                    rayDir
                );

                float dstToBox = intersection.x;
                float dstInside = intersection.y;

                // Calculate the first sampling position inside the volume
                float3 entryPoint = rayOrigin + rayDir * dstToBox;

                float totalDensity = 0.0;
                float3 accumulatedColor = float3(0, 0, 0);
                float distanceTravelled = 0.0;

                // Number of raymarching steps used to integrate fog
                int steps = 32;
                float stepSize = dstInside / steps;

                // Small random offset to reduce banding artifacts
                float dither = frac(
                    sin(dot(i.pos.xy, float2(12.9898, 78.233))) * 43758.5453
                );

                float3 currentPos = entryPoint + rayDir * stepSize * dither;

                // Raymarch through the fog volume
                for (int j = 0; j < steps; j++)
                {
                    if (distanceTravelled >= dstInside)
                        break;

                    // Generate animated noise coordinates
                    float2 noiseUV = currentPos.xz * 2.0 + _Time.y * _ScrollSpeed.xy;

                    // Sample noise to simulate volumetric density variation
                    float noise = tex2D(_NoiseTex, noiseUV).r;

                    // Fetch main directional light (assumed at index 0)
                    float3 lightDir = normalize(-_GlobalLightDir[0].xyz);

                    // Simple wrapped lighting approximation for volumetric scattering
                    float lightIntensity =
                        saturate(dot(float3(0, 1, 0), lightDir) * 0.5 + 0.5);

                    if (noise > 0.1)
                    {
                        // Accumulate density along the ray
                        float density = noise * _Density * stepSize;
                        totalDensity += density;

                        // Accumulate scattered light contribution
                        accumulatedColor +=
                            _FogColor.rgb *
                            _GlobalLightCol[0].rgb *
                            density *
                            lightIntensity;
                    }

                    currentPos += rayDir * stepSize;
                    distanceTravelled += stepSize;
                }

                // Compute remaining light using Beer-Lambert law
                float transmittance = exp(-totalDensity);

                // Output fog color and opacity
                return float4(accumulatedColor, 1.0 - transmittance);
            }

            ENDHLSL
        }
    }
}
