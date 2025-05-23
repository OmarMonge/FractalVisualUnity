using UnityEngine;

[ExecuteInEditMode, RequireComponent(typeof(Camera))]
public class DebugRaymarching : MonoBehaviour
{
    [Header("Materials")]
    [SerializeField] private Material raymarchMaterial;
    
    [Header("Debug Options")]
    [SerializeField] private bool enableDebugMode = true;
    [SerializeField] private bool testAudioValues = true;
    [SerializeField] private Vector4 manualAudioValues = new Vector4(0.3f, 0.5f, 0.7f, 0.4f);
    
    [Header("Audio Testing")]
    [SerializeField] private AudioSource audioSource;
    [SerializeField] private bool forcePlayAudio = true;
    
    [Header("Camera Positioning")]
    [SerializeField] private bool fixedCameraPosition = true;
    [SerializeField] private Vector3 fixedPosition = new Vector3(0, 0, -25);
    [SerializeField] private Vector3 lookAtTarget = Vector3.zero;
    
    private Camera cam;
    
    void Start()
    {
        cam = GetComponent<Camera>();
        
        if (enableDebugMode)
        {
            Debug.Log("=== RAYMARCHING DEBUG MODE ===");
            DebugAudioSetup();
            DebugCameraSetup();
        }
        
        // Force audio to play if requested
        if (forcePlayAudio && audioSource != null)
        {
            audioSource.Stop();
            audioSource.Play();
            Debug.Log("Forced audio to play: " + audioSource.isPlaying);
        }
    }
    
    void Update()
    {
        if (enableDebugMode)
        {
            UpdateDebugInfo();
        }
        
        // Fixed camera position for debugging
        if (fixedCameraPosition)
        {
            transform.position = fixedPosition;
            transform.LookAt(lookAtTarget);
        }
    }
    
    void DebugAudioSetup()
    {
        if (audioSource == null)
        {
            Debug.LogError("No AudioSource found!");
            return;
        }
        
        Debug.Log("AudioSource Setup:");
        Debug.Log("- Has Clip: " + (audioSource.clip != null));
        Debug.Log("- Clip Name: " + (audioSource.clip ? audioSource.clip.name : "None"));
        Debug.Log("- Volume: " + audioSource.volume);
        Debug.Log("- Mute: " + audioSource.mute);
        Debug.Log("- Play on Awake: " + audioSource.playOnAwake);
        Debug.Log("- Is Playing: " + audioSource.isPlaying);
        Debug.Log("- Time: " + audioSource.time);
    }
    
    void DebugCameraSetup()
    {
        Debug.Log("Camera Setup:");
        Debug.Log("- Position: " + transform.position);
        Debug.Log("- Rotation: " + transform.eulerAngles);
        Debug.Log("- FOV: " + cam.fieldOfView);
        Debug.Log("- Near Plane: " + cam.nearClipPlane);
    }
    
    void UpdateDebugInfo()
    {
        // Show audio info every few seconds
        if (Time.time % 3f < Time.deltaTime)
        {
            if (audioSource != null)
            {
                Debug.Log($"Audio Time: {audioSource.time:F1}s, Playing: {audioSource.isPlaying}");
            }
        }
        
        // Test keyboard controls
        if (Input.GetKeyDown(KeyCode.P))
        {
            if (audioSource != null)
            {
                if (audioSource.isPlaying)
                    audioSource.Pause();
                else
                    audioSource.Play();
                Debug.Log("Audio toggled: " + audioSource.isPlaying);
            }
        }
        
        if (Input.GetKeyDown(KeyCode.R))
        {
            transform.position = fixedPosition;
            transform.LookAt(lookAtTarget);
            Debug.Log("Camera reset to: " + fixedPosition);
        }
    }
    
    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (raymarchMaterial == null)
        {
            Debug.LogError("No raymarching material assigned!");
            Graphics.Blit(source, destination);
            return;
        }
        
        // Setup camera matrices
        SetupCameraMatrices();
        
        // Set test audio values if requested
        if (testAudioValues)
        {
            raymarchMaterial.SetVector("_MusicCurrent", manualAudioValues);
        }
        
        // Set scene parameters
        raymarchMaterial.SetInt("_SceneID", 1); // Always use Mandelbulb for testing
        
        // Render
        Graphics.Blit(source, destination, raymarchMaterial);
    }
    
    void SetupCameraMatrices()
    {
        // Calculate frustum corners
        float fov = cam.fieldOfView;
        float near = cam.nearClipPlane;
        float aspect = cam.aspect;
        
        float halfHeight = near * Mathf.Tan(fov * 0.5f * Mathf.Deg2Rad);
        Vector3 toRight = cam.transform.right * halfHeight * aspect;
        Vector3 toTop = cam.transform.up * halfHeight;
        
        Vector3 topLeft = cam.transform.forward * near + toTop - toRight;
        Vector3 topRight = cam.transform.forward * near + toRight + toTop;
        Vector3 bottomLeft = cam.transform.forward * near - toTop - toRight;
        Vector3 bottomRight = cam.transform.forward * near + toRight - toTop;
        
        Matrix4x4 frustumCorners = Matrix4x4.identity;
        frustumCorners.SetRow(0, topLeft);
        frustumCorners.SetRow(1, topRight);
        frustumCorners.SetRow(2, bottomRight);
        frustumCorners.SetRow(3, bottomLeft);
        
        // Send to shader
        raymarchMaterial.SetMatrix("_FrustumCornersES", frustumCorners);
        raymarchMaterial.SetMatrix("_CameraInvViewMatrix", cam.cameraToWorldMatrix);
        raymarchMaterial.SetVector("_CameraWS", cam.transform.position);
        
        // Set default light
        raymarchMaterial.SetVector("_LightPos", cam.transform.position + Vector3.up * 10f);
        raymarchMaterial.SetVector("_LightDir", Vector3.down);
    }
    
    void OnGUI()
    {
        if (!enableDebugMode) return;
        
        GUI.Box(new Rect(10, 10, 300, 150), "Raymarching Debug");
        
        GUILayout.BeginArea(new Rect(20, 35, 280, 120));
        
        GUILayout.Label("Audio: " + (audioSource ? (audioSource.isPlaying ? "Playing" : "Stopped") : "None"));
        
        if (audioSource && audioSource.clip)
        {
            GUILayout.Label($"Time: {audioSource.time:F1}s / {audioSource.clip.length:F1}s");
        }
        
        GUILayout.Label("Camera: " + transform.position.ToString("F1"));
        
        GUILayout.Space(10);
        GUILayout.Label("Controls:");
        GUILayout.Label("P - Play/Pause Audio");
        GUILayout.Label("R - Reset Camera");
        GUILayout.Label("1-4 - Change Scene");
        
        GUILayout.EndArea();
    }
}