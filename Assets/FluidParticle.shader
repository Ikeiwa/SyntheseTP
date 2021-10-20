Shader "Custom/Fluid Particle" {
	Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    	_Elasticity ("Elasticity", Float) = 5
    }
    SubShader {
        Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent"}
		LOD 100

		//ZWrite Off
		//Blend SrcAlpha OneMinusSrcAlpha 

        Pass {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata_t {
                float4 vertex   : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f {
                float4 vertex   : SV_POSITION;
                fixed4 color    : COLOR;
                float2 uv : TEXCOORD0;
            }; 

            struct Particle {
                float3 pos;
                float3 vel;
                float4 color;
            };

            StructuredBuffer<Particle> Particles;
            sampler2D _MainTex;
            float _Elasticity;

            v2f vert(appdata_t i, uint instanceID: SV_InstanceID) {
                v2f o;

				float3 worldPivot = Particles[instanceID].pos;
				float4 viewPos = mul(UNITY_MATRIX_V, float4(worldPivot,1)) + float4(i.vertex.xyz, 0);
                o.vertex = mul(UNITY_MATRIX_P, viewPos);

                float3 velocity = Particles[instanceID].vel;

                if(velocity.x+velocity.y+velocity.z != 0)
                {
	                float lookDir = 1-abs(dot(normalize(velocity),normalize(worldPivot-_WorldSpaceCameraPos)));
	                lookDir *= saturate(length(velocity*float3(1,0.5,1)));

	                float ratio = _ScreenParams.x/_ScreenParams.y;

	                
	                float4 centerClip = UnityObjectToClipPos(worldPivot);

	                float4 velDir = UnityObjectToClipPos(worldPivot+velocity);
	                velDir.xy /= velDir.w;
	                velDir.xy -= centerClip.xy / centerClip.w;
	                velDir.x *= ratio;
	                velDir.xy = normalize(velDir.xy);

	                float angle = atan2(velDir.y,velDir.x);

	                float angleSin = sin(angle);
	                float angleCos = cos(angle);

	                float2x2 rotMat = {angleCos, angleSin,
	                                   -angleSin, angleCos};

	                o.vertex.xy -= centerClip.xy;
	                o.vertex.x *= ratio;

	                o.vertex.x *= (lookDir*_Elasticity)+1;
	                o.vertex.xy = mul(o.vertex.xy,rotMat);

	                o.vertex.x /= ratio;
	                o.vertex.xy += centerClip.xy;
                }

                o.color = Particles[instanceID].color;
                o.uv = i.uv;

                return o;
            }

            fixed4 frag(v2f i) : SV_Target {
                float4 col = tex2D(_MainTex, i.uv)*i.color;
                clip(col.a-0.15f);
                return col;
            }

            ENDCG
        }
    }
}