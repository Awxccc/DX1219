using UnityEngine;

public class GhostAI : MonoBehaviour
{
    [Header("Targeting")]
    public Transform player;
    public float stopDistance = 3.0f;

    [Header("Sanity Stats")]
    // Speed when you are sane (Floating/Drifting)
    public float calmSpeed = 2.0f;
    // Speed when you are insane (Aggressive Chase)
    public float insaneSpeed = 8.0f;

    private SanityController _sanityController;

    void Start()
    {
        // Auto-find player if empty
        if (player == null)
        {
            GameObject p = GameObject.FindGameObjectWithTag("Player");
            if (p != null) player = p.transform;
        }

        _sanityController = FindFirstObjectByType<SanityController>();
    }

    void Update()
    {
        if (player == null) return;

        // 1. Calculate Distance
        float dist = Vector3.Distance(transform.position, player.position);

        // 2. Rotate to face the player (3D rotation for flying)
        // We use Slerp for a smoother turn, rather than snapping instantly
        Vector3 direction = (player.position - transform.position).normalized;
        if (direction != Vector3.zero)
        {
            Quaternion lookRotation = Quaternion.LookRotation(direction);
            transform.rotation = Quaternion.Slerp(transform.rotation, lookRotation, Time.deltaTime * 5f);
        }

        // 3. Get Speed from Sanity System (Seamless Integration)
        float currentSanity = 1.0f;
        if (_sanityController != null)
        {
            currentSanity = _sanityController.currentSanity;
        }

        // Lerp: High Sanity = Slow/Calm, Low Sanity = Fast/Insane
        float speed = Mathf.Lerp(insaneSpeed, calmSpeed, currentSanity);

        // 4. Move towards player (Flying)
        if (dist > stopDistance)
        {
            transform.position += transform.forward * speed * Time.deltaTime;
        }
    }
}