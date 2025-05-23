Shader "Custom/EnhancedFractalRaymarching"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        [IntRange] _SceneID ("Scene ID", Range(1, 8)) = 1
        _MaxSteps ("Max Steps", Int) = 128
        _MaxDist ("Max Distance", Float) = 200.0
        _Epsilon ("Epsilon", Float) = 0.001
        
        // Fractal Controls
        _FractalIterations ("Fractal Iterations", Range(1, 16)) = 8
        _FractalPower ("Fractal Power", Range(2, 16)) = 8.0
        _FractalScale ("Fractal Scale", Range(0.5, 3.0)) = 2.0
        
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
            int _FractalIterations;
            float _FractalPower;
            float _FractalScale;
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
                float glow;
            };
            
            SDFResult sdfResult(float d, float3 col, float glow = 0.0)
            {
                SDFResult result;
                result.distance = d;
                result.color = col;
                result.glow = glow;
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
            
            float3 rotateZ(float3 p, float angle)
            {
                float c = cos(angle);
                float s = sin(angle);
                return float3(p.x * c - p.y * s, p.x * s + p.y * c, p.z);
            }
            
            // HSV to RGB conversion
            float3 hsv2rgb(float3 c)
            {
                float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
                float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
                return c.z * lerp(float3(1,1,1), saturate(p - float3(1,1,1)), c.y);
            }
            
            // Fractal folding operations
            float3 boxFold(float3 p, float3 b)
            {
                return clamp(p, -b, b) * 2.0 - p;
            }
            
            float3 sphereFold(float3 p, float minR, float maxR)
            {
                float r2 = dot(p, p);
                if (r2 < minR * minR)
                    return p * (maxR * maxR) / (minR * minR);
                else if (r2 < maxR * maxR)
                    return p * (maxR * maxR) / r2;
                return p;
            }
            
            // SDF Operations
            float smoothMin(float a, float b, float k)
            {
                float h = saturate(0.5 + 0.5 * (b - a) / k);
                return lerp(b, a, h) - k * h * (1.0 - h);
            }
            
            float3 repeat(float3 p, float3 r)
            {
                return fmod(abs(p) + r * 0.5, r) - r * 0.5;
            }
            
            // 1. Enhanced Mandelbulb with audio
            SDFResult sdMandelbulb(float3 p)
            {
                float3 w = p;
                float m = dot(w, w);
                float4 trap = float4(abs(w), m);
                float dz = 1.0;
                float power = _FractalPower + _MusicCurrent.y * 4.0;
                
                for (int i = 0; i < _FractalIterations; i++)
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
                
                float3 color = hsv2rgb(float3(
                    frac(trap.w * 0.05 + _Time.y * 0.1 + _MusicCurrent.x * 0.5),
                    0.8 + 0.2 * _MusicCurrent.y,
                    0.7 + 0.3 * _MusicCurrent.z
                ));
                
                return sdfResult(dist, color * (1.5 + _MusicCurrent.w * 3.0), trap.w * 0.01);
            }
            
            // 2. Mandelbox fractal
            SDFResult sdMandelbox(float3 p)
            {
                float3 offset = p;
                float dr = 1.0;
                float minR = 0.5;
                float fixedR = 1.0;
                float scale = _FractalScale + _MusicCurrent.x * 0.5;
                float trap = 1e10;
                
                for (int i = 0; i < _FractalIterations; i++)
                {
                    // Box fold
                    p = boxFold(p, float3(1, 1, 1));
                    
                    // Sphere fold
                    p = sphereFold(p, minR, fixedR);
                    
                    // Scale and translate
                    p = scale * p + offset;
                    dr = dr * abs(scale) + 1.0;
                    
                    trap = min(trap, length(p));
                }
                
                float dist = length(p) / abs(dr);
                
                float3 color = hsv2rgb(float3(
                    frac(trap * 0.1 + _Time.y * 0.05),
                    0.7 + 0.3 * _MusicCurrent.y,
                    0.6 + 0.4 * _MusicCurrent.z
                ));
                
                return sdfResult(dist, color, trap * 0.02);
            }
            
            // 3. Sierpinski Triangle
            SDFResult sdSierpinski(float3 p)
            {
                float3 a1 = float3(1, 1, 1);
                float3 a2 = float3(-1, -1, 1);
                float3 a3 = float3(1, -1, -1);
                float3 a4 = float3(-1, 1, -1);
                float3 c;
                float scale = 2.0;
                float dist = 0.0;
                float d;
                
                for (int i = 0; i < _FractalIterations; i++)
                {
                    c = a1; d = length(p - a1);
                    float da = length(p - a2); if (da < d) { d = da; c = a2; }
                    da = length(p - a3); if (da < d) { d = da; c = a3; }
                    da = length(p - a4); if (da < d) { d = da; c = a4; }
                    p = scale * p - c * (scale - 1.0);
                }
                
                dist = length(p) * pow(scale, float(-_FractalIterations));
                
                float3 color = hsv2rgb(float3(
                    frac(d * 0.5 + _Time.y * 0.1),
                    0.8,
                    0.9 + 0.1 * _MusicCurrent.w
                ));
                
                return sdfResult(dist, color * (1.0 + _MusicCurrent.w * 2.0));
            }
            
            // 4. Menger Sponge
            SDFResult sdMenger(float3 p)
            {
                float3 offset = p;
                float scale = 1.0;
                
                for (int i = 0; i < _FractalIterations; i++)
                {
                    p = abs(p);
                    if (p.x < p.y) p.xy = p.yx;
                    if (p.x < p.z) p.xz = p.zx;
                    if (p.y < p.z) p.yz = p.zy;
                    
                    p *= 3.0;
                    scale *= 3.0;
                    
                    p.x -= 2.0;
                    p.y -= 2.0;
                    if (p.z > 1.0) p.z -= 2.0;
                }
                
                float dist = (length(p) - 1.5) / scale;
                
                float3 color = hsv2rgb(float3(
                    frac(scale * 0.01 + _Time.y * 0.1 + _MusicCurrent.x * 0.3),
                    0.7,
                    0.8
                ));
                
                return sdfResult(dist, color);
            }
            
            // 5. Apollonian Gasket
            SDFResult sdApollonian(float3 p)
            {
                float scale = 1.0;
                float r = 0.2 + _MusicCurrent.x * 0.1;
                
                for (int i = 0; i < _FractalIterations; i++)
                {
                    p = -1.0 + 2.0 * frac(0.5 * p + 0.5);
                    
                    float r2 = dot(p, p);
                    float k = max(r / r2, 1.0);
                    p *= k;
                    scale *= k;
                }
                
                float dist = 0.25 * abs(p.y) / scale;
                
                float3 color = hsv2rgb(float3(
                    frac(scale * 0.02 + _Time.y * 0.05),
                    0.8 + 0.2 * sin(_Time.y + scale),
                    0.7
                ));
                
                return sdfResult(dist, color * (1.0 + _MusicCurrent.w));
            }
            
            // 6. Kleinian Group Limit Set
            SDFResult sdKleinian(float3 p)
            {
                float3 cSize = float3(0.92436, 0.90756, 0.92436);
                float size = 1.0;
                
                p = p * 0.5 + float3(0.5, 0.5, 0.5);
                float3 offset = float3(0.0, 1.4124, 0.0);
                
                for (int i = 0; i < _FractalIterations; i++)
                {
                    p = abs(p);
                    float t = 2.0 * min(min(p.x, p.y), p.z);
                    p -= t * cSize;
                    
                    float3 q = p;
                    q.z -= 0.5 * cSize.z;
                    q.z = abs(q.z);
                    q.z -= 0.5 * cSize.z;
                    
                    float r2 = dot(q, q);
                    float k = max(size / r2, 1.0);
                    p *= k;
                    
                    p += offset;
                }
                
                float dist = (length(p) - 0.01) / 50.0;
                
                float3 color = hsv2rgb(float3(
                    frac(p.x * 0.1 + _Time.y * 0.1),
                    0.7 + 0.3 * _MusicCurrent.y,
                    0.8
                ));
                
                return sdfResult(dist, color);
            }
            
            // 7. Julia Set in 3D
            SDFResult sdJulia3D(float3 p)
            {
                float4 c = float4(0.45, 0.0, 0.0, 0.0) + _MusicCurrent * 0.2;
                float4 z = float4(p, 0.0);
                float md2 = 1.0;
                float mz2 = dot(z, z);
                
                for (int i = 0; i < _FractalIterations; i++)
                {
                    md2 *= 4.0 * mz2;
                    z = float4(
                        z.x * z.x - dot(z.yzw, z.yzw),
                        2.0 * z.x * z.yzw
                    ) + c;
                    mz2 = dot(z, z);
                    if (mz2 > 4.0) break;
                }
                
                float dist = 0.25 * sqrt(mz2 / md2) * log(mz2);
                
                float3 color = hsv2rgb(float3(
                    frac(mz2 * 0.1 + _Time.y * 0.1),
                    0.8,
                    0.7 + 0.3 * _MusicCurrent.w
                ));
                
                return sdfResult(dist, color, mz2 * 0.01);
            }
            
            // 8. Hybrid fractal - mix different types
            SDFResult sdHybrid(float3 p)
            {
                float3 offset = p;
                float scale = 1.0;
                float trap = 1e10;
                
                for (int i = 0; i < _FractalIterations; i++)
                {
                    // Mix of different folding operations
                    if (i % 3 == 0)
                    {
                        // Mandelbox style
                        p = boxFold(p, float3(1, 1, 1));
                        p = sphereFold(p, 0.5, 1.0);
                    }
                    else if (i % 3 == 1)
                    {
                        // Sierpinski style
                        p = abs(p);
                        if (p.x < p.y) p.xy = p.yx;
                        if (p.x < p.z) p.xz = p.zx;
                        if (p.y < p.z) p.yz = p.zy;
                    }
                    else
                    {
                        // Kaleidoscopic
                        p.xy = abs(p.xy);
                        p = rotateZ(p, _Time.y * 0.1 + _MusicCurrent.x);
                    }
                    
                    p = _FractalScale * p + offset;
                    scale *= _FractalScale;
                    trap = min(trap, length(p));
                }
                
                float dist = length(p) / scale;
                
                float3 color = hsv2rgb(float3(
                    frac(trap * 0.05 + _Time.y * 0.1),
                    0.8 + 0.2 * sin(_Time.y * 2.0 + trap),
                    0.7 + 0.3 * _MusicCurrent.w
                ));
                
                return sdfResult(dist, color * (1.0 + _MusicCurrent.w * 2.0), trap * 0.01);
            }
            
            // Scene selection
            SDFResult sdScene(float3 p)
            {
                // Audio-reactive rotation
                p = rotateY(p, _Time.y * 0.1 + _MusicCurrent.x * 2.0);
                p = rotateX(p, _Time.y * 0.05 + _MusicCurrent.y * 1.5);
                
                if (_SceneID == 1)
                    return sdMandelbulb(p * 0.15);
                else if (_SceneID == 2)
                    return sdMandelbox(p * 0.15);
                else if (_SceneID == 3)
                    return sdSierpinski(p * 0.1);
                else if (_SceneID == 4)
                    return sdMenger(p * 0.15);
                else if (_SceneID == 5)
                    return sdApollonian(p * 0.2);
                else if (_SceneID == 6)
                    return sdKleinian(p);
                else if (_SceneID == 7)
                    return sdJulia3D(p * 0.15);
                else if (_SceneID == 8)
                    return sdHybrid(p * 0.15);
                
                // Default
                return sdfResult(length(p) - 10.0, float3(1.0, 0.5, 1.0));
            }
            
            // Enhanced raymarching with glow accumulation
            SDFResult raymarch(float3 ro, float3 rd)
            {
                float t = 0.0;
                SDFResult result;
                float glow = 0.0;
                
                for (int i = 0; i < _MaxSteps; i++)
                {
                    float3 p = ro + t * rd;
                    result = sdScene(p);
                    
                    // Accumulate glow for near-misses
                    glow += result.glow / (1.0 + result.distance * result.distance);
                    
                    if (result.distance < _Epsilon)
                    {
                        result.distance = t;
                        result.glow = glow;
                        return result;
                    }
                    
                    t += result.distance * 0.8; // Slightly smaller steps for better quality
                    
                    if (t > _MaxDist)
                        break;
                }
                
                result.distance = _MaxDist;
                result.glow = glow;
                return result;
            }
            
            // Normal calculation with better precision
            float3 calcNormal(float3 p)
            {
                float2 e = float2(0.0001, 0.0);
                return normalize(float3(
                    sdScene(p + e.xyy).distance - sdScene(p - e.xyy).distance,
                    sdScene(p + e.yxy).distance - sdScene(p - e.yxy).distance,
                    sdScene(p + e.yyx).distance - sdScene(p - e.yyx).distance
                ));
            }
            
            // Ambient occlusion
            float calcAO(float3 p, float3 n)
            {
                float ao = 0.0;
                float weight = 1.0;
                for (int i = 0; i < 5; i++)
                {
                    float dist = 0.01 + 0.02 * float(i);
                    ao += weight * (dist - sdScene(p + n * dist).distance);
                    weight *= 0.5;
                }
                return 1.0 - saturate(ao * 5.0);
            }
            
            // Enhanced lighting
            float3 calcLighting(float3 p, float3 n, float3 rd, SDFResult hit)
            {
                float3 lightDir = normalize(_LightPos - p);
                float ndotl = max(0.0, dot(n, lightDir));
                
                // Soft shadows
                float shadow = 1.0;
                float t = 0.01;
                for (int i = 0; i < 32; i++)
                {
                    float h = sdScene(p + lightDir * t).distance;
                    if (h < 0.001) 
                    {
                        shadow = 0.0;
                        break;
                    }
                    shadow = min(shadow, 8.0 * h / t);
                    t += h;
                    if (t > 20.0) break;
                }
                
                // Ambient occlusion
                float ao = calcAO(p, n);
                
                // Fresnel rim lighting
                float fresnel = 1.0 - saturate(dot(n, -rd));
                fresnel = pow(fresnel, 3.0);
                
                // Combine lighting
                float3 ambient = hit.color * 0.2 * ao;
                float3 diffuse = hit.color * ndotl * shadow * 0.7;
                float3 rim = float3(0.5, 0.8, 1.0) * fresnel * _MusicCurrent.w;
                
                // Add glow effect
                float3 glowColor = hsv2rgb(float3(_Time.y * 0.1, 0.8, 1.0));
                float3 glow = glowColor * hit.glow * 0.1 * (1.0 + _MusicCurrent.w * 2.0);
                
                return ambient + diffuse + rim + glow;
            }
            
            fixed4 frag (v2f i) : SV_Target
            {
                float3 rayOrigin = _CameraWS;
                float3 rayDir = normalize(i.rayDir);
                
                // Raymarch
                SDFResult result = raymarch(rayOrigin, rayDir);
                
                if (result.distance >= _MaxDist)
                {
                    // Dynamic fractal-inspired background
                    float pattern = sin(i.uv.x * 30.0 + _Time.y) * sin(i.uv.y * 30.0 + _Time.y * 1.3);
                    pattern += sin(i.uv.x * 50.0 + _Time.y * 2.0) * sin(i.uv.y * 50.0 + _Time.y * 1.7) * 0.5;
                    
                    float3 bgColor = lerp(
                        float3(0.01, 0.01, 0.03), 
                        float3(0.2, 0.05, 0.3), 
                        _MusicCurrent.w + pattern * 0.1
                    );
                    
                    // Add glow to background
                    bgColor += result.glow * hsv2rgb(float3(_Time.y * 0.1, 0.8, 0.5)) * 0.05;
                    
                    return fixed4(bgColor, 1.0);
                }
                
                // Hit point and lighting
                float3 p = rayOrigin + result.distance * rayDir;
                float3 normal = calcNormal(p);
                float3 finalColor = calcLighting(p, normal, rayDir, result);
                
                // Audio-reactive post effects
                finalColor += _MusicCurrent.xyz * 0.1 * sin(_Time.y * 15.0);
                
                // Bloom effect
                finalColor *= 1.0 + _MusicCurrent.w * 0.5;
                
                // Tone mapping
                finalColor = finalColor / (finalColor + float3(1, 1, 1));
                finalColor = pow(finalColor, float3(1.0/2.2, 1.0/2.2, 1.0/2.2));
                
                return fixed4(finalColor, 1.0);
            }
            ENDCG
        }
    }
}