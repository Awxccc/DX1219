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
            uniform float4 _GlobalLightCol[MAX_LIGHTS];
            uniform float4 _GlobalLightDir[MAX_LIGHTS];
            uniform float4 _GlobalLightPos[MAX_LIGHTS];
            uniform float4 _GlobalLightAtten[MAX_LIGHTS];
            uniform float4 _GlobalSpotParams[MAX_LIGHTS];
            uniform int _ActiveLightCount;

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
                float3 worldPos_fix : TEXCOORD1; // ADD THIS
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
                o.worldPos_fix = mul(unity_ObjectToWorld, v.vertex).xyz; // ADD THIS
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                // 1. Read Dissolve Noise
                float noiseVal = tex2D(_NoiseTex, i.uv).r;
                float val = noiseVal - _DissolveAmount;
                if(val < 0) discard;

                // 3. Base Color & Lighting
                float4 col = tex2D(_MainTex, i.uv);
                
                // 3. Lighting Loop
                float3 totalLight = float3(0,0,0);
                
                for(int k = 0; k < MAX_LIGHTS; k++)
                {
                    if(k >= _ActiveLightCount) break;
                    if(length(_GlobalLightCol[k].rgb) <= 0.0) continue;

                    float3 lightColor = _GlobalLightCol[k].rgb;
                    int type = (int)_GlobalLightCol[k].a; // 0=Dir, 1=Point, 2=Spot

                    float3 L;
                    float attenuation = 1.0;

                    if(type == 0) // Directional
                    {
                        L = normalize(-_GlobalLightDir[k].xyz);
                    }
                    else // Point or Spot
                    {
                        float3 distVec = _GlobalLightPos[k].xyz - i.pos.xyz; // Note: Dissolve shader didn't pass worldPos clearly, usually needs v.vertex -> world
                        // Correction: Dissolve shader 'v2f' struct lacks explicit worldPos in frag, 
                        // but 'i.pos' is Clip Space. We need World Pos for Point lights.
                        // *Important*: You might need to add 'float3 worldPos : TEXCOORD1;' to v2f struct if not present!
                        // Assuming you add it (see below), or use i.worldNormal temporarily which is wrong for position.
                        
                        // LET'S FIX THE STRUCT FIRST (See instruction below code block)
                        // For now, assuming you added worldPos:
                        distVec = _GlobalLightPos[k].xyz - i.worldPos_fix; 
                        
                        float dist = length(distVec);
                        L = normalize(distVec);
                        float3 att = _GlobalLightAtten[k].xyz;
                        attenuation = 1.0 / (att.x + att.y * dist + att.z * dist * dist);

                        if(type == 2) // Spot Cone Logic
                        {
                            float theta = dot(L, normalize(-_GlobalLightDir[k].xyz));
                            float outer = _GlobalSpotParams[k].x;
                            float inner = _GlobalSpotParams[k].y;
                            float epsilon = inner - outer;
                            float intensity = clamp((theta - outer) / epsilon, 0.0, 1.0);
                            attenuation *= intensity;
                        }
                    }

                    float diff = max(dot(i.worldNormal, L), 0.0);
                    totalLight += col.rgb * diff * lightColor * attenuation;
                }

                // 4. Burn Edge
                float edgeFactor = step(val, _EdgeWidth);
                float3 emission = edgeFactor * _EdgeColor.rgb * _EdgeIntensity;

                return float4(totalLight + emission, 1.0);
            }
            ENDHLSL
        }
    }
}