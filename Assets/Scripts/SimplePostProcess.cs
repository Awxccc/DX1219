using UnityEngine;

[ExecuteInEditMode]
public class SimplePostProcess : MonoBehaviour
{
    [Header("Shader Reference")]
    public Material postMaterial;

    [Header("Glitch Settings")]
    [Range(0, 0.2f)]
    public float glitchAmount = 0.01f;

    [Range(0, 50f)]
    public float speed = 10.0f;

    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (postMaterial != null)
        {
            // Send the values to the Glitch Shader
            postMaterial.SetFloat("_GlitchAmount", glitchAmount);
            postMaterial.SetFloat("_Speed", speed);

            // Render the effect
            Graphics.Blit(source, destination, postMaterial);
        }
        else
        {
            // Fallback if no material is assigned
            Graphics.Blit(source, destination);
        }
    }
}