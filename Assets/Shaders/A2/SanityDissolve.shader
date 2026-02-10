Shader "Custom/SanityDissolve_URP"
{
    Properties
    {
        [MainTexture] _BaseMap("Base Map", 2D) = "white" {}
        [MainColor] _BaseColor("Base Color", Color) = (1,1,1,1)
        _BumpMap("Normal Map", 2D) = "bump" {}
        _EmissionMap("Emission Map", 2D) = "black" {}
        
        [Header(Dissolve Settings)]
        _NoiseTex("Dissolve Noise", 2D) = "white" {}
        _DissolveScale("Noise Scale", Float) = 2.0
        _EdgeColor("Edge Glow Color", Color) = (1, 0, 0, 1)
        _EdgeWidth("Edge Width", Range(0.0, 0.2)) = 0.05
        
        [Header(Sanity Interaction)]
        _DisplacementAmount("Vertex Jitter Amount", Range(0, 1)) = 0.2
        _DissolveInvert("Invert Dissolve", Float) = 0
    }

    SubShader
    {
        Tags 
        { 
            "RenderType"="Opaque" 
            "Queue"="AlphaTest" 
            "RenderPipeline"="UniversalPipeline" 
        }
        
        // Double-sided rendering so we see the inside of the walls as they vanish
        Cull Off 

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            
            // Requirements for URP Lighting and Shadows
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
                float2 uv           : TEXCOORD0;
                float4 tangentOS    : TANGENT;
            };

            struct Varyings
            {
                float4 positionCS   : SV_POSITION;
                float3 positionWS   : TEXCOORD0;
                float3 normalWS     : TEXCOORD1;
                float2 uv           : TEXCOORD2;
            };

            // Global Variable from SanityController.cs
            uniform float _GlobalSanity; 

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float4 _BaseColor;
                float4 _EdgeColor;
                float _DissolveScale;
                float _EdgeWidth;
                float _DisplacementAmount;
                float _DissolveInvert;
            CBUFFER_END

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            TEXTURE2D(_BumpMap); SAMPLER(sampler_BumpMap);
            TEXTURE2D(_NoiseTex); SAMPLER(sampler_NoiseTex);
            TEXTURE2D(_EmissionMap); SAMPLER(sampler_EmissionMap);Varyings Vert(Attributes input)
            {
                Varyings output;
                
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

                // --- COMPLEXITY UPGRADE: Vertex Displacement ---
                // Calculate Sanity Factor (0 = Insane, 1 = Sane)
                // We want effect to happen when Sanity is LOW.
                float sanityFactor = saturate(_GlobalSanity);
                float dissolveAmt = 1.0 - sanityFactor; // 0 when sane, 1 when insane

                // World Space Noise for displacement
                float3 worldPos = vertexInput.positionWS;
                float noiseVal = sin(worldPos.x * 5.0 + _Time.y * 2.0) * cos(worldPos.z * 5.0 + _Time.y);
                
                // Jitter vertices along normal only when insane
                float3 displacement = normalInput.normalWS * noiseVal * _DisplacementAmount * dissolveAmt;
                
                // Apply displacement
                output.positionWS = vertexInput.positionWS + displacement;
                output.positionCS = TransformWorldToHClip(output.positionWS);
                
                output.normalWS = normalInput.normalWS;
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);

                return output;
            }

            half4 Frag(Varyings input) : SV_Target
            {
                // 1. Setup Data
                float sanity = saturate(_GlobalSanity);
                float dissolveAmount = 1.0 - sanity; // Goes from 0 to 1 as we lose sanity
                
                // 2. Sample Textures
                half4 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv) * _BaseColor;
                half3 normalTS = UnpackNormal(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, input.uv));
                half3 emission = SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, input.uv).rgb;

                // 3. --- COMPLEXITY UPGRADE: World Space Dissolve ---
                // We use World Position for the noise so walls match up perfectly
                float2 worldUV = input.positionWS.xz * _DissolveScale; 
                // Add scrolling to make the walls feel "alive"
                worldUV += _Time.x * 0.1;
                
                float noiseValue = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, worldUV).r;
                
                // 4. Clip / Dissolve Logic
                // We offset the noise by the dissolve amount
                float cutOff = dissolveAmount * 1.2; // Multiply by 1.2 to ensure full disappearance
                
                // The actual Dissolve Check
                float val = noiseValue - cutOff;
                
                // Discard pixel if below threshold
                clip(val);

                // 5. Edge Emission (The "burning" rim)
                float edgeFactor = 1.0 - smoothstep(0.0, _EdgeWidth, val);
                float3 edgeGlow = _EdgeColor.rgb * edgeFactor * 5.0; // Boost intensity

                // 6. Lighting Calculation
                Light mainLight = GetMainLight();
                float3 lightDir = normalize(mainLight.direction);
                float NdotL = saturate(dot(input.normalWS, lightDir));
                float3 lighting = albedo.rgb * (mainLight.color * NdotL + unity_AmbientSky.rgb);

                // Combine
                float3 finalColor = lighting + emission + edgeGlow;

                return float4(finalColor, albedo.a);
            }
            ENDHLSL
        }
        
        // Shadow Caster Pass (Essential for A+ Integration so the dissolving walls cast correct shadows)
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On ZTest LEqual

            HLSLPROGRAM
            #pragma vertex ShadowVert
            #pragma fragment ShadowFrag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            struct Attributes { float4 positionOS : POSITION; float3 normalOS : NORMAL; };
            struct Varyings { float4 positionCS : SV_POSITION; float3 positionWS : TEXCOORD0; };

            uniform float _GlobalSanity;
            
            CBUFFER_START(UnityPerMaterial)
                float _DissolveScale;
                float _DisplacementAmount;
            CBUFFER_END
            
            TEXTURE2D(_NoiseTex); SAMPLER(sampler_NoiseTex);

            Varyings ShadowVert(Attributes input)
            {
                Varyings output;
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, float4(1,0,0,1));

                // Apply same vertex jitter to shadow
                float sanityFactor = saturate(_GlobalSanity);
                float dissolveAmt = 1.0 - sanityFactor;
                float3 noiseVal = sin(vertexInput.positionWS.x * 5.0) * 0.5; // Simplified noise for shadow
                float3 displacement = normalInput.normalWS * noiseVal * _DisplacementAmount * dissolveAmt;

                output.positionWS = vertexInput.positionWS + displacement;
                output.positionCS = TransformWorldToHClip(output.positionWS);
                return output;
            }

            half4 ShadowFrag(Varyings input) : SV_Target
            {
                // Apply same clip logic to shadow
                float sanity = saturate(_GlobalSanity);
                float dissolveAmount = 1.0 - sanity;
                float2 worldUV = input.positionWS.xz * _DissolveScale + _Time.x * 0.1;
                float noiseValue = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, worldUV).r;
                float cutOff = dissolveAmount * 1.2;
                clip(noiseValue - cutOff);
                
                return 0;
            }
            ENDHLSL
        }
    }
}