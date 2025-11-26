Shader "Custom/Week5Shader"
{
    Properties
    {
        _mainTexture ("Albedo", 2D) = "white" {}
        _tint ("Tint", Color) = (1,1,1,1)
        _alphaCutoff("Alpha Cutoff", Range(0,1)) = 0.5

        _lightPosition("Light Position", Vector) = (0,0,0)
        _lightDirection("Light Direction", Vector) = (0,-1,0)
        _lightColor("Light Color", Color) = (1,1,1,1)
        _specularStrength("Specular Strength", Range(0,1)) = 0.5
        _smoothness("Smoothness", Range(0,1)) = 0.5
        _lightType("Light Type", Integer) = 1
        _lightIntensity("Light Intensity", Float) = 1
        _attenuation("Attenuation", Vector) = (1.0,0.09,0.032)
        _spotLightCutOff("Spot Light CutOff", Range(0,360)) = 70.0
        _spotLightInnerCutOff("Spot Light Inner CutOff", Range(0,360)) = 25.0
    }

    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType" = "Transparent"}
        Blend SrcAlpha OneMinusSrcAlpha
        Pass
        {
            HLSLPROGRAM
            #include "UnityCG.cginc"

            #pragma vertex MyVertexShader
            #pragma fragment MyFragmentShader

            uniform float4 _tint;
            uniform sampler2D _mainTexture;
            uniform float4 _mainTexture_ST;
            uniform float _alphaCutoff;

            //Light Data
            uniform float3 _lightPosition;
            uniform float3 _lightDirection;
            uniform float4 _lightColor;
            uniform float _specularStrength;
            uniform float _smoothness;
            uniform int _lightType;
            uniform float _lightIntensity;
            uniform float3 _attenuation;
            float attenuation = 1.0;
            uniform float _spotLightCutOff;
            uniform float _spotLightInnerCutOff;

            //Shadow Mapping
            uniform sampler2D _shadowMap;
            uniform float4x4 _lightViewProj;
            uniform float _shadowBias;

            struct vertexData
            {
                float4 position: POSITION;
                float2 uv: TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct vertex2Fragment
            {
                float4 position: SV_POSITION;
                float2 uv: TEXCOORD0;
                float3 normal : NORMAL;
                float3 worldPosition : POSITION1;
                float4 shadowCoord: POSITION2;
            };

            vertex2Fragment MyVertexShader(vertexData vd)
            {
                vertex2Fragment v2f;
                v2f.position = UnityObjectToClipPos(vd.position);
                v2f.worldPosition = mul(unity_ObjectToWorld, vd.position);
                //Can do this v2f.uv = vd.uv * _mainTexture_ST.xy + _mainTexture_ST.zw;
                v2f.uv = TRANSFORM_TEX(vd.uv, _mainTexture);
                v2f.normal = UnityObjectToWorldNormal(vd.normal);
                v2f.normal = normalize(v2f.normal);
                
                v2f.shadowCoord = mul(_lightViewProj, float4(v2f.worldPosition,1.0));
                
                return v2f;
            }
            float ShadowCalculation(float4 fragPosLightSpace)
            {
                //Transform shadow coordinates
                float3 shadowCoord = fragPosLightSpace.xyz / fragPosLightSpace.w;
                //Transform from clip space to texture space
                shadowCoord = shadowCoord * 0.5 + 0.5;

                //Sample shadow Map
                float shadowDepth = 1.0 - tex2D(_shadowMap, shadowCoord.xy).r;
                float shadowFactor = (shadowCoord.z - _shadowBias > shadowDepth) ? 1.0 : 0.0;
                //Flip the shadow factor for proper shadowing
                shadowFactor = saturate(1.0 - shadowFactor);

                return shadowFactor;
            }

            float4 MyFragmentShader(vertex2Fragment v2f) : SV_TARGET
            {
                v2f.normal = normalize(v2f.normal);
                float4 albedo = tex2D(_mainTexture, v2f.uv) * _tint;
                //Apply alpha Cutoff
                if(albedo.a < _alphaCutoff)
                {
                    discard;
                }
                float shadowFactor = ShadowCalculation(v2f.shadowCoord);

                float3 finalLightDirection;
                if(_lightType == 0)
                {
                    finalLightDirection = _lightDirection;
                }
                else
                {
                    
                    finalLightDirection = normalize(v2f.worldPosition - _lightPosition);
                    float distance = length(v2f.worldPosition - _lightPosition);
                    attenuation = 1.0 / (_attenuation.x + _attenuation.y * distance + _attenuation.z * distance * distance);
                    if(_lightType == 2)
                    {
                        float theta = dot(finalLightDirection,_lightDirection);
                        float angle = cos(radians(_spotLightCutOff));
                        if(theta > angle)
                        {
                            float epsilon = cos(radians(_spotLightInnerCutOff)) - angle;
                            float intensity = clamp((theta - angle) / epsilon, 0.0, 1.0);
                            attenuation *= intensity;
                        }
                        else
                        {
                            attenuation = 0.0;
                        }
                    }
                }
                
                
                float3 viewDirection = normalize(_WorldSpaceCameraPos - v2f.worldPosition);
                float3 halfVector = normalize(viewDirection + -finalLightDirection);
                float specular = pow(float(saturate(dot(v2f.normal,halfVector))),_smoothness*100);
                float3 specularColor = specular * _specularStrength * _lightColor.rgb;
                float3 diffuse = albedo.rgb * _lightColor.rgb * saturate(dot(v2f.normal,-finalLightDirection));
                float3 finalColor = (diffuse + specularColor) * _lightIntensity * attenuation * shadowFactor;

                //Return the final color with alpha from the albedo texture.
                return float4(finalColor,albedo.a);
                //return float4(shadowFactor,shadowFactor,shadowFactor,1.0);
                //return float4(v2f.shadowCoord.x,v2f.shadowCoord.y,v2f.shadowCoord.z,1.0);
            }

            

            ENDHLSL
        }
    }
}
