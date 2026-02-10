Shader "Hidden/Custom/PanicAttack"
{
    Properties
    {
        _MainTex ("Source", 2D) = "white" {}
        _VignettePower ("Vignette Power", Range(0.1, 10)) = 5.0
        _RedOut ("Red Overlay", Range(0, 1)) = 0.0
        _BlurStrength ("Blur Strength", Range(0, 5)) = 0.0
        _PulseSpeed ("Pulse Speed", Float) = 2.0
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }
        LOD 100
        ZTest Always ZWrite Off Cull Off

        Pass
        {
            Name "PanicAttackPass"

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

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            float _VignettePower;
            float _RedOut;
            float _BlurStrength;
            float _PulseSpeed;

            Varyings Vert(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = input.uv;
                return output;
            }

            float4 Frag(Varyings input) : SV_Target
            {
                float2 uv = input.uv;
                
                // 1. Heartbeat Pulse Calculation
                float pulse = sin(_Time.y * _PulseSpeed) * 0.5 + 0.5;
                float currentVignette = lerp(_VignettePower, _VignettePower * 0.8, pulse);

                // 2. Radial Blur (Dizziness)
                float2 center = float2(0.5, 0.5);
                float2 dir = center - uv; 
                float dist = length(dir);
                dir /= dist;
                
                float4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
                float4 sum = color;

                // Simple 5-tap radial blur
                for(int i = 0; i < 5; i++)
                {
                    float scale = 1.0 - (_BlurStrength * 0.01 * i * pulse * dist);
                    sum += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv * scale + center * (1.0 - scale));
                }
                color = sum / 6.0;

                // 3. Vignette (Dark edges)
                dist = distance(uv, center);
                float vignette = smoothstep(0.8, 0.2, dist * (currentVignette * 0.5 + 0.5));
                color.rgb *= vignette;

                // 4. Red Overlay (Blood rush)
                float3 redColor = float3(1.0, 0.0, 0.0);
                color.rgb = lerp(color.rgb, color.rgb * redColor, _RedOut * pulse);

                return color;
            }
            ENDHLSL
        }
    }
}