Shader "Hidden/Custom/Psychosis"
{
    Properties
    {
        _MainTex ("Source", 2D) = "white" {}
        _Intensity ("Sanity Loss Intensity", Range(0, 1)) = 0
        _WarpScale ("Fisheye Warp", Range(0, 1)) = 0.5
        _Aberration ("Chromatic Aberration", Range(0, 0.05)) = 0.02
        _GrainPower ("Film Grain", Range(0, 1)) = 0.5
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline"}
        LOD 100
        ZWrite Off Cull Off

        Pass
        {
            Name "PsychosisPass"

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            
            // Parameters driven by C#
            float _Intensity;       // 0 = Normal, 1 = Full Psychosis
            float _WarpScale;       
            float _Aberration;
            float _GrainPower;

            Varyings Vert(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = input.uv;
                return output;
            }

            // --- COMPLEXITY FUNCTION: FISHEYE DISTORTION ---
            float2 DistortUV(float2 uv, float intensity)
            {
                float2 center = float2(0.5, 0.5);
                float2 delta = uv - center;
                float dist = length(delta);
                // Non-linear warp based on distance from center
                float warp = 1.0 - (pow(dist, 2.0) * intensity * _WarpScale);
                return center + delta * warp;
            }

            // --- COMPLEXITY FUNCTION: NOISE GENERATOR ---
            float RandomNoise(float2 uv)
            {
                return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);
            }

            half4 Frag(Varyings input) : SV_Target
            {
                // 1. Calculate Pulse Speed based on Time
                float pulse = sin(_Time.y * 3.0) * 0.5 + 0.5; // Oscillates 0 to 1
                
                // 2. Apply Fisheye Warp driven by Sanity (_Intensity)
                float2 distortedUV = DistortUV(input.uv, _Intensity);

                // 3. Chromatic Aberration (RGB Split)
                // The split widens as Intensity increases
                float splitAmount = _Aberration * _Intensity * (1.0 + pulse * 0.2);
                
                float4 colorR = tex2D(_MainTex, distortedUV - float2(splitAmount, 0));
                float4 colorG = tex2D(_MainTex, distortedUV);
                float4 colorB = tex2D(_MainTex, distortedUV + float2(splitAmount, 0));

                half4 finalColor = half4(colorR.r, colorG.g, colorB.b, 1.0);

                // 4. Add Film Grain
                // Grain becomes more visible as sanity drops
                float noise = RandomNoise(input.uv + _Time.x);
                float grainStrength = _GrainPower * _Intensity;
                finalColor.rgb += (noise - 0.5) * grainStrength;

                // 5. Desaturation / Darkening (Optional Horror Vibe)
                // Linearly interpolate between Color and a Dark Grey based on intensity
                float luminance = dot(finalColor.rgb, float3(0.2126, 0.7152, 0.0722));
                half3 darkGrey = half3(luminance, luminance, luminance) * 0.5;
                finalColor.rgb = lerp(finalColor.rgb, darkGrey, _Intensity * 0.5);

                return finalColor;
            }
            ENDHLSL
        }
    }
}