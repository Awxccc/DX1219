Shader "Custom/AdvancedWater"
{
    Properties
    {
        _WaterColor ("Water Color", Color) = (0, 0.5, 1, 0.8)
        _BumpMap ("Normal Map", 2D) = "bump" {}
        _WaveSpeed ("Wave Speed", Vector) = (0.5, 0.5, 0, 0)
        _WaveHeight ("Wave Height", Range(0, 1)) = 0.2
        _WaveFrequency ("Wave Frequency", Range(0, 10)) = 2.0
        _Specular ("Specular Power", Range(10, 200)) = 100
        
        // --- ADDED REFLECTION PROPERTIES ---
        [Header(Reflection)]
        _CubeMap ("Reflection Cubemap", CUBE) = "" {}
        _Reflectivity ("Reflectivity", Range(0,1)) = 0.5
    }
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" }
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off

        Pass
        {
            HLSLPROGRAM
            #include "UnityCG.cginc"
            #pragma vertex vert
            #pragma fragment frag

            // --------------------------------------------------------
            // UNIFORMS & SHADOW DATA
            // --------------------------------------------------------
            #define MAX_LIGHTS 4
            uniform float4 _GlobalLightPos[MAX_LIGHTS];
            uniform float4 _GlobalLightCol[MAX_LIGHTS];
            uniform float4 _GlobalLightDir[MAX_LIGHTS];
            uniform float4 _GlobalLightAtten[MAX_LIGHTS];
            uniform float4 _GlobalSpotParams[MAX_LIGHTS];
            uniform int _ActiveLightCount;

            // --- 2D SHADOW MAPS (Directional / Spot) ---
            uniform sampler2D _GlobalShadowMap0;
            uniform sampler2D _GlobalShadowMap1;
            uniform sampler2D _GlobalShadowMap2;
            uniform sampler2D _GlobalShadowMap3;

            // --- CUBE SHADOW MAPS (Point Lights) ---
            uniform samplerCUBE _GlobalShadowMapCube0;
            uniform samplerCUBE _GlobalShadowMapCube1;
            uniform samplerCUBE _GlobalShadowMapCube2;
            uniform samplerCUBE _GlobalShadowMapCube3;

            uniform float4x4 _GlobalShadowMatrices[MAX_LIGHTS];
            uniform float _GlobalShadowEnabled[MAX_LIGHTS];

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
                float3 worldPos : TEXCOORD1;
                float3 normal : NORMAL;
            };

            float4 _WaterColor;
            sampler2D _BumpMap; float4 _BumpMap_ST;
            float4 _WaveSpeed;
            float _WaveHeight;
            float _WaveFrequency;
            float _Specular;
            samplerCUBE _CubeMap;
            float _Reflectivity;

            v2f vert (appdata v)
            {
                v2f o;
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                
                // VERTEX DISPLACEMENT
                float wave = sin(_Time.y * _WaveSpeed.x + v.vertex.x * _WaveFrequency) 
                           * cos(_Time.y * _WaveSpeed.y + v.vertex.z * _WaveFrequency);
                v.vertex.y += wave * _WaveHeight;

                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _BumpMap);
                o.normal = UnityObjectToWorldNormal(v.normal);
                return o;
            }

            // --- 2D SHADOW CALCULATION (Spot/Directional) ---
            float CalculateShadow(float4 shadowCoord, float3 normal, float3 lightDir, sampler2D shadowMap)
            {
                float3 projCoords = shadowCoord.xyz / shadowCoord.w;
                if (projCoords.x < 0 || projCoords.x > 1 || projCoords.y < 0 || projCoords.y > 1)
                    return 1.0;

                float cosTheta = clamp(dot(normal, lightDir), 0.0, 1.0);
                float bias = max(0.005 * (1.0 - cosTheta), 0.0005);
                float shadow = 0.0;
                float2 texelSize = float2(1.0/2048.0, 1.0/2048.0);

                // PCF Soft Shadows
                for(int x = -1; x <= 1; ++x)
                {
                    for(int y = -1; y <= 1; ++y)
                    {
                        float pcfDepth = tex2D(shadowMap, projCoords.xy + float2(x, y) * texelSize).r;
                        #if defined(UNITY_REVERSED_Z)
                            if(projCoords.z < pcfDepth - bias) shadow += 0.0; else shadow += 1.0;
                        #else
                            if(projCoords.z > pcfDepth + bias) shadow += 0.0; else shadow += 1.0;
                        #endif
                    }    
                }
                return shadow / 9.0;
            }

            // --- 3D SHADOW CALCULATION (Point) ---
            float CalculateCubeShadow(float3 worldPos, float3 lightPos, samplerCUBE shadowMap)
            {
                float3 fragToLight = worldPos - lightPos;
                float currentDist = length(fragToLight);
                float3 dir = normalize(fragToLight);
                
                // Sample the cubemap (Expects 0-1 linear depth in R channel)
                float closestDepth = texCUBE(shadowMap, dir).r;
                
                // Convert normalized depth back to distance if needed, 
                // but assuming your C# writes linear 0-1 depth relative to light range:
                // (Note: You might need to adjust this multiplier '25.0' to match your light's Range)
                float shadowBias = 0.05; 
                
                // Simple Hard Shadow comparison
                // If current fragment is further than the depth map value, it's in shadow
                // Note: This logic assumes the shadow map stores World Distance or Linear Depth
                if (currentDist * 0.02 > closestDepth + 0.001) // *0.02 is arbitrary scaling, tweak based on Light Range
                    return 0.0;
                
                return 1.0; 
            }

            float4 frag (v2f i) : SV_Target
            {
                float2 uv1 = i.uv + _Time.y * _WaveSpeed.xy;
                float2 uv2 = i.uv - _Time.y * _WaveSpeed.yx * 0.5;
                
                float3 n1 = UnpackNormal(tex2D(_BumpMap, uv1));
                float3 n2 = UnpackNormal(tex2D(_BumpMap, uv2));
                float3 combinedNormal = normalize(n1 + n2);
                float3 worldNormal = normalize(float3(combinedNormal.x, 1.0, combinedNormal.y)); 

                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
                float3 totalDiffuse = float3(0,0,0);
                float3 totalSpecular = float3(0,0,0);

                for(int k = 0; k < MAX_LIGHTS; k++)
                {
                    if(k >= _ActiveLightCount) break;
                    if(length(_GlobalLightCol[k].rgb) <= 0.0) continue;

                    float3 lightColor = _GlobalLightCol[k].rgb;
                    int type = (int)_GlobalLightCol[k].a; 

                    float3 L;
                    float attenuation = 1.0;

                    if(type == 0) // Directional
                    {
                        L = normalize(-_GlobalLightDir[k].xyz);
                    }
                    else // Point or Spot
                    {
                        float3 distVec = _GlobalLightPos[k].xyz - i.worldPos;
                        float dist = length(distVec);
                        L = normalize(distVec);
                        
                        float3 att = _GlobalLightAtten[k].xyz;
                        if(length(att) == 0) att = float3(1, 0, 0); 
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

                    // --- REVISED SHADOW LOGIC ---
                    float shadowVal = 1.0;
                    if(_GlobalShadowEnabled[k] > 0.5)
                    {
                        // 1. POINT LIGHTS use Cube Maps
                        if (type == 1) 
                        {
                            if(k == 0)      shadowVal = CalculateCubeShadow(i.worldPos, _GlobalLightPos[k].xyz, _GlobalShadowMapCube0);
                            else if(k == 1) shadowVal = CalculateCubeShadow(i.worldPos, _GlobalLightPos[k].xyz, _GlobalShadowMapCube1);
                            else if(k == 2) shadowVal = CalculateCubeShadow(i.worldPos, _GlobalLightPos[k].xyz, _GlobalShadowMapCube2);
                            else if(k == 3) shadowVal = CalculateCubeShadow(i.worldPos, _GlobalLightPos[k].xyz, _GlobalShadowMapCube3);
                        }
                        // 2. SPOT & DIRECTIONAL use 2D Projection
                        else 
                        {
                            float4 shadowCoord = mul(_GlobalShadowMatrices[k], float4(i.worldPos, 1.0));
                            if(k == 0)      shadowVal = CalculateShadow(shadowCoord, worldNormal, L, _GlobalShadowMap0);
                            else if(k == 1) shadowVal = CalculateShadow(shadowCoord, worldNormal, L, _GlobalShadowMap1);
                            else if(k == 2) shadowVal = CalculateShadow(shadowCoord, worldNormal, L, _GlobalShadowMap2);
                            else if(k == 3) shadowVal = CalculateShadow(shadowCoord, worldNormal, L, _GlobalShadowMap3);
                        }
                    }

                    // Diffuse
                    float diff = max(dot(worldNormal, L), 0.0);
                    totalDiffuse += _WaterColor.rgb * diff * lightColor * attenuation * shadowVal;

                    // Specular
                    float3 H = normalize(L + viewDir);
                    float spec = pow(max(dot(worldNormal, H), 0.0), _Specular);
                    totalSpecular += float3(1,1,1) * spec * lightColor * attenuation * shadowVal;
                }

                // Reflection
                float3 R = reflect(-viewDir, worldNormal);
                float4 reflectionCol = texCUBE(_CubeMap, R);
                
                float3 finalColor = totalDiffuse + totalSpecular;
                finalColor = lerp(finalColor, reflectionCol.rgb, _Reflectivity);

                return float4(finalColor, _WaterColor.a);
            }
            ENDHLSL
        }
    }
}