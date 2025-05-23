using UnityEngine;
using System.Collections;

[System.Serializable]
public struct MusicData
{
    public Vector4 current;      // x=bass, y=mid, z=high, w=energy
    public Vector4 cumulative;   // Accumulated values over time
    public float[] spectrum;     // Full spectrum data
    public int spectrumCount;
}

public class AdvancedAudioAnalyzer : MonoBehaviour
{
    [Header("Audio Source")]
    [SerializeField] private AudioSource audioSource;
    
    [Header("Analysis Settings")]
    [SerializeField] private int spectrumSize = 64;
    [SerializeField] private int bassRange = 8;      // 0-7 for bass
    [SerializeField] private int midRange = 16;      // 8-23 for mids  
    [SerializeField] private int highRange = 24;     // 24-63 for highs
    
    [Header("Audio Smoothing")]
    [SerializeField] private float smoothingFactor = 0.1f;
    [SerializeField] private float energyMultiplier = 10f;
    
    [Header("Materials")]
    [SerializeField] private Material[] raymarchMaterials;
    
    private MusicData musicData;
    private float[] rawSpectrum;
    private Vector4 cumulativeData;
    private float[] smoothedSpectrum;
    
    void Start()
    {
        musicData.spectrum = new float[spectrumSize];
        rawSpectrum = new float[spectrumSize];
        smoothedSpectrum = new float[spectrumSize];
        musicData.spectrumCount = spectrumSize;
    }
    
    void Update()
    {
        AnalyzeAudio();
        UpdateShaderProperties();
    }
    
    void AnalyzeAudio()
    {
        // Get raw spectrum data
        audioSource.GetSpectrumData(rawSpectrum, 0, FFTWindow.BlackmanHarris);
        
        // Smooth the spectrum data
        for (int i = 0; i < spectrumSize; i++)
        {
            smoothedSpectrum[i] = Mathf.Lerp(smoothedSpectrum[i], rawSpectrum[i], smoothingFactor);
            musicData.spectrum[i] = smoothedSpectrum[i];
        }
        
        // Calculate frequency bands
        float bass = 0f, mid = 0f, high = 0f;
        
        // Bass (0-7)
        for (int i = 0; i < bassRange; i++)
            bass += smoothedSpectrum[i];
        bass /= bassRange;
        
        // Mids (8-23)  
        for (int i = bassRange; i < bassRange + midRange; i++)
            mid += smoothedSpectrum[i];
        mid /= midRange;
        
        // Highs (24-63)
        for (int i = bassRange + midRange; i < spectrumSize; i++)
            high += smoothedSpectrum[i];
        high /= (spectrumSize - bassRange - midRange);
        
        // Overall energy
        float energy = (bass + mid + high) / 3f;
        
        // Apply energy multiplier and clamp
        musicData.current = new Vector4(
            Mathf.Clamp01(bass * energyMultiplier),
            Mathf.Clamp01(mid * energyMultiplier),
            Mathf.Clamp01(high * energyMultiplier),
            Mathf.Clamp01(energy * energyMultiplier)
        );
        
        // Update cumulative data (with decay)
        cumulativeData = Vector4.Lerp(cumulativeData, musicData.current, 0.01f);
        cumulativeData += musicData.current * Time.deltaTime * 0.1f;
        musicData.cumulative = cumulativeData;
    }
    
    void UpdateShaderProperties()
    {
        foreach (Material mat in raymarchMaterials)
        {
            if (mat != null)
            {
                mat.SetVector("_MusicCurrent", musicData.current);
                mat.SetVector("_MusicCumulative", musicData.cumulative);
                mat.SetFloatArray("_MusicSpectrum", musicData.spectrum);
                mat.SetInt("_SpectrumCount", musicData.spectrumCount);
            }
        }
    }
}