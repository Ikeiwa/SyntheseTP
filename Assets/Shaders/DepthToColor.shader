Shader "Hidden/Compute Liquid Data"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        // No culling or depth
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
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            sampler2D_float _MainTex;
            float4 _MainTex_TexelSize;

            sampler2D_float _CameraDepthTexture;
            float4 _CameraDepthTexture_TexelSize;

            float _FluidDensity;

            float getRawDepth(float2 uv) { return SAMPLE_DEPTH_TEXTURE_LOD(_CameraDepthTexture, float4(uv, 0.0, 0.0)); }

            float2 frag(v2f i) : SV_Target
            {
                float2 uv = i.vertex * _CameraDepthTexture_TexelSize.xy;

                float thickness = tex2Dlod(_MainTex,float4(uv, 0.0, 0.0)).a;
                
                return float2(Linear01Depth(getRawDepth(uv)), thickness);
            }
            ENDCG
        }
    }
}
