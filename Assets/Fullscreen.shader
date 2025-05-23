Shader "Custom/FullScreenRaymarching"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        [IntRange] _SceneID ("Scene ID", Range(1, 4)) = 1
        _MaxSteps ("Max Steps", Int) = 128
        _MaxDist ("Max Distance", Float) = 200.0
        _Epsilon ("Epsilon", Float) = 0.001
        
        // Audio Reactive
        _MusicCurrent ("Music Current", Vector) = (0,0,0,0)
    }
    
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        Cull Off ZWrite Off ZTest Always
        
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
            float _MusicSpectrum[64];
            
            // Camera matrices
            float4x4 _FrustumCornersES;
            float4x4 _CameraInvViewMatrix;
            float3 _CameraWS;
            float3 _LightDir;
            float3 _LightPos;
            
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
                
                // Calculate ray direction from frustum corners
                float3 rayDir;
                if (v.uv.x < 0.5 && v.uv.y < 0.5) 
                    rayDir = _FrustumCornersES[0].xyz;
                else if (v.uv.x > 0.5 && v.uv.y < 0.5) 
                    rayDir = _FrustumCornersES[1].xyz;
                else if (v.uv.x > 0.5 && v.uv.y > 0.5) 
                    rayDir = _FrustumCornersES[2].xyz;
                else 
                    rayDir = _FrustumCornersES[3].xyz;
                
                o.rayDir = mul(_CameraInvViewMatrix, float4(rayDir, 0.0)).xyz;
                o.rayDir = normalize(o.rayDir);
                
                return o;
            }
            
            // Utility functions
            float3 rotateY(float3 p, float angle)
            {
                float c = cos(angle);
                float s = sin(angle);
                return float3(p.x * c + p.z * s, p.y, -p.x * s + p.z * c);
            }
            
            float3 rotateX(float3 p, float angle)
            {
                float c = cos(angle);
                float s = sin(angle);
                return float3(p.x, p.y * c - p.z * s, p.y * s + p.z * c);
            }
            
            // HSV to RGB conversion
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
            
            float sdTorus(float3 p, float2 t)
            {
                float2 q = float2(length(p.xz) - t.x, p.y);
                return length(q) - t.y;
            }
            
            // SDF Operations
            float smoothMin(float a, float b, float k)
            {
                float h = saturate(0.5 + 0.5 * (b - a) / k);
                return lerp(b, a, h) - k * h * (1.0 - h);
            }
            
            // Mandelbulb fractal
            SDFResult sdMandelbulb(float3 p)
            {
                float3 w = p;
                float m = dot(w, w);
                float4 trap = float4(abs(w), m);
                float dz = 1.0;
                float power = 8.0 + _MusicCurrent.y * 4.0;
                
                for (int i = 0; i < 4; i++)
                {
                    dz = power * pow(sqrt(m), power - 1.0) * dz + 1.0;
                    
                    float r = length(w);
                    if (r < 0.001) break;
                    
                    float theta = power * acos(clamp(w.y / r, -1.0, 1.0));
                    float phi = power * atan2(w.x, w.z);
                    
                    w = p + pow(r, power) * float3(
                        sin(theta) * sin(phi),
                        cos(theta),
                        sin(theta) * cos(phi)
                    );
                    
                    trap = min(trap, float4(abs(w), m));
                    m = dot(w, w);
                    if (m > 256.0) break;
                }
                
                float dist = 0.25 * log(m) * sqrt(m) / max(dz, 0.001);
                
                // Audio-reactive coloring
                float3 color = hsv2rgb(float3(
                    frac(trap.w * 0.05 + _Time.y * 0.1 + _MusicCurrent.x * 0.5),
                    0.8 + 0.2 * _MusicCurrent.y,
                    0.7 + 0.3 * _MusicCurrent.z
                ));
                
                return sdfResult(dist, color * (1.5 + _MusicCurrent.w * 3.0));
            }
            
            // Audio-reactive tunnel
            SDFResult sdAudioTunnel(float3 p)
            {
                // Rotate based on audio
                p = rotateY(p, _Time.y * 0.5 + _MusicCurrent.x * 3.0);
                
                // Create tunnel
                float tunnelRadius = 8.0 + _MusicCurrent.x * 4.0;
                float d = length(p.xy) - tunnelRadius;
                
                // Add audio-reactive bumps
                float bumps = sin(p.z * 0.5 + _Time.y * 2.0) * _MusicCurrent.y * 2.0;
                d += bumps;
                
                // Repeating elements
                float3 q = p;
                q.z = fmod(q.z + _Time.y * 10.0, 20.0) - 10.0;
                float rings = sdTorus(q, float2(tunnelRadius - 1.0, 0.5 + _MusicCurrent.z));
                d = smoothMin(d, rings, 2.0);
                
                // Color based on position and audio
                float3 color = hsv2rgb(float3(
                    frac(p.z * 0.02 + _Time.y * 0.1),
                    0.8,
                    0.6 + 0.4 * _MusicCurrent.w
                ));
                
                return sdfResult(d, color);
            }
            
            // Morphing geometry scene
            SDFResult sdMorphingScene(float3 p)
            {
                // Audio-reactive transformations
                p = rotateX(p, _Time.y * 0.3 + _MusicCurrent.y * 2.0);
                p = rotateY(p, _Time.y * 0.2 + _MusicCurrent.x * 1.5);
                
                // Base shapes
                float sphere = sdSphere(p, 8.0 + _MusicCurrent.x * 3.0);
                float box = sdBox(p, float3(6, 6, 6) + float3(3, 3, 3) * _MusicCurrent.yzw);
                
                // Morph between shapes based on audio
                float t = 0.5 + 0.5 * sin(_Time.y + _MusicCurrent.w * 5.0);
                float d = lerp(sphere, box, t);
                
                // Add detail
                float detail = sin(p.x * 2.0) * sin(p.y * 2.0) * sin(p.z * 2.0) * _MusicCurrent.z;
                d += detail;
                
                // Audio-reactive color
                float3 color = float3(
                    0.5 + 0.5 * sin(_Time.y + _MusicCurrent.x * 6.28),
                    0.5 + 0.5 * sin(_Time.y * 1.3 + _MusicCurrent.y * 6.28),
                    0.5 + 0.5 * sin(_Time.y * 0.7 + _MusicCurrent.z * 6.28)
                );
                
                return sdfResult(d, color * (1.0 + _MusicCurrent.w * 2.0));
            }
            
            // Spectrum bars visualization
            SDFResult sdSpectrumBars(float3 p)
            {
                float numBars = 32.0;
                float barSpacing = 4.0;
                float barWidth = 1.5;
                
                SDFResult result = sdfResult(1000.0, float3(0, 0, 0));
                
                // Create bars based on spectrum data
                float barIndex = floor((p.x + numBars * barSpacing * 0.5) / barSpacing);
                barIndex = clamp(barIndex, 0.0, numBars - 1.0);
                
                float localX = p.x - (barIndex - numBars * 0.5) * barSpacing;
                
                // Get spectrum value (simplified)
                float spectrumValue = _MusicCurrent.x * (1.0 + sin(barIndex * 0.5 + _Time.y * 2.0) * 0.5);
                float height = 2.0 + spectrumValue * 20.0;
                
                float3 q = float3(localX, p.y - height * 0.5, p.z);
                float d = sdBox(q, float3(barWidth, height * 0.5, barWidth));
                
                // Color based on height and position
                float3 color = hsv2rgb(float3(
                    barIndex / numBars + _Time.y * 0.1,
                    0.8,
                    0.5 + 0.5 * spectrumValue
                ));
                
                return sdfResult(d, color);
            }
            
            // Scene selection
            SDFResult sdScene(float3 p)
            {
                if (_SceneID == 1)
                    return sdMandelbulb(p * 0.15);
                else if (_SceneID == 2)
                    return sdAudioTunnel(p);
                else if (_SceneID == 3)
                    return sdMorphingScene(p);
                else if (_SceneID == 4)
                    return sdSpectrumBars(p);
                
                // Default
                return sdfResult(sdSphere(p, 10.0), float3(1.0, 0.5, 1.0));
            }
            
            // Raymarching
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
            
            // Normal calculation
            float3 calcNormal(float3 p)
            {
                float2 e = float2(0.001, 0.0);
                return normalize(float3(
                    sdScene(p + e.xyy).distance - sdScene(p - e.xyy).distance,
                    sdScene(p + e.yxy).distance - sdScene(p - e.yxy).distance,
                    sdScene(p + e.yyx).distance - sdScene(p - e.yyx).distance
                ));
            }
            
            // Lighting
            float calcSoftShadow(float3 ro, float3 rd, float mint, float k)
            {
                float result = 1.0;
                float t = mint;
                
                for (int i = 0; i < 16; i++)
                {
                    float h = sdScene(ro + rd * t).distance;
                    if (h < 0.001) return 0.0;
                    result = min(result, k * h / t);
                    t += h;
                    if (t > 20.0) break;
                }
                return result;
            }
            
            fixed4 frag (v2f i) : SV_Target
            {
                float3 rayOrigin = _CameraWS;
                float3 rayDir = normalize(i.rayDir);
                
                // Raymarch
                SDFResult result = raymarch(rayOrigin, rayDir);
                
                if (result.distance >= _MaxDist)
                {
                    // Dynamic background based on audio
                    float3 bgColor = lerp(
                        float3(0.01, 0.01, 0.03), 
                        float3(0.2, 0.05, 0.3), 
                        _MusicCurrent.w
                    );
                    
                    // Add some background patterns
                    float pattern = sin(i.uv.x * 20.0 + _Time.y) * sin(i.uv.y * 20.0 + _Time.y * 1.3);
                    bgColor += pattern * _MusicCurrent.xyz * 0.1;
                    
                    return fixed4(bgColor, 1.0);
                }
                
                // Hit point
                float3 p = rayOrigin + result.distance * rayDir;
                float3 normal = calcNormal(p);
                
                // Lighting
                float3 lightDir = normalize(_LightPos - p);
                float ndotl = max(0.0, dot(normal, lightDir));
                
                // Soft shadows
                float shadow = calcSoftShadow(p + normal * 0.01, lightDir, 0.1, 8.0);
                
                // Final lighting
                float3 ambient = result.color * 0.3;
                float3 diffuse = result.color * ndotl * shadow * 0.7;
                
                // Fresnel rim lighting
                float fresnel = 1.0 - saturate(dot(normal, -rayDir));
                fresnel = pow(fresnel, 2.0);
                float3 rim = float3(0.5, 0.8, 1.0) * fresnel * _MusicCurrent.w * 0.5;
                
                float3 finalColor = ambient + diffuse + rim;
                
                // Audio-reactive post effects
                finalColor += _MusicCurrent.xyz * 0.1 * sin(_Time.y * 15.0);
                
                // Add some bloom effect
                finalColor *= 1.0 + _MusicCurrent.w * 0.5;
                
                return fixed4(finalColor, 1.0);
            }
            ENDCG
        }
    }
}