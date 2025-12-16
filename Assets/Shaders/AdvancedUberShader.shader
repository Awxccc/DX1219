Shader "Custom/AdvancedUberShader"
{
    Properties
    {
        [Header(Base Settings)]
        _MainTex ("Albedo (RGBA)", 2D) = "white" {}
        _Tint ("Color Tint", Color) = (1,1,1,1)
        _AlphaCutoff ("Alpha Cutoff", Range(0,1)) = 0.1
        
        [Header(Normal Mapping)]
        _BumpMap ("Normal Map", 2D) = "bump" {}
        _BumpScale ("Normal Strength", Range(0, 2)) = 1.0

        [Header(Surface Properties)]
        _Smoothness ("Smoothness", Range(0.01, 100)) = 32.0
        _SpecularColor ("Specular Color", Color) = (1,1,1,1)

        [Header(Reflection)]
        _CubeMap ("Reflection Cubemap", CUBE) = "" {}
        _Reflectivity ("Reflectivity", Range(0,1)) = 0.5
    }

    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }
        LOD 200
        
        // ========================================================
        // PASS 1: SHADOW CASTER (Renders depth to shadow map)
        // ========================================================
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            
            ZWrite On
            ZTest LEqual
            ColorMask 0  // Don't write color, only depth
            
            HLSLPROGRAM
            #pragma vertex vert_shadow
            #pragma fragment frag_shadow
            #include "UnityCG.cginc"
            
            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _Tint;
            float _AlphaCutoff;
            
            struct appdata_shadow
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };
            
            struct v2f_shadow
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
            };
            
            v2f_shadow vert_shadow(appdata_shadow v)
            {
                v2f_shadow o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }
            
            float4 frag_shadow(v2f_shadow i) : SV_Target
            {
                // Handle alpha cutoff for transparent objects
                float4 albedo = tex2D(_MainTex, i.uv) * _Tint;
                if(albedo.a < _AlphaCutoff) discard;
                
                // Depth is written automatically, we just need to not discard
                return float4(0, 0, 0, 1);
            }
            ENDHLSL
        }
        
        // ========================================================
        // PASS 2: MAIN RENDERING (Your original pass)
        // ========================================================
        Pass
        {
            Name "ForwardBase"
            
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite On

            HLSLPROGRAM
            #include "UnityCG.cginc"
            #pragma vertex vert
            #pragma fragment frag

            // --------------------------------------------------------
            // UNIFORMS (Set by LightingManager.cs)
            // --------------------------------------------------------
            #define MAX_LIGHTS 4
            
            uniform float4 _GlobalLightPos[MAX_LIGHTS];
            uniform float4 _GlobalLightDir[MAX_LIGHTS];
            uniform float4 _GlobalLightCol[MAX_LIGHTS]; // rgb=col, a=type
            uniform float4 _GlobalLightAtten[MAX_LIGHTS];
            uniform float4 _GlobalSpotParams[MAX_LIGHTS];
            uniform int _ActiveLightCount;

            // --- NEW SHADOW UNIFORMS ---
            // Individual Texture Slots
            uniform sampler2D _GlobalShadowMap0;
            uniform sampler2D _GlobalShadowMap1;
            uniform sampler2D _GlobalShadowMap2;
            uniform sampler2D _GlobalShadowMap3;

            // Arrays for Data
            uniform float4x4 _GlobalShadowMatrices[MAX_LIGHTS];
            uniform float _GlobalShadowEnabled[MAX_LIGHTS];
            uniform float _GlobalShadowBias;

            // Material Properties
            sampler2D _MainTex; float4 _MainTex_ST;
            float4 _Tint;
            float _AlphaCutoff;
            sampler2D _BumpMap;
            float _BumpScale;
            float _Smoothness;
            float4 _SpecularColor;
            samplerCUBE _CubeMap;
            float _Reflectivity;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float3 normal : NORMAL;
                float3 tangent : TANGENT;
                float3 binormal : BINORMAL;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                
                // Normal Mapping Calculation (TBN Matrix components)
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.tangent = normalize(mul(unity_ObjectToWorld, float4(v.tangent.xyz, 0.0)).xyz);
                o.binormal = cross(o.normal, o.tangent) * v.tangent.w;

                return o;
            }

            // Now accepts 'shadowMap' as an argument!
            float CalculateShadow(float4 shadowCoord, float3 normal, float3 lightDir, sampler2D shadowMap)
            {
                float3 projCoords = shadowCoord.xyz / shadowCoord.w;

                if (projCoords.x < 0 || projCoords.x > 1 || projCoords.y < 0 || projCoords.y > 1)
                    return 1.0;

                float cosTheta = clamp(dot(normal, lightDir), 0.0, 1.0);
                float bias = max(0.005 * (1.0 - cosTheta), 0.0005);

                float shadow = 0.0;
                float2 texelSize = float2(1.0/2048.0, 1.0/2048.0);

                for(int x = -1; x <= 1; ++x)
                {
                    for(int y = -1; y <= 1; ++y)
                    {
                        // Sample the passed-in 'shadowMap'
                        float pcfDepth = tex2D(shadowMap, projCoords.xy + float2(x, y) * texelSize).r;
                        
                        #if defined(UNITY_REVERSED_Z)
                            if(projCoords.z < pcfDepth - bias) shadow += 0.0;
                            else shadow += 1.0;
                        #else
                            if(projCoords.z > pcfDepth + bias) shadow += 0.0;
                            else shadow += 1.0;
                        #endif
                    }    
                }
                return shadow / 9.0;
            }

            float4 frag (v2f i) : SV_Target
            {
                // 1. Textures & Alpha
                float4 albedo = tex2D(_MainTex, i.uv) * _Tint;
                if(albedo.a < _AlphaCutoff) discard;

                // 2. Normal Mapping (Decode from Texture)
                float3 normalMap = UnpackNormal(tex2D(_BumpMap, i.uv));
                normalMap.xy *= _BumpScale;
                normalMap.z = sqrt(1.0 - saturate(dot(normalMap.xy, normalMap.xy)));
                
                // Construct TBN Matrix
                float3x3 TBN = float3x3(normalize(i.tangent), normalize(i.binormal), normalize(i.normal));
                float3 N = normalize(mul(normalMap, TBN)); // Final World Normal
                
                float3 V = normalize(_WorldSpaceCameraPos - i.worldPos);

                // 3. Lighting Loop
                float3 finalDiffuse = float3(0,0,0);
                float3 finalSpecular = float3(0,0,0);

                for(int k = 0; k < MAX_LIGHTS; k++)
                {
                    // Check if light is active (Active if Color is not black)
                    // Note: We use a loop limit uniform or just check intensity
                    if(k >= _ActiveLightCount) break;

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

                    float shadowVal = 1.0;
                    
                    // Check if this specific light (k) has shadows enabled
                    if(_GlobalShadowEnabled[k] > 0.5)
                    {
                        // Calculate coordinate using THIS light's specific matrix
                        float4 shadowCoord = mul(_GlobalShadowMatrices[k], float4(i.worldPos, 1.0));
                        
                        // Manually pick the texture based on index 'k'
                        if(k == 0)      shadowVal = CalculateShadow(shadowCoord, N, L, _GlobalShadowMap0);
                        else if(k == 1) shadowVal = CalculateShadow(shadowCoord, N, L, _GlobalShadowMap1);
                        else if(k == 2) shadowVal = CalculateShadow(shadowCoord, N, L, _GlobalShadowMap2);
                        else if(k == 3) shadowVal = CalculateShadow(shadowCoord, N, L, _GlobalShadowMap3);
                    }
                    // ------------------------

                    // Diffuse
                    float NdotL = max(dot(N, L), 0.0);
                    finalDiffuse += albedo.rgb * lightColor * NdotL * attenuation * shadowVal;

                    // Specular (Blinn-Phong)
                    float3 H = normalize(L + V);
                    float NdotH = max(dot(N, H), 0.0);
                    float spec = pow(NdotH, _Smoothness);
                    finalSpecular += _SpecularColor.rgb * lightColor * spec * attenuation * shadowVal;
                }

                // 4. Reflection (Environment Mapping)
                float3 R = reflect(-V, N);
                float4 reflectionCol = texCUBE(_CubeMap, R);
                
                float3 finalColor = finalDiffuse + finalSpecular;
                // Mix reflection based on reflectivity
                finalColor = lerp(finalColor, reflectionCol.rgb, _Reflectivity);

                return float4(finalColor, albedo.a);
            }
            ENDHLSL
        }
    }
}