// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Liquid/Liquid Rendering"
{
    Properties
    {
		_MainTex("Source", 2D) = "white" {}
		_Depth("Source", 2D) = "white" {}
        _Specular("Specular",Range(1,100)) = 1
    }
        SubShader
       {
          Cull Off
          ZWrite Off
          ZTest Always

          Pass
          {
             CGPROGRAM
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
             uniform float4x4 UNITY_MATRIX_IV;

             Texture2D _Depth;
             float4 _Depth_TexelSize;

             float _Specular;

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
                 return ray * Linear01Depth(rawDepth);
             }

             float4 fragmentShader(vertexOutput i) : COLOR
             {
             	float depth = _Depth.Load(int3(i.vertex.xy, 0)).r;
                depth = Linear01Depth(depth);

                float2 uv = i.texcoord;
                float4 color = tex2D(_MainTex, uv);

                if(depth<=0 || depth>=1)
                    return float4(color.rgb,depth);

                float3 viewPos = viewSpacePosAtPixelPosition(i.vertex.xy);
                viewPos.z = -viewPos.z;
                float3 WorldPos = mul(UNITY_MATRIX_IV, float4(viewPos.xyz, 1)).xyz;

                float3 vpl = viewSpacePosAtPixelPosition(i.vertex.xy + float2(-1, 0));
                float3 vpr = viewSpacePosAtPixelPosition(i.vertex.xy + float2(1, 0));
                float3 vpd = viewSpacePosAtPixelPosition(i.vertex.xy + float2(0, -1));
                float3 vpu = viewSpacePosAtPixelPosition(i.vertex.xy + float2(0, 1));

                float3 viewNormal = normalize(-cross(vpu - vpd, vpr - vpl));
                viewNormal.z = -viewNormal.z;
                float3 WorldNormal = mul(UNITY_MATRIX_IV, float4(viewNormal.xyz, 0)).xyz;

                float3 thickness = color.a;

                float3 finalColor = color;

                float3 LightDir = _WorldSpaceLightPos0;
                float3 ReflectLight = reflect(LightDir, WorldNormal);
                float3 ViewDir = normalize(_WorldSpaceCameraPos - WorldPos);

                float3 ambientLighting = UNITY_LIGHTMODEL_AMBIENT.rgb * finalColor;
                float3 diffuse = saturate(dot(WorldNormal, LightDir)) * finalColor * _LightColor0;
                float3 specular = pow(saturate(dot(ReflectLight, -ViewDir)),_Specular) * finalColor * _LightColor0;

                finalColor = ambientLighting + diffuse + specular;

                return float4(finalColor,depth);
             }
             ENDCG
          }
       }
           Fallback Off
}
