Shader "Custom/ShadowDepth"
{
    SubShader
    {
        // This tag matches standard Opaque objects
        Tags { "RenderType"="Opaque" }
        
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 worldPos : TEXCOORD0;
            };

            // This variable is set by ShadowCaster.cs
            float _ShadowLightFarPlane; 

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                // Calculate distance from the camera (which is at the light position)
                float dist = distance(i.worldPos, _WorldSpaceCameraPos);
                
                // Normalize distance (0..1) based on the Far Plane
                // Write this to the RED channel
                return float4(dist / _ShadowLightFarPlane, 0, 0, 1);
            }
            ENDCG
        }
    }

    SubShader
    {
        // This tag matches your AdvancedUberShader (Transparent)
        Tags { "RenderType"="Transparent" }
        
        Pass
        {
            // Same logic for Transparent objects
            // (Note: This ignores alpha cutouts for simplicity)
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata { float4 vertex : POSITION; };
            struct v2f { float4 pos : SV_POSITION; float3 worldPos : TEXCOORD0; };
            float _ShadowLightFarPlane; 

            v2f vert (appdata v) {
                v2f o; o.pos = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o;
            }

            float4 frag (v2f i) : SV_Target {
                float dist = distance(i.worldPos, _WorldSpaceCameraPos);
                return float4(dist / _ShadowLightFarPlane, 0, 0, 1);
            }
            ENDCG
        }
    }
}