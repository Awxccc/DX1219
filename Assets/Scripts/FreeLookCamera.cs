using UnityEngine;
using UnityEngine.InputSystem;

[RequireComponent(typeof(PlayerInput))]
public class FreeLookCamera : MonoBehaviour
{
    public float moveSpeed = 10f;
    public float lookSpeed = 15f;
    public float sprintMultiplier = 2f;

    private PlayerInput playerInput;
    private InputAction moveAction;
    private InputAction lookAction;

    private float rotationX = 0f;
    private float rotationY = 0f;

    private void Awake()
    {
        playerInput = GetComponent<PlayerInput>();
        Cursor.lockState = CursorLockMode.Locked;
        Cursor.visible = false;

        // Cache actions for use in Update
        moveAction = playerInput.actions["Move"];
        lookAction = playerInput.actions["Look"];
    }

    void Update()
    {
        // 1. Rotation Logic
        if (lookAction != null)
        {
            Vector2 look = lookAction.ReadValue<Vector2>();
            rotationX += look.x * lookSpeed * Time.deltaTime;
            rotationY -= look.y * lookSpeed * Time.deltaTime;
            rotationY = Mathf.Clamp(rotationY, -90f, 90f);
            transform.rotation = Quaternion.Euler(rotationY, rotationX, 0);
        }

        // 2. Movement Logic
        if (moveAction != null)
        {
            Vector2 move = moveAction.ReadValue<Vector2>();
            Vector3 direction = (transform.forward * move.y + transform.right * move.x).normalized;

            // Check Shift key explicitly or use a "Sprint" action if you added one
            float speed = moveSpeed * (Keyboard.current != null && Keyboard.current.leftShiftKey.isPressed ? sprintMultiplier : 1f);

            transform.position += direction * speed * Time.deltaTime;
        }
    }
}