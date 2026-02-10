Shader "Custom/VolumetricFog_URP"
{
    Properties
    {
        _FogColor ("Fog Color", Color) = (1,1,1,1)
        _InsanityColor ("Insanity Fog Color", Color) = (0.8, 0, 0, 1) 
        _Density ("Density", Range(0, 5)) = 0.5
        _StepSize ("Step Size", Range(0.01, 0.5)) = 0.1
        _NoiseTex ("Noise Texture (3D Look)", 2D) = "white" {}
        _ScrollSpeed ("Flow Speed", Vector) = (0.1, 0.05, 0, 0)
    }

    SubShader
    {
        Tags { "Queue"="Transparent+100" "RenderType"="Transparent" "RenderPipeline"="UniversalPipeline" }
        
        // Standard Alpha Blending
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        
        // Cull Front means we render the BACK faces of the cube.
        // This allows us to walk INSIDE the cube and still see the fog.
        Cull Front 

        Pass
        {
            Name "VolumetricFog"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            #pragma vertex vert
            #pragma fragment frag

            // This variable is set by SanityController.cs
            uniform float _GlobalSanity; 

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 localPos : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _FogColor;
                float4 _InsanityColor;
                float _Density;
                float _StepSize;
                float4 _ScrollSpeed;
                float4 _NoiseTex_ST;
            CBUFFER_END

            sampler2D _NoiseTex;

            v2f vert (appdata v)
            {
                v2f o;
                VertexPositionInputs vertexInput = GetVertexPositionInputs(v.vertex.xyz);
                o.pos = vertexInput.positionCS;
                o.worldPos = vertexInput.positionWS;
                o.localPos = v.vertex.xyz;
                return o;
            }

            // Ray-Box Intersection
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
                // 1. Setup Ray
                float3 rayOrigin = GetCameraPositionWS();
                
                // We need the local position of the camera to calculate entry/exit in Object Space
                // Transform World Camera Pos -> Object Space
                float3 rayOriginLocal = TransformWorldToObject(rayOrigin);
                float3 rayDirLocal = normalize(i.localPos - rayOriginLocal);

                // 2. Calculate Box Intersection (Unit Cube -0.5 to 0.5)
                float2 intersection = RayBoxDst(float3(-0.5, -0.5, -0.5), float3(0.5, 0.5, 0.5), rayOriginLocal, rayDirLocal);
                float dstToBox = intersection.x;
                float dstInside = intersection.y;

                // If we aren't hitting the box logic correctly, or distance is 0, discard
                if (dstInside <= 0) discard;

                // 3. Raymarching Setup
                float3 entryPoint = rayOriginLocal + rayDirLocal * dstToBox;
                float totalDensity = 0.0;
                float3 accumulatedColor = float3(0, 0, 0);
                float distanceTravelled = 0.0;
                
                int steps = 25; // Keep low for performance
                float stepSize = dstInside / steps;

                // Dither to hide banding (random offset)
                float dither = frac(sin(dot(i.pos.xy, float2(12.9898, 78.233))) * 43758.5453);
                float3 currentPos = entryPoint + rayDirLocal * stepSize * dither;

                // 4. Sanity Logic
                float insanity = clamp(_GlobalSanity, 0, 1);
                float speedMult = 1.0 + (insanity * 3.0);
                float3 currentFogColor = lerp(_FogColor.rgb, _InsanityColor.rgb, insanity);

                // 5. Lighting (URP)
                Light mainLight = GetMainLight();
                float3 lightDir = normalize(TransformWorldToObjectDir(mainLight.direction)); 
                float lightIntensity = saturate(dot(float3(0, 1, 0), lightDir) * 0.5 + 0.5);
                float3 lightColor = mainLight.color;

                // 6. Loop
                for (int j = 0; j < steps; j++)
                {
                    if (distanceTravelled >= dstInside) break;

                    // Scroll noise
                    float2 noiseUV = currentPos.xz * 2.0 + _Time.y * _ScrollSpeed.xy * speedMult;
                    float noise = tex2D(_NoiseTex, noiseUV).r; // Standard tex2D for sampler2D
                    
                    if (noise > 0.1)
                    {
                        float density = noise * _Density * stepSize;
                        totalDensity += density;
                        
                        // Add Color + Light
                        accumulatedColor += currentFogColor * lightColor * density * lightIntensity;
                    }

                    currentPos += rayDirLocal * stepSize;
                    distanceTravelled += stepSize;
                }

                float transmittance = exp(-totalDensity);
                
                // Return final color
                return float4(accumulatedColor, 1.0 - transmittance);
            }
            ENDHLSL
        }
    }
}