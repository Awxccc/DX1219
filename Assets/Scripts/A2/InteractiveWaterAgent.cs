using UnityEngine;

[ExecuteAlways] // Runs in editor so you can test without playing!
public class InteractiveWaterAgent : MonoBehaviour
{
    public Transform player;
    public Material waterMaterial;

    void Update()
    {
        if (waterMaterial != null && player != null)
        {
            waterMaterial.SetVector("_PlayerPosition", player.position);
        }
    }
}