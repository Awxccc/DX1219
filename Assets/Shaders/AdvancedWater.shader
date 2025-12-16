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
                // SCROLLING NORMAL MAPS (Keep this part)
                float2 uv1 = i.uv + _Time.y * _WaveSpeed.xy;
                float2 uv2 = i.uv - _Time.y * _WaveSpeed.yx * 0.5;
                
                float3 n1 = UnpackNormal(tex2D(_BumpMap, uv1));
                float3 n2 = UnpackNormal(tex2D(_BumpMap, uv2));
                float3 combinedNormal = normalize(n1 + n2);
                float3 worldNormal = normalize(float3(combinedNormal.x, 1.0, combinedNormal.y));

                // --- NEW LIGHTING LOOP ---
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
                float3 totalDiffuse = float3(0,0,0);
                float3 totalSpecular = float3(0,0,0);

                // Use the active light count uniform
                // (Make sure to add 'uniform int _ActiveLightCount;' at the top if missing!)
                
                for(int k = 0; k < MAX_LIGHTS; k++)
                {
                    // Check if light is active (simple check based on your logic)
                    if(length(_GlobalLightCol[k].rgb) <= 0.0) continue; 

                    float3 lightColor = _GlobalLightCol[k].rgb;
                    int type = (int)_GlobalLightCol[k].a; // 0=Dir, 1=Point, 2=Spot

                    // Calculate Light Direction & Attenuation
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
                        // Simple attenuation matching your other shaders
                        // (Or just use 1.0/dist*dist for water simplicity)
                        attenuation = 1.0 / (1.0 + 0.1 * dist + 0.05 * dist * dist); 
                    }

                    // Diffuse
                    float diff = max(dot(worldNormal, L), 0.0);
                    totalDiffuse += _WaterColor.rgb * diff * lightColor * attenuation;

                    // Specular
                    float3 H = normalize(L + viewDir);
                    float spec = pow(max(dot(worldNormal, H), 0.0), _Specular);
                    totalSpecular += float3(1,1,1) * spec * lightColor * attenuation;
                }

                float3 finalColor = totalDiffuse + totalSpecular;
                return float4(finalColor, _WaterColor.a);
            }
            ENDHLSL
        }
    }
}