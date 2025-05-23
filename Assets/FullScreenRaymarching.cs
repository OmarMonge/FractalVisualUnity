// using UnityEngine;

// [ExecuteInEditMode, RequireComponent(typeof(Camera))]
// public class FullScreenRaymarching : MonoBehaviour
// {
//     [Header("Raymarching Material")]
//     [SerializeField] private Material raymarchMaterial;
    
//     [Header("Scene Settings")]
//     [SerializeField] private int currentSceneID = 1;
//     [SerializeField] private bool autoAdvanceScenes = true;
//     [SerializeField] private float sceneTransitionTime = 30f;
    
//     [Header("Camera Movement")]
//     [SerializeField] private bool enableCameraAnimation = true;
//     [SerializeField] private float cameraSpeed = 1f;
//     [SerializeField] private Vector3 cameraOrbitCenter = Vector3.zero;
//     [SerializeField] private float cameraOrbitRadius = 20f;
    
//     [Header("Audio Integration")]
//     [SerializeField] private AudioSource audioSource;
//     [SerializeField] private bool enableAudioReactivity = true;
    
//     private Camera cam;
//     private float sceneTimer = 0f;
//     private AdvancedAudioAnalyzer audioAnalyzer;
    
//     // Audio analysis
//     private float[] spectrumData;
//     private Vector4 musicData;
    
//     void Start()
//     {
//         cam = GetComponent<Camera>();
//         audioAnalyzer = GetComponent<AdvancedAudioAnalyzer>();
        
//         if (audioSource == null)
//             audioSource = GetComponent<AudioSource>();
        
//         spectrumData = new float[64];
        
//         // Ensure camera renders nothing by default (we'll replace everything)
//         cam.clearFlags = CameraClearFlags.SolidColor;
//         cam.backgroundColor = Color.black;
//     }
    
//     void Update()
//     {
//         UpdateSceneManagement();
//         UpdateCameraAnimation();
//         UpdateAudioAnalysis();
//     }
    
//     void UpdateSceneManagement()
//     {
//         sceneTimer += Time.deltaTime;
        
//         // Auto advance scenes
//         if (autoAdvanceScenes && sceneTimer >= sceneTransitionTime)
//         {
//             currentSceneID = (currentSceneID % 4) + 1; // Cycle through scenes 1-4
//             sceneTimer = 0f;
//             Debug.Log($"Advanced to Scene {currentSceneID}");
//         }
        
//         // Manual scene switching
//         if (Input.GetKeyDown(KeyCode.Alpha1)) currentSceneID = 1;
//         if (Input.GetKeyDown(KeyCode.Alpha2)) currentSceneID = 2;
//         if (Input.GetKeyDown(KeyCode.Alpha3)) currentSceneID = 3;
//         if (Input.GetKeyDown(KeyCode.Alpha4)) currentSceneID = 4;
//         if (Input.GetKeyDown(KeyCode.Space)) autoAdvanceScenes = !autoAdvanceScenes;
//     }
    
//     void UpdateCameraAnimation()
//     {
//         if (!enableCameraAnimation) return;
        
//         float time = Time.time * cameraSpeed;
        
//         // Audio-reactive camera movement
//         float bassBoost = enableAudioReactivity ? musicData.x * 2f : 0f;
//         float midRotation = enableAudioReactivity ? musicData.y * 30f : 0f;
        
//         // Orbital camera movement
//         Vector3 offset = new Vector3(
//             Mathf.Sin(time + bassBoost) * cameraOrbitRadius,
//             Mathf.Sin(time * 0.5f + musicData.z * 5f) * cameraOrbitRadius * 0.3f,
//             Mathf.Cos(time + bassBoost) * cameraOrbitRadius
//         );
        
//         transform.position = cameraOrbitCenter + offset;
//         transform.LookAt(cameraOrbitCenter);
        
//         // Add audio-reactive rotation
//         transform.Rotate(0, midRotation * Time.deltaTime, 0);
//     }
    
//     void UpdateAudioAnalysis()
//     {
//         if (!enableAudioReactivity || audioSource == null) return;
        
//         // Get spectrum data
//         audioSource.GetSpectrumData(spectrumData, 0, FFTWindow.BlackmanHarris);
        
//         // Calculate frequency bands
//         float bass = 0f, mid = 0f, high = 0f;
        
//         // Bass (0-7)
//         for (int i = 0; i < 8; i++)
//             bass += spectrumData[i];
//         bass /= 8f;
        
//         // Mids (8-23)
//         for (int i = 8; i < 24; i++)
//             mid += spectrumData[i];
//         mid /= 16f;
        
//         // Highs (24-63)
//         for (int i = 24; i < 64; i++)
//             high += spectrumData[i];
//         high /= 40f;
        
//         // Overall energy
//         float energy = (bass + mid + high) / 3f;
        
