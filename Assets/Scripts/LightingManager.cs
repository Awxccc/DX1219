using System.Collections.Generic;
using UnityEngine;
[ExecuteInEditMode]
public class LightingManager : MonoBehaviour
{
    // Maximum lights supported in Shader
    private const int MAX_LIGHTS = 4;

    private List<CustomLight> lights = new List<CustomLight>();

    void Update()
    {
        lights.Clear();
        CustomLight[] foundLights = FindObjectsByType<CustomLight>(FindObjectsSortMode.None);
        // Filter active lights only
        foreach (var l in foundLights) { if (l.isActiveAndEnabled) lights.Add(l); }

        // Shader Arrays
        Vector4[] lightPos = new Vector4[MAX_LIGHTS];
        Vector4[] lightDir = new Vector4[MAX_LIGHTS];
        Vector4[] lightCol = new Vector4[MAX_LIGHTS];
        Vector4[] lightAtten = new Vector4[MAX_LIGHTS];
        Vector4[] spotParams = new Vector4[MAX_LIGHTS];

        // --- NEW: Shadow Arrays ---
        Matrix4x4[] shadowMatrices = new Matrix4x4[MAX_LIGHTS];
        float[] shadowEnabled = new float[MAX_LIGHTS]; // 1.0 = Casts Shadow, 0.0 = No Shadow

        for (int i = 0; i < MAX_LIGHTS; i++)
        {
            if (i < lights.Count)
            {
                CustomLight l = lights[i];
                lightPos[i] = l.transform.position;
                lightDir[i] = l.GetDirection();
                lightCol[i] = new Vector4(l.color.r * l.intensity, l.color.g * l.intensity, l.color.b * l.intensity, (float)l.type);
                lightAtten[i] = new Vector4(l.attenuation.x, l.attenuation.y, l.attenuation.z, 0);

                float outerRad = l.spotAngle * Mathf.Deg2Rad;
                float innerRad = l.spotInnerAngle * Mathf.Deg2Rad;
                spotParams[i] = new Vector4(Mathf.Cos(outerRad), Mathf.Cos(innerRad), 0, 0);

                // --- NEW SHADOW LOGIC ---
                // Send specific data for THIS light index
                if (l.castShadows && l.shadowMap != null)
                {
                    shadowMatrices[i] = l.viewProjMatrix;
                    shadowEnabled[i] = 1.0f; // True

                    // Bind the Texture to a unique slot for this index (e.g. "_ShadowMap0", "_ShadowMap1")
                    Shader.SetGlobalTexture("_GlobalShadowMap" + i, l.shadowMap);
                }
                else
                {
                    shadowMatrices[i] = Matrix4x4.identity;
                    shadowEnabled[i] = 0.0f; // False
                    // Bind a default white texture so shader doesn't crash
                    Shader.SetGlobalTexture("_GlobalShadowMap" + i, Texture2D.whiteTexture);
                }
            }
            else
            {
                // Clear empty slots
                lightCol[i] = Vector4.zero;
                shadowEnabled[i] = 0.0f;
            }
        }

        // Send Light Data
        Shader.SetGlobalVectorArray("_GlobalLightPos", lightPos);
        Shader.SetGlobalVectorArray("_GlobalLightDir", lightDir);
        Shader.SetGlobalVectorArray("_GlobalLightCol", lightCol);
        Shader.SetGlobalVectorArray("_GlobalLightAtten", lightAtten);
        Shader.SetGlobalVectorArray("_GlobalSpotParams", spotParams);
        Shader.SetGlobalInt("_ActiveLightCount", lights.Count);

        // --- Send Shadow Data ---
        // We can send matrices as an array!
        Shader.SetGlobalMatrixArray("_GlobalShadowMatrices", shadowMatrices);
        Shader.SetGlobalFloatArray("_GlobalShadowEnabled", shadowEnabled);

        // Note: We ALREADY sent the Textures inside the loop above!
    }
}