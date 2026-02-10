using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class SanityController : MonoBehaviour
{
    [Header("Debug")]
    [Tooltip("If checked, the script will NOT update values, allowing you to edit them manually.")]
    public bool manualOverride = false;

    [Header("Sanity Settings")]
    [Range(0f, 1f)] public float currentSanity = 1.0f; // 1 = Sane, 0 = Insane
    public float sanityDrainRate = 0.05f;

    [Header("Effect References")]
    public Volume globalVolume;

    // Internal references
    private PsychosisVolume _psychosis;
    private GlitchVolume _glitch;
    private VolumetricFogVolume _volumetricFog;

    private float _heartbeatTimer;

    void Start()
    {
        // Ensure variable is set at least once on start
        Shader.SetGlobalFloat("_GlobalSanity", 1.0f - currentSanity);
    }

    void Update()
    {
        // 1. Sanity Logic (Always runs logic, but only updates visuals if not overridden)
        if (Application.isPlaying && !manualOverride)
        {
            currentSanity = Mathf.Clamp01(currentSanity - (sanityDrainRate * Time.deltaTime));
        }

        // 2. Set Global Shader Variable (Always update this so walls/water work)
        Shader.SetGlobalFloat("_GlobalSanity", 1.0f - currentSanity);

        // 3. Drive Post Processing
        if (!manualOverride)
        {
            UpdatePostProcessing();
        }
    }

    void UpdatePostProcessing()
    {
        if (globalVolume == null || globalVolume.profile == null) return;

        // Try to get our custom components
        if (_psychosis == null) globalVolume.profile.TryGet(out _psychosis);
        if (_glitch == null) globalVolume.profile.TryGet(out _glitch);
        if (_volumetricFog == null) globalVolume.profile.TryGet(out _volumetricFog);

        float insanityFactor = 1.0f - currentSanity;

        // --- Drive Psychosis ---
        if (_psychosis != null)
        {
            _psychosis.active = insanityFactor > 0.01f;
            _psychosis.insanityLevel.value = insanityFactor;

            float pulseSpeed = Mathf.Lerp(1.0f, 4.0f, insanityFactor);
            _heartbeatTimer += Time.deltaTime * pulseSpeed;

            float heartbeat = Mathf.Sin(_heartbeatTimer) * 0.5f + 0.5f;
            heartbeat = Mathf.Pow(heartbeat, 4.0f);

            float baseVignette = Mathf.Lerp(0.3f, 0.6f, insanityFactor);
            _psychosis.vignettePower.value = baseVignette + (heartbeat * 0.15f * insanityFactor);
            _psychosis.aberrationAmount.value = insanityFactor * 1.5f;
        }

        // --- Drive Glitch ---
        if (_glitch != null)
        {
            if (insanityFactor > 0.5f)
            {
                _glitch.active = true;
                float glitchSeverity = (insanityFactor - 0.5f) * 2.0f;
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

        // --- Drive Fog ---
        if (_volumetricFog != null)
        {
            _volumetricFog.active = true;
            _volumetricFog.intensity.value = 1.0f;
        }
    }
}