//         // Apply multiplier and smooth
//         float multiplier = 15f;
//         musicData = Vector4.Lerp(musicData, new Vector4(
//             Mathf.Clamp01(bass * multiplier),
//             Mathf.Clamp01(mid * multiplier),
//             Mathf.Clamp01(high * multiplier),
//             Mathf.Clamp01(energy * multiplier)
//         ), Time.deltaTime * 10f);
//     }
    
//     // This is where the magic happens - replaces the entire screen
//     void OnRenderImage(RenderTexture source, RenderTexture destination)
//     {
//         if (raymarchMaterial == null)
//         {
//             Graphics.Blit(source, destination);
//             return;
//         }
        
//         // Setup camera matrices for proper ray calculation
//         SetupCameraMatrices();
        
//         // Set scene parameters
//         raymarchMaterial.SetInt("_SceneID", currentSceneID);
        
//         // Set audio data
//         if (enableAudioReactivity)
//         {
//             raymarchMaterial.SetVector("_MusicCurrent", musicData);
//             raymarchMaterial.SetFloatArray("_MusicSpectrum", spectrumData);
//         }
        
//         // Render full screen effect
//         Graphics.Blit(source, destination, raymarchMaterial);
//     }
    
//     void SetupCameraMatrices()
//     {
//         // Calculate frustum corners for proper ray directions
//         float fov = cam.fieldOfView;
//         float near = cam.nearClipPlane;
//         float aspect = cam.aspect;
        
//         float halfHeight = near * Mathf.Tan(fov * 0.5f * Mathf.Deg2Rad);
//         Vector3 toRight = cam.transform.right * halfHeight * aspect;
//         Vector3 toTop = cam.transform.up * halfHeight;
        
//         Vector3 topLeft = cam.transform.forward * near + toTop - toRight;
//         Vector3 topRight = cam.transform.forward * near + toRight + toTop;
//         Vector3 bottomLeft = cam.transform.forward * near - toTop - toRight;
//         Vector3 bottomRight = cam.transform.forward * near + toRight - toTop;
        
//         Matrix4x4 frustumCorners = Matrix4x4.identity;
//         frustumCorners.SetRow(0, topLeft);
//         frustumCorners.SetRow(1, topRight);
//         frustumCorners.SetRow(2, bottomRight);
//         frustumCorners.SetRow(3, bottomLeft);
        
//         // Send to shader
//         raymarchMaterial.SetMatrix("_FrustumCornersES", frustumCorners);
//         raymarchMaterial.SetMatrix("_CameraInvViewMatrix", cam.cameraToWorldMatrix);
//         raymarchMaterial.SetVector("_CameraWS", cam.transform.position);
        
//         // Set default light (can be improved with actual light sources)
//         raymarchMaterial.SetVector("_LightPos", cam.transform.position + Vector3.up * 10f);
//         raymarchMaterial.SetVector("_LightDir", Vector3.down);
//     }
    
//     // Public methods for external control
//     public void SetScene(int sceneID)
//     {
//         currentSceneID = Mathf.Clamp(sceneID, 1, 4);
//         sceneTimer = 0f;
//     }
    
//     public void ToggleAutoAdvance()
//     {
//         autoAdvanceScenes = !autoAdvanceScenes;
//     }
    
//     public void SetCameraOrbit(Vector3 center, float radius)
//     {
//         cameraOrbitCenter = center;
//         cameraOrbitRadius = radius;
//     }
// }
using UnityEngine;

[ExecuteInEditMode, RequireComponent(typeof(Camera))]
public class FullScreenRaymarching : MonoBehaviour
{
    [Header("Raymarching Material")]
    [SerializeField] private Material raymarchMaterial;
    
    [Header("Scene Settings")]
    [SerializeField] private int currentSceneID = 1;
    [SerializeField] private bool autoAdvanceScenes = true;
    [SerializeField] private float sceneTransitionTime = 30f;
    
    [Header("Camera Movement")]
    [SerializeField] private bool enableCameraAnimation = true;
    [SerializeField] private float cameraSpeed = 1f;
    [SerializeField] private Vector3 cameraOrbitCenter = Vector3.zero;
    [SerializeField] private float cameraOrbitRadius = 20f;
    
    [Header("Audio Integration")]
    [SerializeField] private AudioSource audioSource;
    [SerializeField] private bool enableAudioReactivity = true;
    
    private Camera cam;
    private float sceneTimer = 0f;
    private AdvancedAudioAnalyzer audioAnalyzer;
    
    // Audio analysis
    private float[] spectrumData;
    private Vector4 musicData;
    
    void Start()
    {
        cam = GetComponent<Camera>();
        audioAnalyzer = GetComponent<AdvancedAudioAnalyzer>();
        
        if (audioSource == null)
            audioSource = GetComponent<AudioSource>();
        
        spectrumData = new float[64];
        
        // Ensure camera renders nothing by default (we'll replace everything)
        cam.clearFlags = CameraClearFlags.SolidColor;
        cam.backgroundColor = Color.black;
    }
    
