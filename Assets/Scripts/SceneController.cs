using UnityEngine;
using UnityEngine.InputSystem;

[RequireComponent(typeof(PlayerInput))]
public class SceneController : MonoBehaviour
{
    [Header("Lighting References")]
    public CustomLight mainLight;       // Your Directional Light
    public CustomLight[] pointLights;   // Array of Point Lights
    public CustomLight[] spotLights;    // Array of Spot Lights (NEW)

    [Header("Settings")]
    public float waterSpeedMultiplier = 0.5f;

    private PlayerInput playerInput;
    private InputAction waterControlAction;
    public GameObject dissolveObject;
    private float dissolveValue = 0;

    private void Awake()
    {
        playerInput = GetComponent<PlayerInput>();

        // 1. Setup Toggle Shadow (Existing)
        var toggleAction = playerInput.actions["ToggleShadow"];
        if (toggleAction != null)
        {
            toggleAction.performed += ctx => ToggleShadows();
        }

        // 2. Setup Cycle Lights (Existing)
        var cycleAction = playerInput.actions["CycleLights"];
        if (cycleAction != null)
        {
            cycleAction.performed += ctx => CycleLightColors();
        }

        // 3. Setup Light Toggles (NEW)
        // Ensure you add these Action names to your Input System Asset!
        var toggleDirAction = playerInput.actions["ToggleDirectional"];
        if (toggleDirAction != null)
            toggleDirAction.performed += ctx => ToggleDirectionalLight();

        var togglePointAction = playerInput.actions["TogglePoint"];
        if (togglePointAction != null)
            togglePointAction.performed += ctx => TogglePointLights();

        var toggleSpotAction = playerInput.actions["ToggleSpot"];
        if (toggleSpotAction != null)
            toggleSpotAction.performed += ctx => ToggleSpotLights();

        // 4. Cache Water Control
        waterControlAction = playerInput.actions["WaterControl"];
    }

    private void Update()
    {

        // Dissolve Logic
        if (Keyboard.current.tKey.isPressed)
        {
            dissolveValue += Time.deltaTime;
        }
        else
        {
            dissolveValue -= Time.deltaTime;
        }
        dissolveValue = Mathf.Clamp01(dissolveValue);

        if (dissolveObject)
        {
            dissolveObject.GetComponent<Renderer>().material.SetFloat("_DissolveAmount", dissolveValue);
        }
    }

    // --- Helper Functions ---

    private void ToggleShadows()
    {
        if (mainLight != null)
        {
            mainLight.castShadows = !mainLight.castShadows;
            Debug.Log($"Shadows {(mainLight.castShadows ? "Enabled" : "Disabled")}");
        }
    }

    private void CycleLightColors()
    {
        if (pointLights == null) return;

        foreach (var pl in pointLights)
        {
            // Simple Null check in case a light was destroyed
            if (pl != null)
                pl.color = Color.HSVToRGB(Random.value, 1f, 1f);
        }
    }

    // --- NEW TOGGLE FUNCTIONS ---

    private void ToggleDirectionalLight()
    {
        if (mainLight != null)
        {
            mainLight.enabled = !mainLight.enabled;
            Debug.Log($"Directional Light {(mainLight.enabled ? "On" : "Off")}");
        }
    }

    private void TogglePointLights()
    {
        if (pointLights != null)
        {
            bool anyOn = false;
            // Check the state of the first one to sync them (all on or all off)
            if (pointLights.Length > 0 && pointLights[0] != null) anyOn = pointLights[0].enabled;

            foreach (var l in pointLights)
            {
                if (l != null) l.enabled = !anyOn; // Flip state
            }
            Debug.Log($"Point Lights {(!anyOn ? "On" : "Off")}");
        }
    }

    private void ToggleSpotLights()
    {
        if (spotLights != null)
        {
            bool anyOn = false;
            if (spotLights.Length > 0 && spotLights[0] != null) anyOn = spotLights[0].enabled;

            foreach (var l in spotLights)
            {
                if (l != null) l.enabled = !anyOn; // Flip state
            }
            Debug.Log($"Spot Lights {(!anyOn ? "On" : "Off")}");
        }
    }
}