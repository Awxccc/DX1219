using UnityEngine;

public class RotatingScript : MonoBehaviour
{
    public float rotatingSpeed = 20;
    // Start is called once before the first execution of Update after the MonoBehaviour is created
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        transform.Rotate(new Vector3(0, rotatingSpeed,0) * Time.deltaTime);
    }
}
