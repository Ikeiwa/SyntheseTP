Shader "Liquid/Fluid Particle" {
	Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    	_Elasticity ("Elasticity", Float) = 5
		_ParticleRadius("Particle Radius",Float) = 0.05
    }
    SubShader {
        Tags {"Queue"="Geometry" "RenderType"="Opaque"}
		LOD 100

		//ZWrite Off
		//Blend SrcAlpha OneMinusSrcAlpha 
    	
    	CGINCLUDE
		#include "UnityCG.cginc"

		struct v2f {
			float4 pos   : SV_POSITION;
			fixed4 color : COLOR;
			float3 normal: NORMAL;
			float2 uv : TEXCOORD0;
			float4 screenPos : TEXCOORD1;
		};

		struct Particle {
			float3 pos;
			float3 vel;
			float4 color;
		};

		StructuredBuffer<Particle> Particles;
		sampler2D _MainTex;
		float _Elasticity;
		float _ParticleRadius;

		v2f vert(appdata_base i, uint instanceID: SV_InstanceID) {
			v2f o;

			float3 worldPivot = Particles[instanceID].pos;
			float4 viewPos = mul(UNITY_MATRIX_V, float4(worldPivot, 1)) + float4(i.vertex.xyz, 0);
			o.pos = mul(UNITY_MATRIX_P, viewPos);

			/*float3 velocity = Particles[instanceID].vel;

			if (velocity.x + velocity.y + velocity.z != 0)
			{
				float lookDir = 1 - abs(dot(normalize(velocity), normalize(worldPivot - _WorldSpaceCameraPos)));
				lookDir *= saturate(length(velocity * float3(1, 0.5, 1)));

				float ratio = _ScreenParams.x / _ScreenParams.y;


				float4 centerClip = UnityObjectToClipPos(worldPivot);

				float4 velDir = UnityObjectToClipPos(worldPivot + velocity);
				velDir.xy /= velDir.w;
				velDir.xy -= centerClip.xy / centerClip.w;
				velDir.x *= ratio;
				velDir.xy = normalize(velDir.xy);

				float angle = atan2(velDir.y, velDir.x);

				float angleSin = sin(angle);
				float angleCos = cos(angle);

				float2x2 rotMat = { angleCos, angleSin,
								   -angleSin, angleCos };

				o.pos.xy -= centerClip.xy;
				o.pos.x *= ratio;

				o.pos.x *= (lookDir * _Elasticity) + 1;
				o.pos.xy = mul(o.pos.xy, rotMat);

				o.pos.x /= ratio;
				o.pos.xy += centerClip.xy;
			}*/

			o.color = Particles[instanceID].color;
			o.uv = i.texcoord;
			o.screenPos = ComputeScreenPos(o.pos);

			return o;
		}

		struct fragOut
		{
			half4 color : SV_Target;
			float depth : SV_Depth;
		};

		fragOut frag(v2f i){
			fragOut o;

			float4 col = tex2D(_MainTex, i.uv) * i.color;
			clip(col.a - 0.01f);

			o.color = col;
			o.depth = (i.screenPos.z + col.a * _ParticleRadius) / i.screenPos.w;

			return o;
		}
		ENDCG

        Pass {
			ColorMask RGB
        	
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
			#pragma target 2.0
			#pragma multi_compile_instancing

            ENDCG
        }
    	
		Pass{
			ZTest Off
			Blend One One
			ColorMask A
			
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 2.0
			#pragma multi_compile_instancing

			ENDCG
		}
    	
			
    	
		Pass {
			Name "ShadowCaster"
			Tags { "LightMode" = "ShadowCaster" }

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 2.0
			#pragma multi_compile_shadowcaster
			#pragma multi_compile_instancing
			ENDCG

		}
    }
}