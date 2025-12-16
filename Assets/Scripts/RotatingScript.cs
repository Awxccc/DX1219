using UnityEngine;

public class RotatingScript : MonoBehaviour
{
    public float rotatingSpeed = 20;

    // Update is called once per frame
    void Update()
    {
        transform.Rotate(new Vector3(0, rotatingSpeed, 0) * Time.deltaTime);
    }
}
