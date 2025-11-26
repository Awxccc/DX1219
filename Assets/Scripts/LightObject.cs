using UnityEngine;
[ExecuteInEditMode]
public class LightObject : MonoBehaviour
{
    public enum Type
    {
        DIRECTIONAL = 0,
        POINT = 1,
        SPOT = 2,
    }
    [SerializeField] private Type type;

    [SerializeField] private Vector3 direction = new(0, -1, 0);
    [SerializeField] private Material material;
    [SerializeField] private Color lightColor;
    [SerializeField] [Range(0f, 1f)] private float smoothness;
    [SerializeField] [Range(0f, 10f)] private float intensity;
    [SerializeField] private Vector3 attenuation = new(1.0f, 0.09f, 0.032f);

    [SerializeField] private float _spotLightCutOff = 70.0f;
    [SerializeField] private float _innerSpotLightCutOff = 25.0f;

    private void SendToShader()
    {
        material.SetVector("_lightPosition", transform.position);
        material.SetVector("_lightDirection", direction);
        material.SetColor("_lightColor", lightColor);
        material.SetFloat("_smoothness", smoothness);
        material.SetInteger("_lightType", (int)type);
        material.SetFloat("_lightIntensity", intensity);
        material.SetVector("_attenuation", attenuation);
        material.SetFloat("_spotLightCutOff", _spotLightCutOff);
        material.SetFloat("_innerSpotLightCutOff", _innerSpotLightCutOff);
    }
    // Update is called once per frame
    void Update()
    {
        direction = transform.rotation * new Vector3(0, -1, 0);
        direction = direction.normalized;

        SendToShader();
    }

    private void OnDrawGizmos()
    {
        //Draw a yellow sphere at the transform's position
        Gizmos.color = Color.yellow;
        Gizmos.DrawWireSphere(transform.position, 1);
        Gizmos.DrawRay(transform.position, direction * 10.0f);
    }

    public Material GetMaterial()
    {
        return material;
    }
    public Vector3 GetDirection()
    {
        return direction;
    }
}

