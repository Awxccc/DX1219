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

        moveAction = playerInput.actions["Move"];
        lookAction = playerInput.actions["Look"];
    }

    void Update()
    {
        if (lookAction != null)
        {
            Vector2 look = lookAction.ReadValue<Vector2>();
            rotationX += look.x * lookSpeed * Time.deltaTime;
            rotationY -= look.y * lookSpeed * Time.deltaTime;
            rotationY = Mathf.Clamp(rotationY, -90f, 90f);
            transform.rotation = Quaternion.Euler(rotationY, rotationX, 0);
        }

        if (moveAction != null)
        {
            Vector2 move = moveAction.ReadValue<Vector2>();
            Vector3 direction = (transform.forward * move.y + transform.right * move.x).normalized;

            float speed = moveSpeed * (Keyboard.current != null && Keyboard.current.leftShiftKey.isPressed ? sprintMultiplier : 1f);

            transform.position += speed * Time.deltaTime * direction;
        }
    }
}