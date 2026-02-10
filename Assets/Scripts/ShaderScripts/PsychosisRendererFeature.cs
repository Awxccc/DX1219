using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;

[System.Serializable]
[VolumeComponentMenu("Custom/Horror Psychosis")]
public class PsychosisVolume : VolumeComponent, IPostProcessComponent
{
    public ClampedFloatParameter insanityLevel = new ClampedFloatParameter(0f, 0f, 1f);
    public ClampedFloatParameter grainAmount = new ClampedFloatParameter(0.5f, 0f, 1f);
    public ClampedFloatParameter vignettePower = new ClampedFloatParameter(0.5f, 0f, 1f);
    public ClampedFloatParameter aberrationAmount = new ClampedFloatParameter(0.5f, 0f, 1f);

    public bool IsActive() => insanityLevel.value > 0f;
    public bool IsTileCompatible() => true;
}

public class PsychosisRendererFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class Settings
    {
        public RenderPassEvent passEvent = RenderPassEvent.BeforeRenderingPostProcessing;
        public Shader shader;
    }

    [SerializeField] private Settings settings = new Settings();
    private Material _material;
    private PsychosisPass _pass;

    public override void Create()
    {
        if (settings.shader == null) settings.shader = Shader.Find("Hidden/Custom/Psychosis");
        if (settings.shader != null) _material = CoreUtils.CreateEngineMaterial(settings.shader);
        
        _pass = new PsychosisPass(_material)
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

    private sealed class PsychosisPass : ScriptableRenderPass
    {
        private Material _mat;
        
        private class PassData
        {
            public TextureHandle source;
            public Material material;
            public float intensity;
            public float grain;
            public float vignette;
            public float aberration;
        }

        public PsychosisPass(Material mat)
        {
            _mat = mat;
        }

        public void Dispose() { }

        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            var stack = VolumeManager.instance.stack;
            var vol = stack.GetComponent<PsychosisVolume>();
            if (vol == null || !vol.IsActive()) return;

            var resources = frameData.Get<UniversalResourceData>();
            TextureHandle source = resources.activeColorTexture;
            if (!source.IsValid()) return;

            var desc = renderGraph.GetTextureDesc(source);
            desc.name = "Psychosis_Temp";
            desc.clearBuffer = false;
            TextureHandle tempTex = renderGraph.CreateTexture(desc);

            using (var builder = renderGraph.AddRasterRenderPass<PassData>("Psychosis Pass", out var passData))
            {
                builder.UseTexture(source, AccessFlags.Read);
                builder.SetRenderAttachment(tempTex, 0);
                
                passData.source = source;
                passData.material = _mat;
                passData.intensity = vol.insanityLevel.value;
                passData.grain = vol.grainAmount.value;
                passData.vignette = vol.vignettePower.value;
                passData.aberration = vol.aberrationAmount.value;

                builder.SetRenderFunc((PassData data, RasterGraphContext ctx) =>
                {
                    data.material.SetFloat("_Intensity", data.intensity);
                    data.material.SetFloat("_GrainStrength", data.grain);
                    data.material.SetFloat("_VignetteStrength", data.vignette);
                    data.material.SetFloat("_AberrationStrength", data.aberration);
                    Blitter.BlitTexture(ctx.cmd, data.source, new Vector4(1, 1, 0, 0), data.material, 0);
                });
            }

            using (var builder = renderGraph.AddRasterRenderPass<PassData>("Psychosis Copy Back", out var passData))
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