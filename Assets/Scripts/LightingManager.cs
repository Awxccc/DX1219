using System.Collections.Generic;
using UnityEngine;

[ExecuteAlways]
public class LightingManager : MonoBehaviour
{
    // Maximum lights supported in Shader
    private const int MAX_LIGHTS = 4;

    private List<CustomLight> lights = new List<CustomLight>();

    void Update()
    {
        // Find all active custom lights
        lights.Clear();
        CustomLight[] foundLights = FindObjectsByType<CustomLight>(FindObjectsSortMode.None);
        lights.AddRange(foundLights);

        // Prepare arrays for Shader
        Vector4[] lightPos = new Vector4[MAX_LIGHTS];
        Vector4[] lightDir = new Vector4[MAX_LIGHTS];
        Vector4[] lightCol = new Vector4[MAX_LIGHTS]; // rgb = color * intensity, a = type
        Vector4[] lightAtten = new Vector4[MAX_LIGHTS]; // xyz = atten, w = spotParams (packed)
        Vector4[] spotParams = new Vector4[MAX_LIGHTS]; // x = cos(outer), y = cos(inner)

        // Shadow Data (Support for 1 main shadow caster for this example, or array for multiple)
        Matrix4x4 mainShadowMatrix = Matrix4x4.identity;
        Texture mainShadowMap = Texture2D.whiteTexture;
        int shadowCasterIndex = -1;

        for (int i = 0; i < MAX_LIGHTS; i++)
        {
            if (i < lights.Count)
            {
                CustomLight l = lights[i];
                lightPos[i] = l.transform.position;
                lightDir[i] = l.GetDirection();

                // Pack Type into Alpha of Color
                lightCol[i] = new Vector4(l.color.r * l.intensity, l.color.g * l.intensity, l.color.b * l.intensity, (float)l.type);

                lightAtten[i] = new Vector4(l.attenuation.x, l.attenuation.y, l.attenuation.z, 0);

                // Pre-calculate Cosines for Spotlights to save Shader instructions
                float outerRad = l.spotAngle * Mathf.Deg2Rad;
                float innerRad = l.spotInnerAngle * Mathf.Deg2Rad;
                spotParams[i] = new Vector4(Mathf.Cos(outerRad), Mathf.Cos(innerRad), 0, 0);

                // Check for Shadows
                if (l.castShadows && l.shadowMap != null)
                {
                    shadowCasterIndex = i;
                    mainShadowMap = l.shadowMap;
                    mainShadowMatrix = l.viewProjMatrix;
                }
            }
            else
            {
                // Reset unused slots
                lightCol[i] = Vector4.zero;
            }
        }

        // Send to ALL shaders
        Shader.SetGlobalVectorArray("_GlobalLightPos", lightPos);
        Shader.SetGlobalVectorArray("_GlobalLightDir", lightDir);
        Shader.SetGlobalVectorArray("_GlobalLightCol", lightCol);
        Shader.SetGlobalVectorArray("_GlobalLightAtten", lightAtten);
        Shader.SetGlobalVectorArray("_GlobalSpotParams", spotParams);
        Shader.SetGlobalInt("_ActiveLightCount", lights.Count);

        // Shadow Global Data
        Shader.SetGlobalTexture("_GlobalShadowMap", mainShadowMap);
        Shader.SetGlobalMatrix("_GlobalShadowMatrix", mainShadowMatrix);
        Shader.SetGlobalFloat("_ShadowCasterIndex", (float)shadowCasterIndex);
    }
}