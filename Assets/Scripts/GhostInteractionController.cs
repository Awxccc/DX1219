using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class GhostInteractionController : MonoBehaviour
{
    [Header("References")]
    public Transform playerCamera;   // Assign your Main Camera or Player
    public Transform ghostTarget;    // Assign the Ghost Object
    public ScriptableRendererFeature psychosisFeature; // Drag the RenderFeature from the list here if possible, or we find it via code

    [Header("Settings")]
    public float maxDistance = 10f; // Distance where effects start
    public float minDistance = 2f;  // Distance where you go fully insane

    [Header("Ghost Material Control")]
    public Renderer ghostRenderer;
    private Material ghostInstanceMat;

    // Internal reference to the specific feature settings
    private PsychosisRendererFeature castedFeature;

    void Start()
    {
        // Setup Ghost Material to allow dynamic changes
        if (ghostRenderer != null)
        {
            ghostInstanceMat = ghostRenderer.material;
        }

        // Auto-find references if missing
        if (playerCamera == null && Camera.main != null)
            playerCamera = Camera.main.transform;

        // Try to find the renderer feature in the current volume or graphics settings
        // (Note: Direct modification of RendererFeatures at runtime is advanced. 
        // For assignment safety, ensure you dragged the reference in Inspector if using a custom pipeline asset manager, 
        // otherwise this logic attempts to fetch it.)
        var pipeline = GraphicsSettings.currentRenderPipeline as UniversalRenderPipelineAsset;
        // Note: Accessing features list directly via code is tricky in URP. 
        // A safer way for assignments is using a static reference or singleton. 
        // For now, ensure you assign 'psychosisFeature' in the Inspector.
        castedFeature = psychosisFeature as PsychosisRendererFeature;
    }

    void Update()
    {
        if (playerCamera == null || ghostTarget == null) return;

        // 1. Calculate Normalized Distance (0.0 to 1.0)
        float dist = Vector3.Distance(playerCamera.position, ghostTarget.position);

        // Inverse Lerp: returns 0 when at maxDistance, 1 when at minDistance
        float dangerLevel = Mathf.InverseLerp(maxDistance, minDistance, dist);

        // 2. Drive the Post-Processing (Psychosis)
        if (castedFeature != null)
        {
            // Smoothly interpolate for a "Seamless" feel
            castedFeature.settings.intensity = Mathf.Lerp(castedFeature.settings.intensity, dangerLevel, Time.deltaTime * 5f);
        }

        // 3. Drive the Shader Graph (Phasmic Ghost)
        // Assumption: You added a "_GlitchIntensity" float property to your Shader Graph
        if (ghostInstanceMat != null)
        {
            // As we get closer, the ghost glitches MORE (Higher speed or threshold)
            ghostInstanceMat.SetFloat("_GlitchIntensity", dangerLevel);

            // Optional: Make it pulse faster
            ghostInstanceMat.SetFloat("_PulseSpeed", 1.0f + (dangerLevel * 10.0f));
        }

        // 4. Simple Chase Logic (Requested)
        MoveGhost(dist);
    }

    void MoveGhost(float currentDist)
    {
        // Simple chase: Only move if player is within range but not TOO close (collision)
        if (currentDist < maxDistance && currentDist > 1.0f)
        {
            // Look at player
            ghostTarget.LookAt(new Vector3(playerCamera.position.x, ghostTarget.position.y, playerCamera.position.z));
            // Move forward
            ghostTarget.Translate(Vector3.forward * 2.0f * Time.deltaTime);
        }
    }
}