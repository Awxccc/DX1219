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
    public ClampedFloatParameter intensity = new ClampedFloatParameter(1f, 0f, 1f);
    public bool IsActive() => intensity.value > 0f;
    public bool IsTileCompatible() => true;
}
public class BlackAndWhiteRendererFeature : ScriptableRendererFeature
{
    
    [SerializeField] private Settings settings = new();
    private Material _material;
    private Pass _pass;
}

public override void Create()
{
    if (settings.shader == null)
    {
        settings.shader = Shader.Find("Hidden/Custom/BlackAndWhite");
    }
    if(settings.shader != null)
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
    if(_material == null)
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
    public Pass(Material mat)
    {
        _mat = mat;
    }
}

public void Dispose()
{
}
public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
{
    if(_mat == null)
    {
        return;
    }
}