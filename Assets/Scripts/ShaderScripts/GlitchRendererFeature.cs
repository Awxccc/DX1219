using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;

[System.Serializable]
[VolumeComponentMenu("Custom/Horror Glitch")]
public class GlitchVolume : VolumeComponent, IPostProcessComponent
{
    public ClampedFloatParameter intensity = new ClampedFloatParameter(0f, 0f, 1f);
    public ClampedFloatParameter scanlines = new ClampedFloatParameter(0.5f, 0f, 1f);
    public FloatParameter noiseScale = new FloatParameter(10f);

    public bool IsActive() => intensity.value > 0f;
    public bool IsTileCompatible() => true;
}

public class GlitchRendererFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class Settings
    {
        public RenderPassEvent passEvent = RenderPassEvent.BeforeRenderingPostProcessing;
        public Shader shader;
    }

    [SerializeField] private Settings settings = new Settings();
    private Material _material;
    private GlitchPass _pass;

    public override void Create()
    {
        if (settings.shader == null) settings.shader = Shader.Find("Hidden/Custom/Glitch");
        if (settings.shader != null) _material = CoreUtils.CreateEngineMaterial(settings.shader);

        _pass = new GlitchPass(_material)
        {
            renderPassEvent = settings.passEvent
        };
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (_material != null) renderer.EnqueuePass(_pass);
    }

    protected override void Dispose(bool disposing)
    {
        _pass?.Dispose();
        CoreUtils.Destroy(_material);
    }

    private sealed class GlitchPass : ScriptableRenderPass
    {
        private Material _mat;

        private class PassData
        {
            public TextureHandle source;
            public Material material;
            public float intensity;
            public float scanlines;
            public float noiseScale;
        }

        public GlitchPass(Material mat)
        {
            _mat = mat;
        }

        public void Dispose() { }

        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            var stack = VolumeManager.instance.stack;
            var vol = stack.GetComponent<GlitchVolume>();
            if (vol == null || !vol.IsActive()) return;

            var resources = frameData.Get<UniversalResourceData>();
            TextureHandle source = resources.activeColorTexture;
            if (!source.IsValid()) return;

            var desc = renderGraph.GetTextureDesc(source);
            desc.name = "Glitch_Temp";
            desc.clearBuffer = false;
            TextureHandle tempTex = renderGraph.CreateTexture(desc);

            using (var builder = renderGraph.AddRasterRenderPass<PassData>("Glitch Pass", out var passData))
            {
                builder.UseTexture(source, AccessFlags.Read);
                builder.SetRenderAttachment(tempTex, 0);

                passData.source = source;
                passData.material = _mat;
                passData.intensity = vol.intensity.value;
                passData.scanlines = vol.scanlines.value;
                passData.noiseScale = vol.noiseScale.value;

                builder.SetRenderFunc((PassData data, RasterGraphContext ctx) =>
                {
                    data.material.SetFloat("_Intensity", data.intensity);
                    data.material.SetFloat("_ScanlineStrength", data.scanlines);
                    data.material.SetFloat("_NoiseScale", data.noiseScale);

                    // Automatically binds data.source to _BlitTexture
                    Blitter.BlitTexture(ctx.cmd, data.source, new Vector4(1, 1, 0, 0), data.material, 0);
                });
            }

            using (var builder = renderGraph.AddRasterRenderPass<PassData>("Glitch Copy Back", out var passData))
            {
                builder.UseTexture(tempTex, AccessFlags.Read);
                builder.SetRenderAttachment(source, 0);
                passData.source = tempTex;

                builder.SetRenderFunc((PassData data, RasterGraphContext ctx) =>
                {
                    Blitter.BlitTexture(ctx.cmd, data.source, new Vector4(1, 1, 0, 0), 0, false);
                });
            }
        }
    }
}