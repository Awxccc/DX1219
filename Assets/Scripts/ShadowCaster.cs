using UnityEngine;

[RequireComponent(typeof(CustomLight))]
public class ShadowCaster : MonoBehaviour
{
    public int resolution = 2048;

    [Header("Directional Settings")]
    public float orthoSize = 20.0f;

    [Header("Spot Settings")]
    public float nearPlane = 0.1f;
    public float farPlane = 100.0f;

    public float shadowBias = 0.005f;

    private Camera shadowCam;
    private RenderTexture shadowRT;
    private CustomLight customLight;

    void Start()
    {
        customLight = GetComponent<CustomLight>();

        shadowRT = new RenderTexture(resolution, resolution, 24, RenderTextureFormat.Depth);
        shadowRT.filterMode = FilterMode.Bilinear;
        shadowRT.wrapMode = TextureWrapMode.Clamp;

        customLight.shadowMap = shadowRT;
        customLight.castShadows = true;

        GameObject camObj = new GameObject("Shadow Cam Internal");
        camObj.transform.SetParent(transform, false);
        camObj.transform.localRotation = Quaternion.identity;

        shadowCam = camObj.AddComponent<Camera>();
        shadowCam.enabled = false;
        shadowCam.backgroundColor = Color.white;
        shadowCam.clearFlags = CameraClearFlags.SolidColor; // Important for depth
        shadowCam.targetTexture = shadowRT;
        shadowCam.depthTextureMode = DepthTextureMode.Depth;
        shadowCam.cullingMask = ~(1 << LayerMask.NameToLayer("UI"));
    }

    void Update()
    {
        if (shadowCam == null || customLight == null) return;

        // 1. Switch Projection
        if (customLight.type == CustomLight.LightType.Directional)
        {
            shadowCam.orthographic = true;
            shadowCam.orthographicSize = orthoSize;
            shadowCam.nearClipPlane = -50.0f;
            shadowCam.farClipPlane = farPlane;
        }
        else
        {
            shadowCam.orthographic = false;
            shadowCam.fieldOfView = customLight.spotAngle;
            shadowCam.nearClipPlane = nearPlane;
            shadowCam.farClipPlane = farPlane;
        }

        shadowCam.Render();

        // 2. Calculate Matrix (The Critical Fix)
        // We need to map Clip Space to Texture Space (0..1)
        // D3D (Windows) has Clip Z of 0..1 (or 1..0 reversed). OpenGL has -1..1.

        Matrix4x4 scaleOffset = Matrix4x4.identity;

        // Fix XY: Always map -1..1 to 0..1
        scaleOffset.m00 = 0.5f; scaleOffset.m03 = 0.5f;
        scaleOffset.m11 = 0.5f; scaleOffset.m13 = 0.5f;

        // Fix Z: Detect if we need to scale Z (OpenGL) or keep it raw (D3D)
        bool d3d = SystemInfo.graphicsDeviceVersion.IndexOf("Direct3D") > -1;
        if (d3d)
        {
            // D3D: Z is already 0..1 (or 1..0). Don't scale it.
            scaleOffset.m22 = 1.0f;
            scaleOffset.m23 = 0.0f;
        }
        else
        {
            // OpenGL: Z is -1..1. Scale to 0..1.
            scaleOffset.m22 = 0.5f;
            scaleOffset.m23 = 0.5f;
        }

        Matrix4x4 view = shadowCam.worldToCameraMatrix;
        Matrix4x4 proj = GL.GetGPUProjectionMatrix(shadowCam.projectionMatrix, false);
        Matrix4x4 m = scaleOffset * proj * view;

        customLight.viewProjMatrix = m;
        Shader.SetGlobalFloat("_GlobalShadowBias", shadowBias);
    }

    void OnDestroy()
    {
        if (shadowRT) shadowRT.Release();
    }
}