using UnityEngine;
using UnityEngine.InputSystem;

[RequireComponent(typeof(PlayerInput))]
public class SceneController : MonoBehaviour
{
    [Header("Lighting References")]
    public CustomLight mainLight;
    public CustomLight[] pointLights;
    public CustomLight[] spotLights;

    [Header("Settings")]
    public float waterSpeedMultiplier = 0.5f;

    private PlayerInput playerInput;
    private InputAction waterControlAction;
    public GameObject dissolveObject;
    private float dissolveValue = 0;

    private void Awake()
    {
        playerInput = GetComponent<PlayerInput>();

        InputAction toggleAction = playerInput.actions["ToggleShadow"];
        if (toggleAction != null)
        {
            toggleAction.performed += ctx => ToggleShadows();
        }

        InputAction cycleAction = playerInput.actions["CycleLights"];
        if (cycleAction != null)
        {
            cycleAction.performed += ctx => CycleLightColors();
        }

        InputAction toggleDirAction = playerInput.actions["ToggleDirectional"];
        if (toggleDirAction != null)
            toggleDirAction.performed += ctx => ToggleDirectionalLight();

        InputAction togglePointAction = playerInput.actions["TogglePoint"];
        if (togglePointAction != null)
            togglePointAction.performed += ctx => TogglePointLights();

        InputAction toggleSpotAction = playerInput.actions["ToggleSpot"];
        if (toggleSpotAction != null)
            toggleSpotAction.performed += ctx => ToggleSpotLights();

        waterControlAction = playerInput.actions["WaterControl"];
    }

    private void Update()
    {
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
            if (pl != null)
                pl.color = Color.HSVToRGB(Random.value, 1f, 1f);
        }
    }

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
            if (pointLights.Length > 0 && pointLights[0] != null) anyOn = pointLights[0].enabled;

            foreach (var l in pointLights)
            {
                if (l != null) l.enabled = !anyOn;
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
                if (l != null) l.enabled = !anyOn;
            }
            Debug.Log($"Spot Lights {(!anyOn ? "On" : "Off")}");
        }
    }
}