Shader "Custom/Water_TwoLayerNormal"
{
    Properties
    {
        [Header(Color)]
        _ShallowColor ("Shallow Color", Color) = (0.1, 0.6, 0.7, 0.9)
        _DeepColor ("Deep Color", Color) = (0.02, 0.15, 0.3, 0.9)
        _DepthMaxDistance ("Depth Max Distance", Float) = 5.0
        
        [Header(Normal Map)]
        _NormalMap ("Normal Map", 2D) = "bump" {}
        _NormalStrength ("Normal Strength", Range(0, 2)) = 0.5
        
        [Header(Layer 1)]
        _Layer1Tiling ("Layer1 Tiling", Vector) = (2, 2, 0, 0)
        _Layer1Speed ("Layer1 Speed", Float) = 0.05
        _Layer1Direction ("Layer1 Direction", Vector) = (1, 0.3, 0, 0)
        
        [Header(Layer 2)]
        _Layer2Tiling ("Layer2 Tiling", Vector) = (4, 4, 0, 0)
        _Layer2Speed ("Layer2 Speed", Float) = 0.08
        _Layer2Direction ("Layer2 Direction", Vector) = (-0.5, 1, 0, 0)
        
        [Header(Surface)]
        _Smoothness ("Smoothness", Range(0, 1)) = 0.95
        _FresnelPower ("Fresnel Power", Range(1, 10)) = 4.0
        _ReflectColor ("Reflect Color", Color) = (0.6, 0.8, 1.0, 1.0)
    }
    
    SubShader
    {
        Tags 
        { 
            "RenderType" = "Transparent" 
            "Queue" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
            "IgnoreProjector" = "True"
        }
        
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }
            
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull Back
            
            HLSLPROGRAM
            #pragma target 3.0
            #pragma vertex vert
            #pragma fragment frag
            
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile_fog
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            
            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);
            
            CBUFFER_START(UnityPerMaterial)
                half4 _ShallowColor;
                half4 _DeepColor;
                half _DepthMaxDistance;
                
                float4 _NormalMap_ST;
                half _NormalStrength;
                
                float4 _Layer1Tiling;
                half _Layer1Speed;
                float4 _Layer1Direction;
                
                float4 _Layer2Tiling;
                half _Layer2Speed;
                float4 _Layer2Direction;
                
                half _Smoothness;
                half _FresnelPower;
                half4 _ReflectColor;
            CBUFFER_END
            
            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 uv : TEXCOORD0;
            };
            
            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                half3 normalWS : TEXCOORD2;
                half3 tangentWS : TEXCOORD3;
                half3 bitangentWS : TEXCOORD4;
                float4 screenPos : TEXCOORD5;
                half fogFactor : TEXCOORD6;
            };
            
            // ノーマルアンパック
            half3 UnpackNormalWithScale(half4 packedNormal, half scale)
            {
                half3 normal;
                normal.xy = (packedNormal.xy * 2.0h - 1.0h) * scale;
                normal.z = sqrt(1.0h - saturate(dot(normal.xy, normal.xy)));
                return normal;
            }
            
            // ノーマルブレンド（Reoriented Normal Mapping）
            half3 BlendNormals(half3 n1, half3 n2)
            {
                half3 t = n1 + half3(0.0h, 0.0h, 1.0h);
                half3 u = n2 * half3(-1.0h, -1.0h, 1.0h);
                return normalize(t * dot(t, u) - u * t.z);
            }
            
            Varyings vert(Attributes IN)
            {
                Varyings OUT = (Varyings)0;
                
                VertexPositionInputs vertexInput = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);
                
                OUT.positionHCS = vertexInput.positionCS;
                OUT.positionWS = vertexInput.positionWS;
                OUT.uv = IN.uv;
                
                OUT.normalWS = normalInput.normalWS;
                OUT.tangentWS = normalInput.tangentWS;
                OUT.bitangentWS = normalInput.bitangentWS;
                
                OUT.screenPos = ComputeScreenPos(OUT.positionHCS);
                OUT.fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
                
                return OUT;
            }
            
            half4 frag(Varyings IN) : SV_Target
            {
                // ========================================
                // Layer 1
                // ========================================
                float2 uv1 = IN.uv * _Layer1Tiling.xy;
                uv1 += _Time.y * _Layer1Speed * _Layer1Direction.xy;
                
                half4 normalTex1 = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, uv1);
                half3 normal1 = UnpackNormalWithScale(normalTex1, 1.0h);
                
                // ========================================
                // Layer 2
                // ========================================
                float2 uv2 = IN.uv * _Layer2Tiling.xy;
                uv2 += _Time.y * _Layer2Speed * _Layer2Direction.xy;
                
                half4 normalTex2 = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, uv2);
                half3 normal2 = UnpackNormalWithScale(normalTex2, 1.0h);
                
                // ========================================
                // Normal Blend
                // ========================================
                half3 blendedNormal = BlendNormals(normal1, normal2);
                blendedNormal.xy *= _NormalStrength;
                blendedNormal = normalize(blendedNormal);
                
                // TBN変換
                half3x3 TBN = half3x3(
                    normalize(IN.tangentWS),
                    normalize(IN.bitangentWS),
                    normalize(IN.normalWS)
                );
                half3 normalWS = normalize(mul(blendedNormal, TBN));
                
                // ========================================
                // 深度
                // ========================================
                float2 screenUV = IN.screenPos.xy / IN.screenPos.w;
                float sceneDepth = LinearEyeDepth(SampleSceneDepth(screenUV), _ZBufferParams);
                float surfaceDepth = IN.screenPos.w;
                float depthDiff = sceneDepth - surfaceDepth;
                half depthFactor = saturate(depthDiff / _DepthMaxDistance);
                
                half4 waterColor = lerp(_ShallowColor, _DeepColor, depthFactor);
                
                // ========================================
                // Fresnel
                // ========================================
                half3 viewDirWS = normalize(GetWorldSpaceViewDir(IN.positionWS));
                half fresnel = pow(1.0h - saturate(dot(normalWS, viewDirWS)), _FresnelPower);
                
                // ========================================
                // ライティング
                // ========================================
                Light mainLight = GetMainLight();
                half3 lightDir = mainLight.direction;
                half3 lightColor = mainLight.color;
                
                half NdotL = saturate(dot(normalWS, lightDir));
                half3 diffuse = lightColor * (NdotL * 0.5h + 0.5h);
                
                // スペキュラ
                half3 halfDir = normalize(lightDir + viewDirWS);
                half spec = pow(saturate(dot(normalWS, halfDir)), 128.0h * _Smoothness);
                half3 specular = lightColor * spec * fresnel;
                
                // ========================================
                // 最終合成
                // ========================================
                half3 finalColor = lerp(waterColor.rgb, _ReflectColor.rgb, fresnel);
                finalColor *= diffuse;
                finalColor += specular;
                
                // フォグ
                finalColor = MixFog(finalColor, IN.fogFactor);
                
                return half4(finalColor, waterColor.a);
            }
            ENDHLSL
        }
        
        // シャドウキャスターは透明なので不要
    }
    
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}
