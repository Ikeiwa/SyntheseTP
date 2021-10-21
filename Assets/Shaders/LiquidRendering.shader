// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Liquid/Liquid Rendering"
{
    Properties
    {
       _MainTex("Source", 2D) = "white" {}
       _Depth("Source", 2D) = "white" {}
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

             Texture2D _Depth;
             float4 _Depth_TexelSize;

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
                 return ray * /*Linear01Depth(*/rawDepth/*)*/;
             }

             float4 fragmentShader(vertexOutput i) : COLOR
             {
                float2 uv = i.texcoord;
                float4 color = tex2D(_MainTex, uv);

                float3 vpl = viewSpacePosAtPixelPosition(i.vertex.xy + float2(-1, 0));
                float3 vpr = viewSpacePosAtPixelPosition(i.vertex.xy + float2(1, 0));
                float3 vpd = viewSpacePosAtPixelPosition(i.vertex.xy + float2(0, -1));
                float3 vpu = viewSpacePosAtPixelPosition(i.vertex.xy + float2(0, 1));

                float3 viewNormal = normalize(-cross(vpu - vpd, vpr - vpl));
                float3 WorldNormal = mul((float3x3)unity_MatrixInvV, viewNormal);

                float depth = _Depth.Load(int3(i.vertex.xy, 0)).r;
                //depth = Linear01Depth(depth);

                float3 thickness = color.a;

                return float4(WorldNormal.rgb,depth);
             }
             ENDCG
          }
       }
           Fallback Off
}
