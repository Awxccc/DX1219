using UnityEngine;

public class DissolveController : MonoBehaviour
{
    [Header("Settings")]
    public Material targetMaterial;
    public string propertyName = "_DissolveAmount";
    public float dissolveSpeed = 0.5f;

    [Header("Trigger Logic")]
    public Transform player;
    public float triggerDistance = 5.0f;
    public bool dissolveOnProximity = true;

    private float _currentVal = 0;
    private bool _isDissolving = false;

    void Start()
    {
        // Create a clone of the material so we don't change the original asset
        if (GetComponent<Renderer>() != null)
        {
            targetMaterial = GetComponent<Renderer>().material;
        }
    }

    void Update()
    {
        if (player == null) return;

        // Check distance to player
        float dist = Vector3.Distance(transform.position, player.position);

        // Logic: If player is close, start dissolving (appearing/disappearing)
        if (dissolveOnProximity)
        {
            _isDissolving = dist < triggerDistance;
        }

        // Smoothly animate the value
        float target = _isDissolving ? 1.0f : 0.0f;
        _currentVal = Mathf.MoveTowards(_currentVal, target, dissolveSpeed * Time.deltaTime);

        // Apply to shader
        if (targetMaterial != null)
        {
            targetMaterial.SetFloat(propertyName, _currentVal);
        }
    }
}