Shader "Custom/MinimalRaymarching"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        [IntRange] _SceneID ("Scene ID", Range(1, 4)) = 1
        _MaxSteps ("Max Steps", Int) = 64
        _MaxDist ("Max Distance", Float) = 100.0
        _Epsilon ("Epsilon", Float) = 0.001
        
        // Audio Reactive
        _MusicCurrent ("Music Current", Vector) = (0,0,0,0)
    }
    
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };
            
            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 rayDir : TEXCOORD1;
            };
            
            sampler2D _MainTex;
            int _SceneID;
            int _MaxSteps;
            float _MaxDist;
            float _Epsilon;
            float4 _MusicCurrent;
            
            struct SDFResult
            {
                float distance;
                float3 color;
            };
            
            SDFResult sdfResult(float d, float3 col)
            {
                SDFResult result;
                result.distance = d;
                result.color = col;
                return result;
            }
            
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                
                // Simple ray direction calculation
                float3 rayDir = float3(v.uv * 2.0 - 1.0, 1.0);
                rayDir.x *= _ScreenParams.x / _ScreenParams.y; // Aspect ratio correction
                o.rayDir = normalize(rayDir);
                
                return o;
            }
            
            // Simple HSV to RGB conversion
            float3 hsv2rgb(float3 c)
            {
                float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
                float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
                return c.z * lerp(float3(1,1,1), saturate(p - float3(1,1,1)), c.y);
            }
            
            // SDF Primitives
            float sdSphere(float3 p, float r)
            {
                return length(p) - r;
            }
            
            float sdBox(float3 p, float3 b)
            {
                float3 q = abs(p) - b;
                return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
            }
            
            // Simple Mandelbulb
            SDFResult sdMandelbulb(float3 p)
            {
                float3 w = p;
                float m = dot(w, w);
                float dz = 1.0;
                
                for (int i = 0; i < 4; i++)
                {
                    dz = 8.0 * pow(sqrt(m), 7.0) * dz + 1.0;
                    
                    float r = length(w);
                    float b = 8.0 * acos(clamp(w.y / r, -1.0, 1.0));
                    float a = 8.0 * atan2(w.x, w.z);
                    
                    w = p + pow(r, 8.0) * float3(sin(b) * sin(a), cos(b), sin(b) * cos(a));
                    
                    m = dot(w, w);
                    if (m > 256.0) break;
                }
                
                float dist = 0.25 * log(m) * sqrt(m) / dz;
                float3 color = hsv2rgb(float3(frac(m * 0.05 + _Time.y * 0.1), 0.8, 0.9));
                
                return sdfResult(dist, color * (1.0 + _MusicCurrent.w * 2.0));
            }
            
            // Audio-reactive sphere
            SDFResult sdAudioSphere(float3 p)
            {
                float r = 5.0 + _MusicCurrent.x * 3.0;
                float d = sdSphere(p, r);
                float3 color = float3(
                    0.5 + 0.5 * _MusicCurrent.x,
                    0.5 + 0.5 * _MusicCurrent.y,
                    0.5 + 0.5 * _MusicCurrent.z
                );
                return sdfResult(d, color);
            }
            
            // Morphing box
            SDFResult sdMorphBox(float3 p)
            {
                float3 size = float3(3, 3, 3) + float3(2, 2, 2) * _MusicCurrent.xyz;
                float d = sdBox(p, size);
                float3 color = hsv2rgb(float3(_Time.y * 0.1 + _MusicCurrent.w, 0.7, 0.8));
                return sdfResult(d, color);
            }
            
            // Scene selection
            SDFResult sdScene(float3 p)
            {
                if (_SceneID == 1)
                    return sdMandelbulb(p * 0.2);
                else if (_SceneID == 2)
                    return sdAudioSphere(p);
                else if (_SceneID == 3)
                    return sdMorphBox(p);
                else
                    return sdfResult(sdSphere(p, 10.0), float3(1.0, 0.5, 1.0));
            }
            
            // Simple raymarching
            SDFResult raymarch(float3 ro, float3 rd)
            {
                float t = 0.0;
                SDFResult result;
                
                for (int i = 0; i < _MaxSteps; i++)
                {
                    float3 p = ro + t * rd;
                    result = sdScene(p);
                    
                    if (result.distance < _Epsilon)
                    {
                        result.distance = t;
                        return result;
                    }
                    
                    t += result.distance;
                    
                    if (t > _MaxDist)
                        break;
                }
                
                result.distance = _MaxDist;
                return result;
            }
            
            // Simple normal calculation
            float3 calcNormal(float3 p)
            {
                float2 e = float2(0.001, 0.0);
                return normalize(float3(
                    sdScene(p + e.xyy).distance - sdScene(p - e.xyy).distance,
                    sdScene(p + e.yxy).distance - sdScene(p - e.yxy).distance,
                    sdScene(p + e.yyx).distance - sdScene(p - e.yyx).distance
                ));
            }
            
            fixed4 frag (v2f i) : SV_Target
            {
                // Camera setup
                float3 rayOrigin = float3(0, 0, -20);
                float3 rayDir = normalize(i.rayDir);
                
                // Raymarch
                SDFResult result = raymarch(rayOrigin, rayDir);
                
                if (result.distance >= _MaxDist)
                {
                    // Background
                    float3 bgColor = lerp(
                        float3(0.02, 0.02, 0.05), 
                        float3(0.1, 0.05, 0.2), 
                        _MusicCurrent.w
                    );
                    return fixed4(bgColor, 1.0);
                }
                
                // Hit point
                float3 p = rayOrigin + result.distance * rayDir;
                float3 normal = calcNormal(p);
                
                // Simple lighting
                float3 lightDir = normalize(float3(1, 1, -1));
                float ndotl = max(0.0, dot(normal, lightDir));
                
                float3 finalColor = result.color * (0.3 + 0.7 * ndotl);
                
                // Audio-reactive effects
                finalColor += _MusicCurrent.xyz * 0.1 * sin(_Time.y * 10.0);
                
                return fixed4(finalColor, 1.0);
            }
            ENDCG
        }
    }
}