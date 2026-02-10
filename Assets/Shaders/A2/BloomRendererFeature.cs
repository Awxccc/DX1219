using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;

public class BloomRendererFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class Settings
    {
        public RenderPassEvent passEvent = RenderPassEvent.BeforeRenderingPostProcessing;
        public Shader bloomShader;
        public Shader blurShader;
    }
    [System.Serializable]
    [VolumeComponentMenu("Custom/Simple Bloom")]
    public class BloomVolume : VolumeComponent, IPostProcessComponent
    {
        public ClampedFloatParameter threshold = new ClampedFloatParameter(0.9f, 0f, 2f);
        public ClampedFloatParameter intensity = new ClampedFloatParameter(1f, 0f, 5f);
        public ClampedIntParameter blurRadius = new ClampedIntParameter(5, 1, 10);
        public ClampedIntParameter downsample = new ClampedIntParameter(2, 1, 4);

        public bool IsActive() => intensity.value > 0f;

        public bool IsTileCompatible() => true;
    }

    [SerializeField] private Settings settings = new Settings();
    private Material _bloomMaterial;
    private Material _blurMaterial;
    private BloomPass _pass;

    public override void Create()
    {
        if (settings.bloomShader == null) settings.bloomShader = Shader.Find("Hidden/Custom/Bloom");
        if (settings.blurShader == null) settings.blurShader = Shader.Find("Hidden/Custom/GaussianBlur");

        if (settings.bloomShader != null && settings.blurShader != null)
        {
            _bloomMaterial = CoreUtils.CreateEngineMaterial(settings.bloomShader);
            _blurMaterial = CoreUtils.CreateEngineMaterial(settings.blurShader);
            _pass = new BloomPass(_bloomMaterial, _blurMaterial, settings.passEvent);
        }
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (_bloomMaterial != null && _blurMaterial != null)
            renderer.EnqueuePass(_pass);
    }

    protected override void Dispose(bool disposing)
    {
        _pass?.Dispose();
        CoreUtils.Destroy(_bloomMaterial);
        CoreUtils.Destroy(_blurMaterial);
    }

    private sealed class BloomPass : ScriptableRenderPass
    {
        private Material _bloomMat;
        private Material _blurMat;

        private class PassData
        {
            public TextureHandle source;
            public TextureHandle dest;
            public Material material;
            public int passIndex;
        }

        // Setup for Gaussian parameters
        private static readonly int IntensityID = Shader.PropertyToID("_Intensity");
        private static readonly int RadiusID = Shader.PropertyToID("_Radius");
        private static readonly int DirectionID = Shader.PropertyToID("_Direction");
        private static readonly int TexelSizeID = Shader.PropertyToID("_TexelSize");
        private static readonly int ThresholdID = Shader.PropertyToID("_Threshold");

        public BloomPass(Material bloom, Material blur, RenderPassEvent evt)
        {
            _bloomMat = bloom;
            _blurMat = blur;
            renderPassEvent = evt;
        }

        public void Dispose() { }

        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            var volume = VolumeManager.instance.stack.GetComponent<BloomVolume>();
            if (volume == null || !volume.IsActive()) return;

            var resources = frameData.Get<UniversalResourceData>();
            TextureHandle cameraColor = resources.activeColorTexture;
            if (!cameraColor.IsValid()) return;

            var desc = renderGraph.GetTextureDesc(cameraColor);
            desc.width = Mathf.Max(1, desc.width / volume.downsample.value);
            desc.height = Mathf.Max(1, desc.height / volume.downsample.value);
            desc.clearBuffer = false;
            desc.name = "Bloom_Threshold";

            TextureHandle thresholdTex = renderGraph.CreateTexture(desc);
            TextureHandle tempH = renderGraph.CreateTexture(desc);
            TextureHandle tempV = renderGraph.CreateTexture(desc);

            // 1. Threshold Pass
            using (var builder = renderGraph.AddRasterRenderPass<PassData>("Bloom Threshold", out var data))
            {
                builder.UseTexture(cameraColor, AccessFlags.Read);
                builder.SetRenderAttachment(thresholdTex, 0);
                data.source = cameraColor;
                data.material = _bloomMat;

                builder.SetRenderFunc((PassData d, RasterGraphContext ctx) =>
                {
                    d.material.SetFloat(ThresholdID, volume.threshold.value);
                    Blitter.BlitTexture(ctx.cmd, d.source, new Vector4(1, 1, 0, 0), d.material, 0);
                });
            }

            // 2. Blur Passes (Reusing Gaussian Shader Logic)
            Vector2 texelSize = new Vector2(1f / desc.width, 1f / desc.height);

            // Horizontal
            using (var builder = renderGraph.AddRasterRenderPass<PassData>("Bloom Blur H", out var data))
            {
                builder.UseTexture(thresholdTex, AccessFlags.Read);
                builder.SetRenderAttachment(tempH, 0);
                data.source = thresholdTex;
                data.material = _blurMat;

                builder.SetRenderFunc((PassData d, RasterGraphContext ctx) =>
                {
                    d.material.SetFloat(IntensityID, 1f); // Blur full intensity for bloom
                    d.material.SetFloat(RadiusID, volume.blurRadius.value);
                    d.material.SetVector(DirectionID, new Vector4(1, 0, 0, 0));
                    d.material.SetVector(TexelSizeID, new Vector4(texelSize.x, texelSize.y, 0, 0));
                    Blitter.BlitTexture(ctx.cmd, d.source, new Vector4(1, 1, 0, 0), d.material, 0);
                });
            }

            // Vertical
            using (var builder = renderGraph.AddRasterRenderPass<PassData>("Bloom Blur V", out var data))
            {
                builder.UseTexture(tempH, AccessFlags.Read);
                builder.SetRenderAttachment(tempV, 0);
                data.source = tempH;
                data.material = _blurMat;

                builder.SetRenderFunc((PassData d, RasterGraphContext ctx) =>
                {
                    d.material.SetFloat(IntensityID, 1f);
                    d.material.SetFloat(RadiusID, volume.blurRadius.value);
                    d.material.SetVector(DirectionID, new Vector4(0, 1, 0, 0));
                    d.material.SetVector(TexelSizeID, new Vector4(texelSize.x, texelSize.y, 0, 0));
                    Blitter.BlitTexture(ctx.cmd, d.source, new Vector4(1, 1, 0, 0), d.material, 0);
                });
            }

            // 3. Combine Pass
            using (var builder = renderGraph.AddRasterRenderPass<PassData>("Bloom Combine", out var data))
            {
                builder.UseTexture(cameraColor, AccessFlags.Read); // Read original
                builder.UseTexture(tempV, AccessFlags.Read);      // Read blurred bloom
                builder.SetRenderAttachment(cameraColor, 0);      // Write back to camera
                data.source = cameraColor; // Helper to store one, pass other via material
                data.dest = tempV;         // Passing blurred texture as "BlitTexture" usually
                data.material = _bloomMat;

                builder.SetRenderFunc((PassData d, RasterGraphContext ctx) =>
                {
                    d.material.SetFloat(IntensityID, volume.intensity.value);
                    d.material.SetTexture("_SourceTexture", d.source); // Set original texture manually if needed
                    // Blitter uses data.dest as _BlitTexture (the MainTex)
                    Blitter.BlitTexture(ctx.cmd, d.dest, new Vector4(1, 1, 0, 0), d.material, 1);
                });
            }
        }
    }
}