using UnityEngine;

[RequireComponent(typeof(CustomLight))]
public class ShadowCaster : MonoBehaviour
{
    public int resolution = 2048;
    public float orthoSize = 20.0f;
    public float nearPlane = 0.1f;
    public float farPlane = 100.0f;
    public float shadowBias = 0.005f;

    private Camera shadowCam;
    private RenderTexture shadowRT;
    private CustomLight customLight;

    void Start()
    {
        customLight = GetComponent<CustomLight>();

        // Setup Render Texture
        shadowRT = new RenderTexture(resolution, resolution, 24, RenderTextureFormat.Depth);
        shadowRT.filterMode = FilterMode.Bilinear; // Important for Soft Shadows
        shadowRT.wrapMode = TextureWrapMode.Clamp;

        customLight.shadowMap = shadowRT;
        customLight.castShadows = true;

        // Setup Hidden Camera
        GameObject camObj = new GameObject("Shadow Cam Internal");
        camObj.transform.SetParent(transform, false);

        shadowCam = camObj.AddComponent<Camera>();
        shadowCam.enabled = false;
        shadowCam.backgroundColor = Color.white;
        shadowCam.clearFlags = CameraClearFlags.SolidColor;
        shadowCam.orthographic = true;
        shadowCam.orthographicSize = orthoSize;
        shadowCam.nearClipPlane = nearPlane;
        shadowCam.farClipPlane = farPlane;
        shadowCam.targetTexture = shadowRT;
    }

    void Update()
    {
        if (shadowCam == null) return;

        // Match Render settings
        shadowCam.orthographicSize = orthoSize;

        // Render the depth map
        shadowCam.Render();

        // Calculate Matrix for Shader: bias * projection * view
        // Scale and Offset to map [-1, 1] clip space to [0, 1] texture space
        Matrix4x4 scaleOffset = Matrix4x4.TRS(
            new Vector3(0.5f, 0.5f, 0.5f),
            Quaternion.identity,
            new Vector3(0.5f, 0.5f, 0.5f)
        );

        Matrix4x4 view = shadowCam.worldToCameraMatrix;
        Matrix4x4 proj = shadowCam.projectionMatrix;
        Matrix4x4 m = scaleOffset * proj * view;

        customLight.viewProjMatrix = m;

        // Send bias globally
        Shader.SetGlobalFloat("_GlobalShadowBias", shadowBias);
    }

    void OnDestroy()
    {
        if (shadowRT) shadowRT.Release();
    }
}