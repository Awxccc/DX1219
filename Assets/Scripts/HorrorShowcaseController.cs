using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.UI;

public class HorrorShowcaseController : MonoBehaviour
{
    [Header("UI References")]
    [SerializeField] private Slider sanitySlider;
    [SerializeField] private Slider glitchSlider;

    [Header("Volume")]
    [SerializeField] private Volume globalVolume;

    private PsychosisVolume _psychosisProfile;
    private GlitchVolume _glitchProfile;

    private void Start()
    {
        // Find the Global Volume if not assigned manually
        if (globalVolume == null) globalVolume = FindAnyObjectByType<Volume>();

        // Safety check to prevent errors if volume is missing
        if (globalVolume != null && globalVolume.profile != null)
        {
            // Try to get the specific overrides from the volume profile
            if (globalVolume.profile.TryGet(out PsychosisVolume psycho))
            {
                _psychosisProfile = psycho;
            }

            if (globalVolume.profile.TryGet(out GlitchVolume glitch))
            {
                _glitchProfile = glitch;
            }
        }

        // Setup Sliders
        if (sanitySlider != null)
        {
            sanitySlider.onValueChanged.AddListener(OnSanityChanged);
            // Initialize slider to match current volume value if it exists
            if (_psychosisProfile != null) sanitySlider.value = _psychosisProfile.insanityLevel.value;
        }

        if (glitchSlider != null)
        {
            glitchSlider.onValueChanged.AddListener(OnGlitchChanged);
            // Initialize slider to match current volume value if it exists
            if (_glitchProfile != null) glitchSlider.value = _glitchProfile.intensity.value;
        }
    }

    private void OnSanityChanged(float value)
    {
        if (_psychosisProfile != null)
        {
            // FIX: Changed 'intensity' to 'insanityLevel' to match the PsychosisVolume script
            _psychosisProfile.insanityLevel.Override(value);
        }
    }

    private void OnGlitchChanged(float value)
    {
        if (_glitchProfile != null)
        {
            // GlitchVolume uses 'intensity', so this remains the same
            _glitchProfile.intensity.Override(value);
        }
    }
}