// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Liquid/Liquid Display"
{
    Properties
    {
       _MainTex("Source", 2D) = "white" {}
       _LiquidTex("Liquid Texture",2D) = "white" {}
       _LiquidDepth("Liquid Depth",2D) = "white" {}
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
             sampler2D_float _CameraDepthTexture;
             float4 _CameraDepthTexture_TexelSize;
             sampler2D_float _LiquidDepth;
             float4 _LiquidDepth_TexelSize;

             float getRawDepth(float2 uv) { return SAMPLE_DEPTH_TEXTURE_LOD(_CameraDepthTexture, float4(uv, 0.0, 0.0)); }

             float4 fragmentShader(vertexOutput i) : COLOR
             {
                float2 uv = i.texcoord;
                float4 color = tex2D(_MainTex, uv);
                float4 liquid = tex2D(_LiquidTex, uv);

                float depth = tex2D(_CameraDepthTexture,uv);
                depth = Linear01Depth(depth);

                float liquidDepth = tex2D(_LiquidDepth, uv).r;
                liquidDepth = Linear01Depth(liquidDepth);

                float mask = saturate(sign(depth - liquidDepth));


                return lerp(color, lerp(color,liquid,1), mask);
             }
             ENDCG
          }
       }
           Fallback Off
}
