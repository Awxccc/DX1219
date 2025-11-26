using System;
using UnityEngine;

public class ShadowMapRenderer : MonoBehaviour
{
    [SerializeField] private LightObject lightObject;

    [SerializeField] private int shadowMapResolution = 1024;

    [SerializeField] private float shadowBias = 0.005f;

    private Camera lightCamera;
    private RenderTexture shadowMap;

    // Start is called once before the first execution of Update after the MonoBehaviour is created
    void Start()
    {
        //Assuming that the light object class are in the same game object
        lightObject = GetComponent<LightObject>();

        if (lightObject == null)
        {
            Debug.LogError("ShadowMapper requires a LightObject.");
            return;
        }

        CreateLightCamera();

        //Create shadow camera
        GameObject lightCamObject = new("Light Camera");
        lightCamera = lightCamObject.AddComponent<Camera>();
        lightCamera.enabled = false; //Manual rendering
        lightCamera.clearFlags = CameraClearFlags.Depth;
        lightCamera.backgroundColor = Color.white;
        lightCamera.targetTexture = shadowMap;

        //Configure camera type
        lightCamera.nearClipPlane = 0.1f;
        lightCamera.farClipPlane = 100.0f;
        lightCamera.orthographic = true;
        lightCamera.orthographicSize = 30.0f;

        lightCamObject.transform.SetParent(lightObject.transform, false);
    }

    // Update is called once per frame
    void Update()
    {
        if(lightCamera == null || shadowMap == null)
        {
            return;
        }

        UpdateLightCamera();
        SendShadowDataToShader();
    }

    private void SendShadowDataToShader()
    {
        Material material = lightObject.GetMaterial();
        if(material == null)
        {
            return;
        }
        //Calculate light's view-projection matrix
        Matrix4x4 lightViewProjMatrix = lightCamera.projectionMatrix * lightCamera.worldToCameraMatrix;

        //Send shadow data to shader
        material.SetTexture("_shadowMap", shadowMap);
        material.SetFloat("_shadowBias", shadowBias);
        material.SetMatrix("_lightViewProj", lightViewProjMatrix);
    }

    private void UpdateLightCamera()
    {
        //Sync shadow camera with light transform
        lightCamera.transform.position = lightObject.transform.position;
        lightCamera.transform.forward = lightObject.GetDirection();

        //Render shadow map manually
        lightCamera.Render();
    }

    private void CreateLightCamera()
    {
        //Create shadow map render texture
        shadowMap = new RenderTexture(shadowMapResolution, shadowMapResolution, 24, RenderTextureFormat.Depth);
        shadowMap.Create();
    }

    private void OnDestroy()
    {
        if(shadowMap != null)
        {
            shadowMap.Release();
        }
        if(lightCamera != null)
        {
            Destroy(lightCamera.gameObject);
        }
    }

    private void OnGUI()
    {
        GUI.DrawTexture(new Rect(0, 0, 256, 256), shadowMap, ScaleMode.ScaleToFit, false);
    }
}
