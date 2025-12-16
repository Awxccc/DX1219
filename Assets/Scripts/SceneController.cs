using UnityEngine;
using UnityEngine.InputSystem;

[RequireComponent(typeof(PlayerInput))]
public class SceneController : MonoBehaviour
{
    [Header("Lighting References")]
    public CustomLight mainLight;
    public CustomLight[] pointLights;
    public GameObject waterObject;

    [Header("Settings")]
    public float waterSpeedMultiplier = 0.5f;

    private PlayerInput playerInput;
    private InputAction waterControlAction;
    public GameObject dissolveObject;
    private float dissolveValue = 0;

    private void Awake()
    {
        playerInput = GetComponent<PlayerInput>();

        // 1. Setup Toggle Shadow (One-shot event)
        // We look up the action by string name "ToggleShadow"
        var toggleAction = playerInput.actions["ToggleShadow"];
        if (toggleAction != null)
        {
            toggleAction.performed += ctx => ToggleShadows();
        }
        else
        {
            Debug.LogWarning("Action 'ToggleShadow' not found in PlayerInput!");
        }

        // 2. Setup Cycle Lights (One-shot event)
        var cycleAction = playerInput.actions["CycleLights"];
        if (cycleAction != null)
        {
            cycleAction.performed += ctx => CycleLightColors();
        }

        // 3. Cache Water Control (Continuous value)
        waterControlAction = playerInput.actions["WaterControl"];
    }

    private void Update()
    {
        // Continuous input polling
        if (waterControlAction != null && waterObject != null)
        {
            float waterInput = waterControlAction.ReadValue<float>();

            if (Mathf.Abs(waterInput) > 0.01f)
            {
                Material mat = waterObject.GetComponent<Renderer>().material;
                Vector4 speed = mat.GetVector("_WaveSpeed");
                speed.y += waterInput * waterSpeedMultiplier * Time.deltaTime;
                mat.SetVector("_WaveSpeed", speed);
            }
        }
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
            pl.color = Color.HSVToRGB(Random.value, 1f, 1f);
        }
    }
}