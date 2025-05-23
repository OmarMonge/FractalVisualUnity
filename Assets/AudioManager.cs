using UnityEngine;
using System.Collections;

[RequireComponent(typeof(AudioSource))]
public class AudioManager : MonoBehaviour
{
    [Header("Audio Setup")]
    [SerializeField] private AudioClip musicClip;
    [SerializeField] private bool playOnStart = true;
    [SerializeField] private bool loopMusic = true;
    
    [Header("Audio Settings")]
    [SerializeField] private float masterVolume = 1f;
    [SerializeField] private bool muteAudio = false;
    
    [Header("Debug Info")]
    [SerializeField] private bool showDebugInfo = true;
    [SerializeField] private bool showAudioWaveform = true;
    
    private AudioSource audioSource;
    private float[] samples = new float[512];
    private float[] waveform = new float[64];
    private string debugMessage = "";
    
    void Awake()
    {
        // Get or add AudioSource component
        audioSource = GetComponent<AudioSource>();
        if (audioSource == null)
        {
            audioSource = gameObject.AddComponent<AudioSource>();
        }
        
        ConfigureAudioSource();
    }
    
    void Start()
    {
        // Verify audio system
        CheckAudioSystem();
        
        if (playOnStart && musicClip != null)
        {
            PlayMusic();
        }
    }
    
    void ConfigureAudioSource()
    {
        // Configure AudioSource settings
        audioSource.playOnAwake = false;
        audioSource.loop = loopMusic;
        audioSource.volume = masterVolume;
        audioSource.mute = muteAudio;
        audioSource.spatialBlend = 0f; // 2D sound
        audioSource.priority = 0; // Highest priority
        
        if (musicClip != null)
        {
            audioSource.clip = musicClip;
        }
        
        // Make sure audio plays through speakers
        audioSource.outputAudioMixerGroup = null;
        
        debugMessage = "AudioSource configured";
    }
    
    void CheckAudioSystem()
    {
        // Check audio configuration
        AudioConfiguration config = AudioSettings.GetConfiguration();
        
        Debug.Log("=== Audio System Check ===");
        Debug.Log($"Sample Rate: {config.sampleRate} Hz");
        Debug.Log($"DSP Buffer Size: {config.dspBufferSize}");
        Debug.Log($"Speaker Mode: {config.speakerMode}");
        Debug.Log($"Number of Real Voices: {config.numRealVoices}");
        Debug.Log($"Number of Virtual Voices: {config.numVirtualVoices}");
        
        // Check if audio is disabled
        if (AudioListener.volume == 0)
        {
            Debug.LogWarning("AudioListener volume is 0! Setting to 1.");
            AudioListener.volume = 1f;
        }
        
        if (AudioListener.pause)
        {
            Debug.LogWarning("AudioListener is paused! Unpausing.");
            AudioListener.pause = false;
        }
        
        // Check for AudioListener
        AudioListener listener = FindObjectOfType<AudioListener>();
        if (listener == null)
        {
            Debug.LogError("No AudioListener found in scene! Adding one to Main Camera.");
            Camera mainCam = Camera.main;
            if (mainCam != null)
            {
                mainCam.gameObject.AddComponent<AudioListener>();
            }
        }
        else
        {
            Debug.Log($"AudioListener found on: {listener.gameObject.name}");
        }
    }
    
    public void PlayMusic()
    {
        if (audioSource == null || musicClip == null)
        {
            Debug.LogError("Cannot play music: AudioSource or AudioClip is null!");
            return;
        }
        
        audioSource.clip = musicClip;
        audioSource.Play();
        
        debugMessage = $"Playing: {musicClip.name}";
        Debug.Log($"Started playing music: {musicClip.name}");
        
        // Double-check it's actually playing
        StartCoroutine(VerifyPlayback());
    }
    
    IEnumerator VerifyPlayback()
    {
        yield return new WaitForSeconds(0.1f);
        
        if (!audioSource.isPlaying)
        {
            Debug.LogError("Audio failed to start! Attempting force play...");
            
            // Force audio context
            AudioListener.pause = false;
            AudioListener.volume = 1f;
            
            // Try playing again
            audioSource.Stop();
            audioSource.Play();
            
            yield return new WaitForSeconds(0.1f);
            
            if (!audioSource.isPlaying)
            {
                Debug.LogError("Audio still not playing! Check Unity Audio settings in Edit > Project Settings > Audio");
            }
            else
            {
                Debug.Log("Audio successfully started after retry");
            }
        }
    }
    
