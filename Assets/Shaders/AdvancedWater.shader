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

            // Global Light data (We only use the first light for simplicity in water)
            #define MAX_LIGHTS 4
            uniform float4 _GlobalLightPos[MAX_LIGHTS];
            uniform float4 _GlobalLightCol[MAX_LIGHTS];
            uniform float4 _GlobalLightDir[MAX_LIGHTS];

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

            v2f vert (appdata v)
            {
                v2f o;
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                
                // VERTEX DISPLACEMENT (Simple Sin Wave)
                float wave = sin(_Time.y * _WaveSpeed.x + v.vertex.x * _WaveFrequency) 
                           * cos(_Time.y * _WaveSpeed.y + v.vertex.z * _WaveFrequency);
                
                v.vertex.y += wave * _WaveHeight;

                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _BumpMap);
                o.normal = UnityObjectToWorldNormal(v.normal);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                // SCROLLING NORMAL MAPS
                float2 uv1 = i.uv + _Time.y * _WaveSpeed.xy;
                float2 uv2 = i.uv - _Time.y * _WaveSpeed.yx * 0.5;
                
                float3 n1 = UnpackNormal(tex2D(_BumpMap, uv1));
                float3 n2 = UnpackNormal(tex2D(_BumpMap, uv2));
                float3 combinedNormal = normalize(n1 + n2);

                // Reorient normal to world space (Approximate for flat water)
                float3 worldNormal = normalize(float3(combinedNormal.x, 1.0, combinedNormal.y));

                // LIGHTING (Sun only - Index 0)
                float3 lightDir = normalize(-_GlobalLightDir[0].xyz);
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
                float3 H = normalize(lightDir + viewDir);

                // Diffuse
                float diff = max(dot(worldNormal, lightDir), 0.0);
                
                // Specular
                float spec = pow(max(dot(worldNormal, H), 0.0), _Specular);
                
                float3 finalColor = _WaterColor.rgb * diff + float3(1,1,1) * spec;

                return float4(finalColor, _WaterColor.a);
            }
            ENDHLSL
        }
    }
}