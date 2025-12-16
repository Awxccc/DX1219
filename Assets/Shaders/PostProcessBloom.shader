Shader "Hidden/PostProcessBloom"
{
    Properties
    {
        _MainTex ("Base (RGB)", 2D) = "white" {}
        _BloomThreshold ("Bloom Threshold", Range(0, 2)) = 1.0
        _BloomIntensity ("Bloom Intensity", Range(0, 5)) = 1.0
    }
    SubShader
    {
        // No culling or depth write for screen effects
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #include "UnityCG.cginc"
            #pragma vertex vert_img
            #pragma fragment frag

            sampler2D _MainTex;
            float _BloomThreshold;
            float _BloomIntensity;

            // Simple Box Blur Function
            float3 BoxBlur(sampler2D tex, float2 uv, float2 texelSize)
            {
                float3 col = float3(0,0,0);
                col += tex2D(tex, uv + float2(-1, -1) * texelSize).rgb;
                col += tex2D(tex, uv + float2( 0, -1) * texelSize).rgb;
                col += tex2D(tex, uv + float2( 1, -1) * texelSize).rgb;
                col += tex2D(tex, uv + float2(-1,  0) * texelSize).rgb;
                col += tex2D(tex, uv + float2( 0,  0) * texelSize).rgb;
                col += tex2D(tex, uv + float2( 1,  0) * texelSize).rgb;
                col += tex2D(tex, uv + float2(-1,  1) * texelSize).rgb;
                col += tex2D(tex, uv + float2( 0,  1) * texelSize).rgb;
                col += tex2D(tex, uv + float2( 1,  1) * texelSize).rgb;
                return col / 9.0;
            }

            float4 frag (v2f_img i) : SV_Target
            {
                float4 col = tex2D(_MainTex, i.uv);
                
                // 1. Extract Bright Areas (Thresholding)
                // We calculate luminance (brightness)
                float brightness = dot(col.rgb, float3(0.2126, 0.7152, 0.0722));
                float3 brightPart = float3(0,0,0);
                
                if(brightness > _BloomThreshold)
                {
                    brightPart = col.rgb;
                }

                // 2. Mock Blur (In a real engine we'd downsample, but here we do a single pass blur for simplicity)
                // We sample the texture again with offsets to fake a blur
                float2 texel = 1.0 / _ScreenParams.xy * 4.0; // Large spread
                float3 blurredBright = BoxBlur(_MainTex, i.uv, texel) * brightPart;

                // 3. Add Bloom to Original
                col.rgb += blurredBright * _BloomIntensity;

                // 4. Tone Mapping (ACES approximation)
                // Compresses high values (>1) down to 0-1 range nicely
                float3 x = col.rgb;
                float a = 2.51;
                float b = 0.03;
                float c = 2.43;
                float d = 0.59;
                float e = 0.14;
                col.rgb = saturate((x*(a*x+b))/(x*(c*x+d)+e));

                return col;
            }
            ENDCG
        }
    }
}