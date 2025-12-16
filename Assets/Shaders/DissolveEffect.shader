Shader "Custom/DissolveEffect"
{
    Properties
    {
        _MainTex ("Albedo", 2D) = "white" {}
        _NoiseTex ("Dissolve Noise", 2D) = "white" {}
        _DissolveAmount ("Dissolve Amount", Range(0, 1)) = 0
        _EdgeWidth ("Burn Edge Width", Range(0, 0.2)) = 0.05
        _EdgeColor ("Burn Color", Color) = (1, 0.2, 0, 1)
        _EdgeIntensity ("Edge Intensity", Float) = 20.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        Cull Off // Double sided so we see inside when dissolving

        Pass
        {
            HLSLPROGRAM
            #include "UnityCG.cginc"
            #pragma vertex vert
            #pragma fragment frag

            // Global Light Support
            #define MAX_LIGHTS 4
            uniform float4 _GlobalLightDir[MAX_LIGHTS];
            uniform float4 _GlobalLightCol[MAX_LIGHTS];

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
                float3 worldNormal : NORMAL;
            };

            sampler2D _MainTex;
            sampler2D _NoiseTex;
            float _DissolveAmount;
            float _EdgeWidth;
            float4 _EdgeColor;
            float _EdgeIntensity;

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                // 1. Read Dissolve Noise
                float noiseVal = tex2D(_NoiseTex, i.uv).r;

                // 2. Perform Clip
                // If noise value is less than dissolve amount, discard pixel
                float val = noiseVal - _DissolveAmount;
                if(val < 0) discard;

                // 3. Base Color & Lighting
                float4 col = tex2D(_MainTex, i.uv);
                
                // Simple Diffuse from Sun (Light 0)
                float3 L = normalize(-_GlobalLightDir[0].xyz);
                float diff = max(dot(i.worldNormal, L), 0.0);
                float3 lighting = col.rgb * diff * _GlobalLightCol[0].rgb;

                // 4. Burn Edge Calculation
                // If 'val' is very close to 0 (just barely survived the clip), it's an edge
                float edgeFactor = step(val, _EdgeWidth); 
                float3 emission = edgeFactor * _EdgeColor.rgb * _EdgeIntensity;

                return float4(lighting + emission, 1.0);
            }
            ENDHLSL
        }
    }
}