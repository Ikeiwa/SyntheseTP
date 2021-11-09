// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Liquid/Liquid Rendering"
{
	Properties
	{
		[HideInInspector] _MainTex("Source", 2D) = "white" {}
		[HideInInspector] _Depth("Source", 2D) = "white" {}
		[HideInInspector] _Background("Background",2D) = "white" {}
		_Specular("Specular",Range(1,100)) = 1
		_FluidDensity("Fluid Density",Range(0,1)) = 1
		_AttennuationConstant("Attennuation Constant",Float) = 1
		_ReflectionConstant("Reflection Constant",Float) = 0
		[Toggle(SOLID_PARTICLES)] _SolidParticles("Solid Particles", Float) = 0
	}
	SubShader
	{
		Cull Off
		ZWrite Off
		ZTest Always

		Pass
		{
			CGPROGRAM
			#pragma shader_feature SOLID_PARTICLES
			#pragma vertex vertexShader
			#pragma fragment fragmentShader

			#include <UnityLightingCommon.cginc>

			#include "UnityCG.cginc"

			struct vertexInput
			{
				float4 vertex : POSITION;
				float2 texcoord : TEXCOORD0;
			};

			struct vertexOutput
			{
				float2 texcoord : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};

			vertexOutput vertexShader(vertexInput i)
			{
				vertexOutput o;
				o.vertex = UnityObjectToClipPos(i.vertex);
				o.texcoord = i.texcoord;
				return o;
			}

			sampler2D _MainTex;
			sampler2D _LiquidTex;
			sampler2D _Background;
			uniform float4x4 UNITY_MATRIX_IV;

			Texture2D _Depth;
			float4 _Depth_TexelSize;

			float _Specular;
			float _FluidDensity;
			float _AttennuationConstant;
			float _ReflectionConstant;

			float3 rayFromScreenUV(in float2 uv, in float4x4 InvMatrix)
			{
				float x = uv.x * 2.0 - 1.0;
				float y = uv.y * 2.0 - 1.0;
				float4 position_s = float4(x, y, 1.0, 1.0);
				return mul(InvMatrix, position_s * _ProjectionParams.z);
			}

			float3 viewSpacePosAtPixelPosition(float2 pos)
			{
				float rawDepth = _Depth.Load(int3(pos, 0)).r;
				float2 uv = pos * _Depth_TexelSize.xy;
				float3 ray = rayFromScreenUV(uv, unity_CameraInvProjection);
				return ray * rawDepth;
			}

			float3 viewSpaceNormalAtPixelPosition(float2 pos)
			{
				float3 vpl = viewSpacePosAtPixelPosition(pos + float2(-1, 0));
				float3 vpr = viewSpacePosAtPixelPosition(pos + float2(1, 0));
				float3 vpd = viewSpacePosAtPixelPosition(pos + float2(0, -1));
				float3 vpu = viewSpacePosAtPixelPosition(pos + float2(0, 1));

				float3 viewNormal = normalize(-cross(vpu - vpd, vpr - vpl));
				viewNormal.z = -viewNormal.z;
				return viewNormal;
			}

			float3 computeAttennuation(float thickness,float3 k)
			{
				return float3(exp(-k.r * thickness), exp(-k.g * thickness), exp(-k.b * thickness));
			}

			float4 fragmentShader(vertexOutput i) : COLOR
			{
				float2 liquidData = _Depth.Load(int3(i.vertex.xy, 0)).rg;
				float depth = liquidData.r;

				float2 uv = i.texcoord;

				if (depth <= 0 || depth >= 1)
					return tex2D(_MainTex, uv);

				//Define constants
				const float refractiveIndex = 1.33;
				const float eta = 1.0 / refractiveIndex; // Ratio of indices of refraction
				const float fresnelPower = 5.0;
				const float F = ((1.0 - eta) * (1.0 - eta)) / ((1.0 + eta) * (1.0 + eta));

				//Compute vectors
				float3 viewPos = viewSpacePosAtPixelPosition(i.vertex.xy);
				viewPos.z = -viewPos.z;

				float3 worldPos = mul(UNITY_MATRIX_IV, float4(viewPos.xyz, 1)).xyz;
				float3 viewNormal = viewSpaceNormalAtPixelPosition(i.vertex.xy);
				float3 worldNormal = mul(UNITY_MATRIX_IV, float4(viewNormal.xyz, 0)).xyz;

				float3 lightDir		= _WorldSpaceLightPos0;
				float3 viewViewDir	= normalize(-viewPos.xyz);
				float3 viewDir		= normalize(_WorldSpaceCameraPos - worldPos);
				float3 H			= normalize(lightDir + viewDir);

				float specular = pow(max(0.0f, dot(H, worldNormal)), _Specular) * _LightColor0;
				float diffuse = max(0.0f, dot(lightDir, worldNormal)) * _LightColor0;


				#ifdef SOLID_PARTICLES
				float3 finalColor = diffuse + unity_AmbientSky.rgb * tex2D(_MainTex, uv);

				return float4(finalColor, 1);
				#else
				//Get liquid data
				float thickness = saturate(liquidData.g / (1/_FluidDensity));
				float4 color = tex2D(_MainTex, uv);

				//Reflection
				float fresnelRatio = clamp(F + (1.0 - F) * pow(1.0 - dot(viewDir, worldNormal), fresnelPower), 0, 1);
				float3 reflectDir	= reflect(-viewDir, worldNormal);
				float3 reflectionColor = UNITY_SAMPLE_TEXCUBE(unity_SpecCube0, reflectDir);

				//Attenuation
				float3 colorAttennuation = computeAttennuation(thickness * 5.0f,1-color);
				colorAttennuation = lerp(float3(1, 1, 1), colorAttennuation, _AttennuationConstant);

				//Refraction
				float3 refractionDir = refract(-viewViewDir, viewNormal, 1.0 / refractiveIndex);
				float3 refractionColor = colorAttennuation * tex2D(_Background, uv + refractionDir.xy * thickness * _AttennuationConstant * 0.1f).rgb;

				fresnelRatio = lerp(fresnelRatio, 1.0, _ReflectionConstant);
				

				float3 finalColor = (lerp(refractionColor, reflectionColor, fresnelRatio) + specular);

				return float4(finalColor, thickness);
				#endif
				
			}
			ENDCG
		}
	}
	Fallback Off
}