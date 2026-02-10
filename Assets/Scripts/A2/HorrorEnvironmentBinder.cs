using UnityEngine;

[ExecuteAlways]
public class HorrorEnvironmentBinder : MonoBehaviour
{
    [Header("Target Material")]
    public Material targetMaterial;

    [Header("Settings")]
    public EnvironmentType type;

    public enum EnvironmentType
    {
        HorrorWater,
        PhasmicGhost
    }

    void Update()
    {
        if (targetMaterial == null) return;

        // 1. Read the Global Sanity set by SanityController.cs
        // Value is 0.0 (Calm) to 1.0 (Insane)
        float sanity = Shader.GetGlobalFloat("_GlobalSanity");

        if (type == EnvironmentType.HorrorWater)
        {
            // Water becomes faster and more turbulent when insane
            float waveSpeed = Mathf.Lerp(0.5f, 3.0f, sanity);
            float rippleStrength = Mathf.Lerp(1.0f, 5.0f, sanity);

            targetMaterial.SetFloat("_WaveSpeed", waveSpeed);
            targetMaterial.SetFloat("_RippleStrength", rippleStrength);

            // Optional: Turn water blood red as you go insane
            Color calmColor = new Color(0, 0.3f, 0.5f, 1);
            Color insaneColor = new Color(0.6f, 0, 0, 1);
            targetMaterial.SetColor("_BaseColor", Color.Lerp(calmColor, insaneColor, sanity));
        }
        else if (type == EnvironmentType.PhasmicGhost)
        {
            // Ghost becomes more solid and "shaky" when insane
            float alpha = Mathf.Lerp(0.1f, 0.8f, sanity); // Faint -> Solid
            float wobble = Mathf.Lerp(0.5f, 10.0f, sanity); // Calm -> Violent shaking

            targetMaterial.SetFloat("_GhostAlpha", alpha);
            targetMaterial.SetFloat("_WobbleSpeed", wobble);
        }
    }
}