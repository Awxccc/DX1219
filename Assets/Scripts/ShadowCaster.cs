using UnityEngine;
using UnityEngine.Rendering;

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

        // 1. Initialize the Render Texture based on Light Type
        if (customLight.type == CustomLight.LightType.Point)
        {
            // Point lights need a CubeMap (3D Texture)
            shadowRT = new RenderTexture(resolution, resolution, 24);
            shadowRT.dimension = TextureDimension.Cube;
        }
        else
        {
            // Spot and Directional lights use a standard 2D Depth Texture
            shadowRT = new RenderTexture(resolution, resolution, 24, RenderTextureFormat.Depth);
        }

        shadowRT.filterMode = FilterMode.Bilinear;
        shadowRT.wrapMode = TextureWrapMode.Clamp;

        customLight.shadowMap = shadowRT;
        customLight.castShadows = true;

        // 2. Setup the Internal Shadow Camera
        GameObject camObj = new GameObject("Shadow Cam Internal");
        camObj.transform.SetParent(transform, false);
        camObj.transform.localRotation = Quaternion.identity;

        shadowCam = camObj.AddComponent<Camera>();
        shadowCam.enabled = false;
        shadowCam.backgroundColor = Color.white;
        shadowCam.clearFlags = CameraClearFlags.SolidColor;

        // For 2D shadows, we bind the texture here. 
        // For Point (Cubemap), RenderToCubemap handles binding internally.
        if (customLight.type != CustomLight.LightType.Point)
        {
            shadowCam.targetTexture = shadowRT;
        }
        else
        {
            // CRITICAL: Assign the camera to CustomLight ONLY if it's a Point light.
            // This enables CustomLight.Update() to run UpdateShadowMap() -> RenderToCubemap().
            customLight.shadowCamera = shadowCam;
        }

        shadowCam.depthTextureMode = DepthTextureMode.Depth;
        shadowCam.cullingMask = ~(1 << LayerMask.NameToLayer("UI"));
    }

    void Update()
    {
        if (shadowCam == null || customLight == null) return;

        // 3. Point Light Logic
        if (customLight.type == CustomLight.LightType.Point)
        {
            // Ensure camera planes are correct
            shadowCam.nearClipPlane = nearPlane;
            shadowCam.farClipPlane = farPlane;

            // We EXIT EARLY here. 
            // We do NOT want to run the 2D rendering logic below.
            // CustomLight.cs's Update loop will handle the RenderToCubemap call.
            return;
        }

        // --- Standard 2D Shadow Logic (Directional / Spot) ---

        // Switch Projection
        if (customLight.type == CustomLight.LightType.Directional)
        {
            shadowCam.orthographic = true;
            shadowCam.orthographicSize = orthoSize;
            shadowCam.nearClipPlane = -50.0f;
            shadowCam.farClipPlane = farPlane;
        }
        else // Spot Light
        {
            shadowCam.orthographic = false;
            shadowCam.fieldOfView = customLight.spotAngle + 30.0f;
            shadowCam.nearClipPlane = nearPlane;
            shadowCam.farClipPlane = farPlane;
        }

        shadowCam.Render();

        // Calculate View-Projection Matrix for the Shader
        Matrix4x4 scaleOffset = Matrix4x4.identity;

        // Fix XY: Map -1..1 to 0..1
        scaleOffset.m00 = 0.5f; scaleOffset.m03 = 0.5f;
        scaleOffset.m11 = 0.5f; scaleOffset.m13 = 0.5f;

        // Fix Z: Detect Direct3D vs OpenGL ranges
        bool d3d = SystemInfo.graphicsDeviceVersion.IndexOf("Direct3D") > -1;
        if (d3d)
        {
            scaleOffset.m22 = 1.0f;
            scaleOffset.m23 = 0.0f;
        }
        else
        {
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