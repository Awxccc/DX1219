using UnityEngine;

public class CustomLight : MonoBehaviour
{
    public enum LightType { Directional = 0, Point = 1, Spot = 2 }
    public LightType type;
    public Color color = Color.white;
    public float intensity = 1.0f;

    // Attenuation: x = constant, y = linear, z = quadratic
    public Vector3 attenuation = new Vector3(1.0f, 0.09f, 0.032f);

    [Range(0, 180)] public float spotAngle = 30.0f;
    [Range(0, 180)] public float spotInnerAngle = 25.0f;

    // Shadow settings
    public bool castShadows = false;
    public RenderTexture shadowMap;
    public Matrix4x4 viewProjMatrix;

    public Vector3 GetDirection()
    {
        return transform.forward; // Normalized by Unity transform
    }
}