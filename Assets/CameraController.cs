using UnityEngine;

[RequireComponent(typeof(Camera))]
public class CameraController : MonoBehaviour
{
    [Header("Movement Settings")]
    [SerializeField] private float moveSpeed = 10f;
    [SerializeField] private float fastMoveSpeed = 30f;
    [SerializeField] private float mouseSensitivity = 2f;
    [SerializeField] private float smoothTime = 0.1f;
    
    [Header("Control Settings")]
    [SerializeField] private bool enableMouseLook = true;
    [SerializeField] private bool invertY = false;
    
    [Header("Constraints")]
    [SerializeField] private float maxLookAngle = 90f;
    
    private Vector3 velocity = Vector3.zero;
    private Vector3 smoothVelocity = Vector3.zero;
    private float rotationX = 0f;
    private float rotationY = 0f;
    private bool isControlling = false;
    
    void Start()
    {
        // Initialize rotation based on current transform
        Vector3 rotation = transform.eulerAngles;
        rotationX = rotation.x;
        rotationY = rotation.y;
    }
    
    void Update()
    {
        HandleInput();
        
        if (isControlling)
        {
            HandleMouseLook();
            HandleMovement();
        }
    }
    
    void HandleInput()
    {
        // Toggle camera control with Right Mouse Button
        if (Input.GetMouseButtonDown(1))
        {
            isControlling = true;
            Cursor.lockState = CursorLockMode.Locked;
            Cursor.visible = false;
        }
        else if (Input.GetMouseButtonUp(1))
        {
            isControlling = false;
            Cursor.lockState = CursorLockMode.None;
            Cursor.visible = true;
        }
        
        // Alternative: Toggle with Tab key
        if (Input.GetKeyDown(KeyCode.Tab))
        {
            isControlling = !isControlling;
            
            if (isControlling)
            {
                Cursor.lockState = CursorLockMode.Locked;
                Cursor.visible = false;
            }
            else
            {
                Cursor.lockState = CursorLockMode.None;
                Cursor.visible = true;
            }
        }
    }
    
    void HandleMouseLook()
    {
        if (!enableMouseLook) return;
        
        float mouseX = Input.GetAxis("Mouse X") * mouseSensitivity;
        float mouseY = Input.GetAxis("Mouse Y") * mouseSensitivity;
        
        rotationY += mouseX;
        rotationX -= mouseY * (invertY ? -1 : 1);
        
        // Clamp vertical rotation
        rotationX = Mathf.Clamp(rotationX, -maxLookAngle, maxLookAngle);
        
        // Apply rotation
        transform.rotation = Quaternion.Euler(rotationX, rotationY, 0);
    }
    
    void HandleMovement()
    {
        // Get input
        float horizontal = Input.GetAxis("Horizontal");
        float vertical = Input.GetAxis("Vertical");
        float upDown = 0f;
        
        if (Input.GetKey(KeyCode.E)) upDown = 1f;
        if (Input.GetKey(KeyCode.Q)) upDown = -1f;
        
        // Calculate movement direction
        Vector3 direction = new Vector3(horizontal, upDown, vertical);
        direction = transform.TransformDirection(direction);
        
        // Apply speed modifier
        float currentSpeed = Input.GetKey(KeyCode.LeftShift) ? fastMoveSpeed : moveSpeed;
        
        // Calculate desired velocity
        Vector3 targetVelocity = direction * currentSpeed;
        
        // Smooth movement
        velocity = Vector3.SmoothDamp(velocity, targetVelocity, ref smoothVelocity, smoothTime);
        
        // Apply movement
        transform.position += velocity * Time.deltaTime;
    }
    
    // Public methods for external control
    public void SetPosition(Vector3 position)
    {
        transform.position = position;
    }
    
    public void LookAt(Vector3 target)
    {
        transform.LookAt(target);
        Vector3 rotation = transform.eulerAngles;
        rotationX = rotation.x;
        rotationY = rotation.y;
    }
    
    public void ResetCamera()
    {
        transform.position = new Vector3(0, 0, -25);
        transform.rotation = Quaternion.identity;
        rotationX = 0;
        rotationY = 0;
    }
    
    void OnGUI()
    {
        // Position UI elements to avoid overlap with audio debug
        int yOffset = 200;
        
        if (!isControlling)
        {
            GUI.Box(new Rect(Screen.width / 2 - 150, yOffset, 300, 25), "Hold Right Mouse or press Tab to control camera");
        }
        else
        {
            GUI.Box(new Rect(Screen.width - 260, 10, 250, 90), "Camera Controls");
            GUILayout.BeginArea(new Rect(Screen.width - 250, 35, 230, 65));
            GUILayout.Label("WASD/Arrows: Move");
            GUILayout.Label("Mouse: Look around");
            GUILayout.Label("Q/E: Move down/up");
            GUILayout.Label("Shift: Move faster");
            GUILayout.EndArea();
        }
    }
}