    void Update()
    {
        // Update volume
        if (audioSource != null)
        {
            audioSource.volume = masterVolume;
            audioSource.mute = muteAudio;
        }
        
        // Get audio data for visualization
        if (audioSource != null && audioSource.isPlaying)
        {
            audioSource.GetSpectrumData(waveform, 0, FFTWindow.Hanning);
        }
        
        // Keyboard controls
        HandleKeyboardControls();
    }
    
    void HandleKeyboardControls()
    {
        // Play/Pause with Space
        if (Input.GetKeyDown(KeyCode.Space))
        {
            if (audioSource.isPlaying)
                audioSource.Pause();
            else
                audioSource.UnPause();
                
            debugMessage = audioSource.isPlaying ? "Playing" : "Paused";
        }
        
        // Volume control with +/-
        if (Input.GetKey(KeyCode.Equals) || Input.GetKey(KeyCode.KeypadPlus))
        {
            masterVolume = Mathf.Clamp01(masterVolume + 0.01f);
        }
        if (Input.GetKey(KeyCode.Minus) || Input.GetKey(KeyCode.KeypadMinus))
        {
            masterVolume = Mathf.Clamp01(masterVolume - 0.01f);
        }
        
        // Mute with M
        if (Input.GetKeyDown(KeyCode.M))
        {
            muteAudio = !muteAudio;
            debugMessage = muteAudio ? "Muted" : "Unmuted";
        }
        
        // Restart with R
        if (Input.GetKeyDown(KeyCode.R))
        {
            audioSource.Stop();
            audioSource.Play();
            debugMessage = "Restarted";
        }
    }
    
    void OnGUI()
    {
        if (!showDebugInfo) return;
        
        // Debug info box
        GUI.Box(new Rect(10, 10, 350, 180), "Audio Debug Info");
        
        GUILayout.BeginArea(new Rect(20, 35, 330, 145));
        
        GUILayout.Label($"Status: {debugMessage}");
        
        if (audioSource != null)
        {
            GUILayout.Label($"Is Playing: {audioSource.isPlaying}");
            GUILayout.Label($"Time: {audioSource.time:F1}s / {(audioSource.clip ? audioSource.clip.length : 0):F1}s");
            GUILayout.Label($"Volume: {masterVolume:F2} (Master: {AudioListener.volume:F2})");
            GUILayout.Label($"Muted: {muteAudio} (Listener Paused: {AudioListener.pause})");
            
            if (audioSource.clip != null)
            {
                GUILayout.Label($"Clip: {audioSource.clip.name}");
                GUILayout.Label($"Channels: {audioSource.clip.channels}, {audioSource.clip.frequency}Hz");
            }
        }
        
        GUILayout.Space(5);
        GUILayout.Label("Controls: Space=Play/Pause, M=Mute, R=Restart, +/-=Volume");
        
        GUILayout.EndArea();
        
        // Waveform visualization
        if (showAudioWaveform && audioSource != null && audioSource.isPlaying)
        {
            DrawWaveform();
        }
    }
    
    void DrawWaveform()
    {
        int width = 300;
        int height = 100;
        int startX = 10;
        int startY = 200;
        
        // Background
        GUI.Box(new Rect(startX, startY, width, height), "Audio Waveform");
        
        // Draw waveform
        for (int i = 1; i < waveform.Length; i++)
        {
            float x1 = startX + (i - 1) * (width / (float)waveform.Length);
            float x2 = startX + i * (width / (float)waveform.Length);
            float y1 = startY + height - waveform[i - 1] * height * 0.8f - 10;
            float y2 = startY + height - waveform[i] * height * 0.8f - 10;
            
            DrawLine(new Vector2(x1, y1), new Vector2(x2, y2), Color.green);
        }
    }
    
    void DrawLine(Vector2 start, Vector2 end, Color color)
    {
        float distance = Vector2.Distance(start, end);
        if (distance < 0.01f) return;
        
        Camera cam = Camera.main;
        if (cam == null) return;
        
        GUI.color = color;
        
        float angle = Mathf.Atan2(end.y - start.y, end.x - start.x) * Mathf.Rad2Deg;
        GUIUtility.RotateAroundPivot(angle, start);
        GUI.DrawTexture(new Rect(start.x, start.y - 1, distance, 2), Texture2D.whiteTexture);
        GUIUtility.RotateAroundPivot(-angle, start);
        
        GUI.color = Color.white;
    }
    
    // Public methods
    public void SetVolume(float volume)
    {
        masterVolume = Mathf.Clamp01(volume);
    }
    
    public void ToggleMute()
    {
        muteAudio = !muteAudio;
    }
    
    public bool IsPlaying()
    {
        return audioSource != null && audioSource.isPlaying;
    }
    
    public float GetCurrentTime()
    {
        return audioSource != null ? audioSource.time : 0f;
    }
}