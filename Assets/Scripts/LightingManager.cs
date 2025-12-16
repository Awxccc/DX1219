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

                if (l.castShadows && l.shadowMap != null)
                {
                    shadowMatrices[i] = l.viewProjMatrix;
                    shadowEnabled[i] = 1.0f;

                    // CHECK THE TYPE: Is it a Point Light?
                    if (l.type == CustomLight.LightType.Point)
                    {
                        // Assign to the CUBE slot
                        // Note: Ensure l.shadowMap is actually a Cubemap dimension RenderTexture!
                        Shader.SetGlobalTexture("_GlobalShadowMapCube" + i, l.shadowMap);

                        // Safety: Bind a dummy 2D texture to the other slot just in case
                        Shader.SetGlobalTexture("_GlobalShadowMap" + i, Texture2D.whiteTexture);
                    }
                    else
                    {
                        // Assign to the 2D slot (Spot / Directional)
                        Shader.SetGlobalTexture("_GlobalShadowMap" + i, l.shadowMap);

                        // Safety: Bind a dummy Cube to the other slot
                        // (Unity doesn't have a default whiteCube, but usually null is safe or you can make a dummy one)
                    }
                }
                else
                {
                    shadowMatrices[i] = Matrix4x4.identity;
                    shadowEnabled[i] = 0.0f;

                    // Bind defaults to BOTH slots to prevent reading garbage memory
                    Shader.SetGlobalTexture("_GlobalShadowMap" + i, Texture2D.whiteTexture);
                    // For Cubemaps, we can't easily pass "Texture2D.whiteTexture", 
                    // passing null usually clears it or leaves it as black (no shadow).
                    Shader.SetGlobalTexture("_GlobalShadowMapCube" + i, Texture2D.blackTexture);
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
}