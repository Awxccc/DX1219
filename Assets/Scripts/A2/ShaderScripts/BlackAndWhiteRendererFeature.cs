using TMPro;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;
using static UnityEditor.ShaderData;

[System.Serializable]
public class Settings
{
    public RenderPassEvent passEvent = RenderPassEvent.BeforeRenderingPostProcessing;
    public Shader shader;
}

[System.Serializable]
[VolumeComponentMenu("Custom/Black And White")]
public class BlackAndWhiteVolume : VolumeComponent, IPostProcessComponent
{
    public ClampedFloatParameter intensity = new(0f, 0f, 1f);

    public bool IsActive() => intensity.value > 0f;

    public bool IsTileCompatible() => true;
}
public class BlackAndWhiteRendererFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class Settings
    {
        public RenderPassEvent passEvent = RenderPassEvent.BeforeRenderingPostProcessing;
        public Shader shader;
    }

    [SerializeField] private Settings settings = new();
    private Material _material;
    private Pass _pass;

    public override void Create()
    {
        if (settings.shader == null)
        {
            settings.shader = Shader.Find("Hidden/Custom/BlackAndWhite");
        }

        if (settings.shader != null)
        {
            _material = CoreUtils.CreateEngineMaterial(settings.shader);
        }

        _pass = new Pass(_material)
        {
            renderPassEvent = settings.passEvent
        };
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (_material == null)
        {
            return;
        }

        renderer.EnqueuePass(_pass);
    }

    protected override void Dispose(bool disposing)
    {
        _pass?.Dispose();
        CoreUtils.Destroy(_material);
    }

    private sealed class Pass : ScriptableRenderPass
    {
        private readonly Material _mat;

        private class CopyPassData
        {
            public TextureHandle source;
        }

        private class BwPassData
        {
            public TextureHandle source;
            public Material material;
            public float intensity;
        }

        public Pass(Material mat)
        {
            _mat = mat;
        }

        public void Dispose() { }
        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            if (_mat == null)
            {
                return;
            }

            var cameraData = frameData.Get<UniversalCameraData>();
            if (cameraData.isPreviewCamera)
            {
                return;
            }

            var bw = VolumeManager.instance.stack.GetComponent<BlackAndWhiteVolume>();
            if (bw == null || !bw.IsActive())
            {
                return;
            }

            float intensity = bw.intensity.value;

            var resources = frameData.Get<UniversalResourceData>();
            if (resources.isActiveTargetBackBuffer)
            {
                return;
            }

            TextureHandle target = resources.activeColorTexture;
            if (!target.IsValid())
            {
                return;
            }

            var desc = renderGraph.GetTextureDesc(target);
            desc.clearBuffer = false;
            desc.name = "BW_TempCopy";

            TextureHandle tempCopy = renderGraph.CreateTexture(desc);

            using (var builder = renderGraph.AddRasterRenderPass<CopyPassData>("BW Copy", out var passData))
            {
                builder.UseTexture(target, AccessFlags.Read);
                builder.SetRenderAttachment(tempCopy, 0);
                passData.source = target;

                builder.SetRenderFunc((CopyPassData data, RasterGraphContext ctx) =>
                {
                    Blitter.BlitTexture(ctx.cmd, data.source, new Vector4(1f, 1f, 0f, 0f), 0f, false);
                });
            }

            using (var builder = renderGraph.AddRasterRenderPass<BwPassData>("BW Apply", out var passData))
            {
                builder.UseTexture(tempCopy, AccessFlags.Read);
                builder.SetRenderAttachment(target, 0);
                passData.source = tempCopy;
                passData.material = _mat;
                passData.intensity = intensity;

                builder.SetRenderFunc((BwPassData data, RasterGraphContext ctx) =>
                {
                    data.material.SetFloat("_Intensity", data.intensity);
                    Blitter.BlitTexture(ctx.cmd, data.source, new Vector4(1f, 1f, 0f, 0f), data.material, 0);
                });
            }
        }
    }
}

