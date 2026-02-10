using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[ExecuteAlways]
public class SanityController : MonoBehaviour
{
    [Header("Sanity Settings")]
    [Range(0f, 1f)] public float currentSanity = 1.0f; // 1 = Sane, 0 = Insane
    public float sanityDrainRate = 0.05f;
    public float recoveryRate = 0.02f;

    [Header("Effect References")]
    public Volume globalVolume;

    // Internal references to your custom volume components
    private PsychosisVolume _psychosis;
    private GlitchVolume _glitch;

    private float _heartbeatTimer;
    private float _targetVignette;

    void Update()
    {
        // 1. Manage Sanity Logic (Only in Play Mode)
        if (Application.isPlaying)
        {
            // Example: Drain sanity automatically over time
            currentSanity = Mathf.Clamp01(currentSanity - (sanityDrainRate * Time.deltaTime));
        }

        // 2. Set Global Shader Variable for ALL shaders to use (Water, Fog, etc.)
        // This is crucial for "Seamless Integration" across the whole project
        Shader.SetGlobalFloat("_GlobalSanity", 1.0f - currentSanity);

        // 3. Drive Post Processing
        UpdatePostProcessing();
    }

    void UpdatePostProcessing()
    {
        if (globalVolume == null || globalVolume.profile == null) return;

        // Try to get our custom components if we haven't yet
        if (_psychosis == null) globalVolume.profile.TryGet(out _psychosis);
        if (_glitch == null) globalVolume.profile.TryGet(out _glitch);

        float insanityFactor = 1.0f - currentSanity; // 0 = Calm, 1 = Horror

        // --- Drive Psychosis ---
        if (_psychosis != null)
        {
            _psychosis.active = insanityFactor > 0.01f;
            _psychosis.insanityLevel.value = insanityFactor;

            // Heartbeat Logic: Pulse the vignette based on how scared we are
            float pulseSpeed = Mathf.Lerp(1.0f, 4.0f, insanityFactor); // Fast beat when scared
            _heartbeatTimer += Time.deltaTime * pulseSpeed;

            // Create a sharp "thump-thump" curve
            float heartbeat = Mathf.Sin(_heartbeatTimer) * 0.5f + 0.5f;
            heartbeat = Mathf.Pow(heartbeat, 4.0f); // Sharpen the curve

            // Blend the vignette: Base value + Heartbeat pulse
            float baseVignette = Mathf.Lerp(0.3f, 0.6f, insanityFactor);
            _psychosis.vignettePower.value = baseVignette + (heartbeat * 0.15f * insanityFactor);

            // Aberration gets worse with low sanity
            _psychosis.aberrationAmount.value = insanityFactor * 1.5f;
        }

        // --- Drive Glitch ---
        if (_glitch != null)
        {
            // Glitch only starts appearing when sanity is below 50%
            if (insanityFactor > 0.5f)
            {
                _glitch.active = true;

                // Remap 0.5-1.0 range to 0.0-1.0
                float glitchSeverity = (insanityFactor - 0.5f) * 2.0f;

                // Randomly spike the glitch intensity to feel "broken"
                float spasm = Random.value > 0.95f ? 1.0f : 0.0f;

                _glitch.intensity.value = Mathf.Lerp(glitchSeverity * 0.5f, glitchSeverity, Random.value) + (spasm * 0.2f);
                _glitch.scanlines.value = glitchSeverity;
                _glitch.noiseScale.value = Mathf.Lerp(10f, 50f, glitchSeverity);
            }
            else
            {
                _glitch.active = false;
                _glitch.intensity.value = 0f;
            }
        }
    }
}