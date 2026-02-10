using UnityEngine;

public class SanityTrigger : MonoBehaviour
{
    [Header("Settings")]
    [Tooltip("How much sanity to remove instantly when entering")]
    public float shockDamage = 0.2f;

    [Tooltip("If true, sanity drains continuously while inside this zone")]
    public bool continuousDrain = false;

    private SanityController _sanityManager;

    void Start()
    {
        // Find the global manager
        _sanityManager = FindFirstObjectByType<SanityController>();
    }

    void OnTriggerEnter(Collider other)
    {
        if (other.CompareTag("Player") && _sanityManager != null)
        {
            // Instant jump scare damage
            _sanityManager.currentSanity -= shockDamage;
        }
    }

    void OnTriggerStay(Collider other)
    {
        if (continuousDrain && other.CompareTag("Player") && _sanityManager != null)
        {
            // Drain fast while standing in the "scary zone" (e.g. near the Ghost)
            _sanityManager.currentSanity -= Time.deltaTime * 0.1f;
        }
    }
}