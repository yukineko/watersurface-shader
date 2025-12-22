Shader "Custom/MirrorWaterRipple"
{
    Properties
    {
        _BaseColor ("Base Color", Color) = (0.01, 0.05, 0.1, 1)
        _RippleCenter ("Ripple Center", Vector) = (0.5, 0.5, 0, 0)
        _RippleTime ("Ripple Time", Float) = 0
        _Frequency ("Frequency", Float) = 30
        _Speed ("Speed", Float) = 3
        _Amplitude ("Amplitude", Float) = 0.15
        _Decay ("Decay", Float) = 3
        _FresnelPower ("Fresnel Power", Float) = 3
        _Smoothness ("Smoothness", Range(0,1)) = 0.95
    }
    
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }
        
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
            };
            
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                float3 viewDirWS : TEXCOORD3;
            };
            
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float2 _RippleCenter;
                float _RippleTime;
                float _Frequency;
                float _Speed;
                float _Amplitude;
                float _Decay;
                float _FresnelPower;
                float _Smoothness;
            CBUFFER_END
            
            Varyings vert(Attributes input)
            {
                Varyings output;
                
                VertexPositionInputs posInputs = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = posInputs.positionCS;
                output.positionWS = posInputs.positionWS;
                output.uv = input.uv;
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                output.viewDirWS = GetWorldSpaceNormalizeViewDir(posInputs.positionWS);
                
                return output;
            }
            
            // 波紋計算
            void ComputeRipple(float2 uv, float2 center, float time, 
                              float frequency, float speed, float amplitude, float decay,
                              out float3 normal, out float height)
            {
                float dist = length(uv - center);
                float wave = dist * frequency - time * speed;
                float distanceDecay = exp(-dist * decay);
                float timeDecay = exp(-time * 0.5);
                
                height = sin(wave) * amplitude * distanceDecay * timeDecay;
                height += sin(wave * 2.0) * 0.3 * amplitude * distanceDecay * timeDecay;
                
                float dHeight = cos(wave) * frequency * amplitude * distanceDecay * timeDecay;
                dHeight += cos(wave * 2.0) * 0.6 * frequency * amplitude * distanceDecay * timeDecay;
                dHeight -= height * decay;
                
                float2 dir = normalize(uv - center + 0.0001);
                normal = normalize(float3(-dir.x * dHeight, 1.0, -dir.y * dHeight));
            }
            
            half4 frag(Varyings input) : SV_Target
            {
                // 波紋の法線を計算
                float3 rippleNormal;
                float rippleHeight;
                ComputeRipple(input.uv, _RippleCenter, _RippleTime,
                             _Frequency, _Speed, _Amplitude, _Decay,
                             rippleNormal, rippleHeight);
                
                // 波紋法線をワールド空間に変換
                float3 worldNormal = normalize(
                    rippleNormal.x * float3(1,0,0) + 
                    rippleNormal.y * input.normalWS + 
                    rippleNormal.z * float3(0,0,1)
                );
                
                // Fresnel
                float NdotV = saturate(dot(worldNormal, input.viewDirWS));
                float fresnel = pow(1.0 - NdotV, _FresnelPower);
                fresnel = lerp(0.02, 1.0, fresnel);
                
                // Skybox反射
                float3 reflectDir = reflect(-input.viewDirWS, worldNormal);
                half3 reflection = GlossyEnvironmentReflection(reflectDir, 1.0 - _Smoothness, 1.0);
                
                // 最終色
                half3 finalColor = lerp(_BaseColor.rgb, reflection, fresnel);
                
                return half4(finalColor, 1.0);
            }
            ENDHLSL
        }
    }
    FallBack "Universal Render Pipeline/Lit"
}