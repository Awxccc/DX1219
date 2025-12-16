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
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        Cull Front // Render the INSIDE of the cube so we can be inside the fog

        Pass
        {
            HLSLPROGRAM
            #include "UnityCG.cginc"
            #pragma vertex vert
            #pragma fragment frag

            // Global Lighting Data (From LightingManager.cs)
            #define MAX_LIGHTS 4
            uniform float4 _GlobalLightPos[MAX_LIGHTS];
            uniform float4 _GlobalLightCol[MAX_LIGHTS];
            uniform float4 _GlobalLightDir[MAX_LIGHTS];
            uniform float4 _GlobalLightAtten[MAX_LIGHTS];

            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 localPos : TEXCOORD0; // Object space for volume bounds
                float3 worldPos : TEXCOORD1;
            };

            float4 _FogColor;
            float _Density;
            float _StepSize;
            sampler2D _NoiseTex; float4 _NoiseTex_ST;
            float4 _ScrollSpeed;

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.localPos = v.vertex.xyz; // Assuming default Cube is -0.5 to 0.5
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o;
            }

            // Ray-Box Intersection (Box is axis aligned -0.5 to 0.5 in object space)
            float2 RayBoxDst(float3 boundsMin, float3 boundsMax, float3 rayOrigin, float3 rayDir) 
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
                float3 rayOrigin = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1)).xyz;
                float3 targetPos = i.localPos; // The pixel we are rendering
                float3 rayDir = normalize(targetPos - rayOrigin);

                // 1. Calculate how far the ray travels inside the box
                // Default Unity Cube is -0.5 to 0.5
                float2 intersection = RayBoxDst(float3(-0.5,-0.5,-0.5), float3(0.5,0.5,0.5), rayOrigin, rayDir);
                float dstInside = intersection.y;
                float dstToBox = intersection.x;

                // Start marching from the entry point
                float3 entryPoint = rayOrigin + rayDir * dstToBox;
                
                float totalDensity = 0;
                float3 accumulatedColor = float3(0,0,0);
                
                float distanceTravelled = 0;
                
                // 2. RAYMARCH LOOP
                // We limit steps for performance (e.g., 32 steps)
                int steps = 32;
                float stepSize = dstInside / (float)steps;
                
                // Randomize start slightly to reduce banding (dithering)
                float dither = frac(sin(dot(i.pos.xy, float2(12.9898,78.233))) * 43758.5453);
                float3 currentPos = entryPoint + rayDir * stepSize * dither;

                for(int j=0; j<steps; j++)
                {
                    if(distanceTravelled >= dstInside) break;

                    // Sample Noise for "Clouds"
                    // We project 3D position to 2D UVs for simplicity in this example
                    float2 noiseUV = currentPos.xz * 2.0 + _Time.y * _ScrollSpeed.xy;
                    float noise = tex2D(_NoiseTex, noiseUV).r;
                    
                    // Lighting Calculation (Simple directional light influence)
                    // (Assuming Index 0 is the Sun)
                    float3 lightDir = normalize(-_GlobalLightDir[0].xyz);
                    float lightIntensity = saturate(dot(float3(0,1,0), lightDir) * 0.5 + 0.5); // Mock light wrap

                    if(noise > 0.1)
                    {
                        float density = noise * _Density * stepSize;
                        totalDensity += density;
                        accumulatedColor += _FogColor.rgb * _GlobalLightCol[0].rgb * density * lightIntensity;
                    }

                    currentPos += rayDir * stepSize;
                    distanceTravelled += stepSize;
                }

                // Beer's Law for Transmittance
                float transmittance = exp(-totalDensity);
                
                return float4(accumulatedColor, 1.0 - transmittance);
            }
            ENDHLSL
        }
    }
}