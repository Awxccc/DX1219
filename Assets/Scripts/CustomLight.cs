using UnityEngine;
using UnityEngine.Rendering;

public class CustomLight : MonoBehaviour
{
    public enum LightType { Directional = 0, Point = 1, Spot = 2 }
    public LightType type;
    public Color color = Color.white;
    public float intensity = 1.0f;


    // Attenuation: x = constant, y = linear, z = quadratic
    public Vector3 attenuation = new(1.0f, 0.09f, 0.032f);

    [Range(0, 180)] public float spotAngle = 30.0f;
    [Range(0, 180)] public float spotInnerAngle = 25.0f;

    // Shadow settings
    public bool castShadows = false;
    public RenderTexture shadowMap;
    public Matrix4x4 viewProjMatrix;
    public Camera shadowCamera;

    void Update()
    {
        if (castShadows && shadowCamera != null)
        {
            UpdateShadowMap();
        }
    }

    void UpdateShadowMap()
    {
        // 1. Setup for POINT Light (360 Cubemap)
        if (type == LightType.Point)
        {
            // Ensure the RenderTexture is actually a CUBEMAP
            if (shadowMap == null || shadowMap.dimension != TextureDimension.Cube)
            {
                // Create a 1024x1024 Cubemap with 16-bit Depth
                shadowMap = new RenderTexture(1024, 1024, 16)
                {
                    dimension = TextureDimension.Cube
                };
                shadowMap.Create();
            }

            // This magic function renders the scene 6 times (Front, Back, Left, Right, Up, Down)
            // and stores it in the Cubemap automatically.
            shadowCamera.RenderToCubemap(shadowMap);
        }

        // 2. Setup for SPOT / DIRECTIONAL (Standard 2D Map)
        else
        {
            // Ensure the RenderTexture is a 2D Texture
            if (shadowMap == null || shadowMap.dimension != TextureDimension.Tex2D)
            {
                shadowMap = new RenderTexture(1024, 1024, 16)
                {
                    dimension = TextureDimension.Tex2D
                };
                shadowMap.Create();
            }

            // Standard render
            shadowCamera.targetTexture = shadowMap;
            shadowCamera.Render();
        }
    }

    public Vector3 GetDirection()
    {
        return transform.forward; // Normalized by Unity transform
    }
}