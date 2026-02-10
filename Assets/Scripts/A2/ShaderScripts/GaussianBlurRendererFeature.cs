using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;

public class GaussianBlurRendererFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class Settings
    {
        public RenderPassEvent passEvent = RenderPassEvent.BeforeRenderingPostProcessing;
        public Shader shader;
        public bool onlyBaseCamera = true;
    }
    [System.Serializable]
    [VolumeComponentMenu("Custom/Gaussian Blur")]
    public class GaussianBlurVolume : VolumeComponent, IPostProcessComponent
    {
        public ClampedFloatParameter intensity = new ClampedFloatParameter(0f, 0f, 1f);
        public ClampedIntParameter radius = new ClampedIntParameter(3, 0, 16);
        public ClampedIntParameter downsample = new ClampedIntParameter(2, 1, 4);

        public bool IsActive() => intensity.value > 0f && radius.value > 0;

        public bool IsTileCompatible() => true;
    }

    [SerializeField] private Settings settings = new Settings();
    private Material _materialH;
    private Material _materialV;
    private Pass _pass;

    public override void Create()
    {
        if (settings.shader == null)
            settings.shader = Shader.Find("Hidden/Custom/GaussianBlur");

        if (settings.shader == null)
            return;

        _materialH = CoreUtils.CreateEngineMaterial(settings.shader);
        _materialV = CoreUtils.CreateEngineMaterial(settings.shader);

        _pass = new Pass(_materialH, _materialV, settings.onlyBaseCamera)
        {
            renderPassEvent = settings.passEvent
        };
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (_materialH == null || _materialV == null)
            return;

        renderer.EnqueuePass(_pass);
    }

    protected override void Dispose(bool disposing)
    {
        _pass?.Dispose();
        CoreUtils.Destroy(_materialH);
        CoreUtils.Destroy(_materialV);
    }

    private sealed class Pass : ScriptableRenderPass
    {
        private static readonly int IntensityID = Shader.PropertyToID("_Intensity");
        private static readonly int DirectionID = Shader.PropertyToID("_Direction");
        private static readonly int TexelSizeID = Shader.PropertyToID("_TexelSize");
        private static readonly int RadiusID = Shader.PropertyToID("_Radius");

        private readonly Material _matH;
        private readonly Material _matV;
        private readonly bool _onlyBaseCamera;

        private class DownPassData
        {
            public TextureHandle source;
        }

        private class BlurPassData
        {
            public TextureHandle source;
            public Material material;
            public float intensity;
            public float radius;
            public Vector2 direction;
            public Vector2 texelSize;
        }

        public Pass(Material matH, Material matV, bool onlyBaseCamera)
        {
            _matH = matH;
            _matV = matV;
            _onlyBaseCamera = onlyBaseCamera;
        }

        public void Dispose() { }

        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            if (_matH == null || _matV == null)
                return;

            var cameraData = frameData.Get<UniversalCameraData>();

            if (cameraData.isPreviewCamera)
                return;

            if (_onlyBaseCamera && cameraData.renderType != CameraRenderType.Base)
                return;

            var vol = VolumeManager.instance.stack.GetComponent<GaussianBlurVolume>();
            if (vol == null || !vol.IsActive())
                return;

            float intensity = vol.intensity.value;
            int radius = vol.radius.value;
            int downsample = Mathf.Max(1, vol.downsample.value);

            var resources = frameData.Get<UniversalResourceData>();
            if (resources.isActiveTargetBackBuffer)
                return;

            TextureHandle source = resources.activeColorTexture;
            if (!source.IsValid())
                return;

            var downDesc = renderGraph.GetTextureDesc(source);
            downDesc.clearBuffer = false;
            downDesc.width = Mathf.Max(1, downDesc.width / downsample);
            downDesc.height = Mathf.Max(1, downDesc.height / downsample);
            downDesc.name = "GaussianBlur_Downsample";

            TextureHandle downTex = renderGraph.CreateTexture(downDesc);

            downDesc.name = "GaussianBlur_TempH";
            TextureHandle tempH = renderGraph.CreateTexture(downDesc);

            downDesc.name = "GaussianBlur_TempV";
            TextureHandle tempV = renderGraph.CreateTexture(downDesc);

            Vector2 texelSize = new Vector2(1f / downDesc.width, 1f / downDesc.height);

            // PASS 1: Downsample
            using (var builder = renderGraph.AddRasterRenderPass<DownPassData>("Blur Downsample", out var passData))
            {
                builder.UseTexture(source, AccessFlags.Read);
                builder.SetRenderAttachment(downTex, 0);
                passData.source = source;

                builder.SetRenderFunc((DownPassData data, RasterGraphContext ctx) =>
                {
                    Blitter.BlitTexture(ctx.cmd, data.source, new Vector4(1f, 1f, 0f, 0f), 0f, false);
                });
            }

            // PASS 2: Horizontal
            using (var builder = renderGraph.AddRasterRenderPass<BlurPassData>("Blur Horizontal", out var passData))
            {
                builder.UseTexture(downTex, AccessFlags.Read);
                builder.SetRenderAttachment(tempH, 0);
                passData.source = downTex;
                passData.material = _matH;
                passData.intensity = intensity;
                passData.radius = radius;
                passData.direction = new Vector2(1f, 0f);
                passData.texelSize = texelSize;

                builder.SetRenderFunc((BlurPassData data, RasterGraphContext ctx) =>
                {
                    data.material.SetFloat(IntensityID, data.intensity);
                    data.material.SetFloat(RadiusID, data.radius);
                    data.material.SetVector(DirectionID, new Vector4(data.direction.x, data.direction.y, 0f, 0f));
                    data.material.SetVector(TexelSizeID, new Vector4(data.texelSize.x, data.texelSize.y, 0f, 0f));

                    Blitter.BlitTexture(ctx.cmd, data.source, new Vector4(1f, 1f, 0f, 0f), data.material, 0);
                });
            }

            // PASS 3: Vertical
            using (var builder = renderGraph.AddRasterRenderPass<BlurPassData>("Blur Vertical", out var passData))
            {
                builder.UseTexture(tempH, AccessFlags.Read);
                builder.SetRenderAttachment(tempV, 0);
                passData.source = tempH;
                passData.material = _matV;
                passData.intensity = intensity;
                passData.radius = radius;
                passData.direction = new Vector2(0f, 1f);
                passData.texelSize = texelSize;

                builder.SetRenderFunc((BlurPassData data, RasterGraphContext ctx) =>
                {
                    data.material.SetFloat(IntensityID, data.intensity);
                    data.material.SetFloat(RadiusID, data.radius);
                    data.material.SetVector(DirectionID, new Vector4(data.direction.x, data.direction.y, 0f, 0f));
                    data.material.SetVector(TexelSizeID, new Vector4(data.texelSize.x, data.texelSize.y, 0f, 0f));

                    Blitter.BlitTexture(ctx.cmd, data.source, new Vector4(1f, 1f, 0f, 0f), data.material, 0);
                });
            }

            resources.cameraColor = tempV;
        }
    }
}