    void Update()
    {
        UpdateSceneManagement();
        UpdateCameraAnimation();
        UpdateAudioAnalysis();
    }
    
    void UpdateSceneManagement()
    {
        sceneTimer += Time.deltaTime;
        
        // Auto advance scenes
        if (autoAdvanceScenes && sceneTimer >= sceneTransitionTime)
        {
            currentSceneID = (currentSceneID % 4) + 1; // Cycle through scenes 1-4
            sceneTimer = 0f;
            Debug.Log($"Advanced to Scene {currentSceneID}");
        }
        
        // Manual scene switching
        if (Input.GetKeyDown(KeyCode.Alpha1)) currentSceneID = 1;
        if (Input.GetKeyDown(KeyCode.Alpha2)) currentSceneID = 2;
        if (Input.GetKeyDown(KeyCode.Alpha3)) currentSceneID = 3;
        if (Input.GetKeyDown(KeyCode.Alpha4)) currentSceneID = 4;
        if (Input.GetKeyDown(KeyCode.Space)) autoAdvanceScenes = !autoAdvanceScenes;
    }
    
    void UpdateCameraAnimation()
    {
        if (!enableCameraAnimation) return;
        
        float time = Time.time * cameraSpeed;
        
        // Audio-reactive camera movement
        float bassBoost = enableAudioReactivity ? musicData.x * 2f : 0f;
        float midRotation = enableAudioReactivity ? musicData.y * 30f : 0f;
        
        // Orbital camera movement - adjusted to center objects better
        Vector3 offset = new Vector3(
            Mathf.Sin(time + bassBoost) * cameraOrbitRadius,
            Mathf.Sin(time * 0.5f + musicData.z * 5f) * cameraOrbitRadius * 0.2f, // Reduced Y movement
            Mathf.Cos(time + bassBoost) * cameraOrbitRadius
        );
        
        transform.position = cameraOrbitCenter + offset;
        
        // Always look at center to keep objects centered
        transform.LookAt(cameraOrbitCenter);
        
        // Add subtle audio-reactive rotation around the center
        transform.RotateAround(cameraOrbitCenter, Vector3.up, midRotation * Time.deltaTime);
    }
    
    void UpdateAudioAnalysis()
    {
        if (!enableAudioReactivity || audioSource == null) return;
        
        // Get spectrum data
        audioSource.GetSpectrumData(spectrumData, 0, FFTWindow.BlackmanHarris);
        
        // Calculate frequency bands
        float bass = 0f, mid = 0f, high = 0f;
        
        // Bass (0-7)
        for (int i = 0; i < 8; i++)
            bass += spectrumData[i];
        bass /= 8f;
        
        // Mids (8-23)
        for (int i = 8; i < 24; i++)
            mid += spectrumData[i];
        mid /= 16f;
        
        // Highs (24-63)
        for (int i = 24; i < 64; i++)
            high += spectrumData[i];
        high /= 40f;
        
        // Overall energy
        float energy = (bass + mid + high) / 3f;
        
        // Apply multiplier and smooth
        float multiplier = 15f;
        musicData = Vector4.Lerp(musicData, new Vector4(
            Mathf.Clamp01(bass * multiplier),
            Mathf.Clamp01(mid * multiplier),
            Mathf.Clamp01(high * multiplier),
            Mathf.Clamp01(energy * multiplier)
        ), Time.deltaTime * 10f);
    }
    
    // This is where the magic happens - replaces the entire screen
    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (raymarchMaterial == null)
        {
            Graphics.Blit(source, destination);
            return;
        }
        
        // Setup camera matrices for proper ray calculation
        SetupCameraMatrices();
        
        // Set scene parameters
        raymarchMaterial.SetInt("_SceneID", currentSceneID);
        
        // Set audio data
        if (enableAudioReactivity)
        {
            raymarchMaterial.SetVector("_MusicCurrent", musicData);
            raymarchMaterial.SetFloatArray("_MusicSpectrum", spectrumData);
        }
        
        // Render full screen effect
        Graphics.Blit(source, destination, raymarchMaterial);
    }
    
    void SetupCameraMatrices()
    {
        // Calculate frustum corners for proper ray directions
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
        
        // Set default light (can be improved with actual light sources)
        raymarchMaterial.SetVector("_LightPos", cam.transform.position + Vector3.up * 10f);
        raymarchMaterial.SetVector("_LightDir", Vector3.down);
    }
    
    // Public methods for external control
    public void SetScene(int sceneID)
    {
        currentSceneID = Mathf.Clamp(sceneID, 1, 4);
        sceneTimer = 0f;
    }
    
    public void ToggleAutoAdvance()
    {
        autoAdvanceScenes = !autoAdvanceScenes;
    }
    
    public void SetCameraOrbit(Vector3 center, float radius)
    {
        cameraOrbitCenter = center;
        cameraOrbitRadius = radius;
    }
}