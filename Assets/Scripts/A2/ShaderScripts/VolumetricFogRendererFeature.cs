using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;

[System.Serializable]
[VolumeComponentMenu("Custom/Volumetric Fog Global")]
public class VolumetricFogVolume : VolumeComponent, IPostProcessComponent
{
    public ClampedFloatParameter intensity = new ClampedFloatParameter(0f, 0f, 5f);
    public ColorParameter fogColor = new ColorParameter(Color.gray);
    public ColorParameter insanityColor = new ColorParameter(Color.red);
    public ClampedFloatParameter density = new ClampedFloatParameter(0.5f, 0f, 2f);
    public FloatParameter noiseScale = new FloatParameter(0.1f);
    public FloatParameter speed = new FloatParameter(0.5f);
    public FloatParameter baseHeight = new FloatParameter(0.0f);
    public ClampedFloatParameter heightFalloff = new ClampedFloatParameter(0.5f, 0.01f, 2f);
    public FloatParameter maxDistance = new FloatParameter(100f);

    public bool IsActive() => intensity.value > 0f;
    public bool IsTileCompatible() => true;
}

public class VolumetricFogRendererFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class Settings
    {
        public RenderPassEvent passEvent = RenderPassEvent.BeforeRenderingPostProcessing;
        public Shader shader;
    }

    [SerializeField] private Settings settings = new Settings();
    private Material _material;
    private VolumetricFogPass _pass;

    public override void Create()
    {
        if (settings.shader == null) settings.shader = Shader.Find("Hidden/Custom/VolumetricFogGlobal");
        if (settings.shader != null) _material = CoreUtils.CreateEngineMaterial(settings.shader);

        _pass = new VolumetricFogPass(_material)
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

    private sealed class VolumetricFogPass : ScriptableRenderPass
    {
        private Material _mat;

        private class PassData
        {
            public TextureHandle source;
            public Material material;
            public float intensity;
            public Color fogColor;
            public Color insanityColor;
            public float density;
            public float noiseScale;
            public float speed;
            public float baseHeight;
            public float heightFalloff;
            public float maxDistance;
        }

        public VolumetricFogPass(Material mat)
        {
            _mat = mat;
        }

        public void Dispose() { }

        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            var stack = VolumeManager.instance.stack;
            var vol = stack.GetComponent<VolumetricFogVolume>();
            if (vol == null || !vol.IsActive()) return;

            var resources = frameData.Get<UniversalResourceData>();
            TextureHandle source = resources.activeColorTexture;
            if (!source.IsValid()) return;

            var desc = renderGraph.GetTextureDesc(source);
            desc.name = "VolumetricFog_Temp";
            desc.clearBuffer = false;
            TextureHandle tempTex = renderGraph.CreateTexture(desc);

            using (var builder = renderGraph.AddRasterRenderPass<PassData>("Volumetric Fog Pass", out var passData))
            {
                builder.UseTexture(source, AccessFlags.Read);
                builder.SetRenderAttachment(tempTex, 0);

                passData.source = source;
                passData.material = _mat;
                passData.intensity = vol.intensity.value;
                passData.fogColor = vol.fogColor.value;
                passData.insanityColor = vol.insanityColor.value;
                passData.density = vol.density.value;
                passData.noiseScale = vol.noiseScale.value;
                passData.speed = vol.speed.value;
                passData.baseHeight = vol.baseHeight.value;
                passData.heightFalloff = vol.heightFalloff.value;
                passData.maxDistance = vol.maxDistance.value;

                builder.SetRenderFunc((PassData data, RasterGraphContext ctx) =>
                {
                    data.material.SetFloat("_Intensity", data.intensity);
                    data.material.SetColor("_FogColor", data.fogColor);
                    data.material.SetColor("_InsanityColor", data.insanityColor);
                    data.material.SetFloat("_FogDensity", data.density);
                    data.material.SetFloat("_NoiseScale", data.noiseScale);
                    data.material.SetFloat("_Speed", data.speed);
                    data.material.SetFloat("_BaseHeight", data.baseHeight);
                    data.material.SetFloat("_HeightFalloff", data.heightFalloff);
                    data.material.SetFloat("_MaxDistance", data.maxDistance);

                    Blitter.BlitTexture(ctx.cmd, data.source, new Vector4(1, 1, 0, 0), data.material, 0);
                });
            }

            using (var builder = renderGraph.AddRasterRenderPass<PassData>("Fog Copy Back", out var passData))
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