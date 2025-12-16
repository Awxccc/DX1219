using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class LightingManager : MonoBehaviour
{
    // Maximum number of custom lights the shader can process at once
    private const int MAX_LIGHTS = 4;

    // List used to store all active CustomLight components in the scene
    private List<CustomLight> lights = new();

    void Update()
    {
        // Clear the list every frame so it can be rebuilt with current active lights
        lights.Clear();

        // Find all CustomLight components in the scene (both runtime and edit mode)
        CustomLight[] foundLights = FindObjectsByType<CustomLight>(FindObjectsSortMode.None);

        // Only add lights that are enabled and active in the hierarchy
        foreach (var l in foundLights)
        {
            if (l.isActiveAndEnabled)
                lights.Add(l);
        }

        // Arrays used to send lighting data to the shader
        Vector4[] lightPos = new Vector4[MAX_LIGHTS];
        Vector4[] lightDir = new Vector4[MAX_LIGHTS];
        Vector4[] lightCol = new Vector4[MAX_LIGHTS];
        Vector4[] lightAtten = new Vector4[MAX_LIGHTS];
        Vector4[] spotParams = new Vector4[MAX_LIGHTS];

        // Arrays used to send shadow data to the shader
        Matrix4x4[] shadowMatrices = new Matrix4x4[MAX_LIGHTS];
        float[] shadowEnabled = new float[MAX_LIGHTS];

        // Loop through the maximum supported lights
        for (int i = 0; i < MAX_LIGHTS; i++)
        {
            // If a valid light exists at this index, populate shader data
            if (i < lights.Count)
            {
                CustomLight l = lights[i];

                // World-space position of the light
                lightPos[i] = l.transform.position;

                // Forward direction of the light (used for directional and spot lights)
                lightDir[i] = l.GetDirection();

                // RGB color multiplied by intensity, with light type stored in the alpha channel
                lightCol[i] = new Vector4(
                    l.color.r * l.intensity,
                    l.color.g * l.intensity,
                    l.color.b * l.intensity,
                    (float)l.type
                );

                // Attenuation parameters for distance-based falloff
                lightAtten[i] = new Vector4(
                    l.attenuation.x,
                    l.attenuation.y,
                    l.attenuation.z,
                    0
                );

                // Convert spot light angles to cosine values for shader comparisons
                float outerRad = l.spotAngle * Mathf.Deg2Rad;
                float innerRad = l.spotInnerAngle * Mathf.Deg2Rad;
                spotParams[i] = new Vector4(
                    Mathf.Cos(outerRad),
                    Mathf.Cos(innerRad),
                    0,
                    0
                );

                // Handle shadow data if the light casts shadows
                if (l.castShadows && l.shadowMap != null)
                {
                    // Store the light's view-projection matrix for shadow mapping
                    shadowMatrices[i] = l.viewProjMatrix;
                    shadowEnabled[i] = 1.0f;

                    // Point lights use cubemap shadow textures
                    if (l.type == CustomLight.LightType.Point)
                    {
                        Shader.SetGlobalTexture("_GlobalShadowMapCube" + i, l.shadowMap);
                        Shader.SetGlobalTexture("_GlobalShadowMap" + i, Texture2D.whiteTexture);
                    }
                    // Spot and directional lights use 2D shadow maps
                    else
                    {
                        Shader.SetGlobalTexture("_GlobalShadowMap" + i, l.shadowMap);
                    }
                }
                else
                {
                    // Disable shadows for this light
                    shadowMatrices[i] = Matrix4x4.identity;
                    shadowEnabled[i] = 0.0f;

                    // Bind safe default textures so the shader never samples invalid memory
                    Shader.SetGlobalTexture("_GlobalShadowMap" + i, Texture2D.whiteTexture);
                    Shader.SetGlobalTexture("_GlobalShadowMapCube" + i, Texture2D.blackTexture);
                }
            }
        }

        // Send all lighting arrays to the shader as global parameters
        Shader.SetGlobalVectorArray("_GlobalLightPos", lightPos);
        Shader.SetGlobalVectorArray("_GlobalLightDir", lightDir);
        Shader.SetGlobalVectorArray("_GlobalLightCol", lightCol);
        Shader.SetGlobalVectorArray("_GlobalLightAtten", lightAtten);
        Shader.SetGlobalVectorArray("_GlobalSpotParams", spotParams);

        // Tell the shader how many lights are currently active
        Shader.SetGlobalInt("_ActiveLightCount", lights.Count);

        // Send shadow-related data to the shader
        Shader.SetGlobalMatrixArray("_GlobalShadowMatrices", shadowMatrices);
        Shader.SetGlobalFloatArray("_GlobalShadowEnabled", shadowEnabled);
    }
}
