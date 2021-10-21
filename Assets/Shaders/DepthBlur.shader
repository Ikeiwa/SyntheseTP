Shader "Hidden/DepthBlur"
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

            #define BSIGMA 0.1
			#define MSIZE 15

			const float kernel[MSIZE] = {0.031225216, 0.033322271, 0.035206333, 0.036826804, 0.038138565, 0.039104044, 0.039695028, 0.039894000, 0.039695028, 0.039104044, 0.038138565, 0.036826804, 0.035206333, 0.033322271, 0.031225216};


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

            sampler2D _CameraDepthTexture;

            float normpdf(in float x, in float sigma)
            {
                return 0.39894 * exp(-0.5 * x * x / (sigma * sigma)) / sigma;
            }


            float frag (v2f i) : SV_Target
            {
                float pixelDepth = tex2D(_CameraDepthTexture, i.uv).r;
				float finalDepth;

                return pixelDepth;

                if (pixelDepth <= 0.0f || pixelDepth >= 1) {
                    finalDepth = pixelDepth;
                }
                else {
                    const int kSize = (MSIZE - 1) / 2;
                    finalDepth = 0;

                    float Z = 0.0;

                    const float bZ = 1.0 / normpdf(0.0, BSIGMA);

                    for (int x = -kSize; x <= kSize; ++x)
                    {
                        for (int y = -kSize; y <= kSize; ++y)
                        {
                            float cc = tex2D(_CameraDepthTexture, i.uv + (float2(float(x), float(y)) / _ScreenParams.xy)).r;
                            float factor = normpdf(cc - pixelDepth, BSIGMA) * bZ * kernel[kSize + y] * kernel[kSize + x];
                            Z += factor;
                            finalDepth += factor * cc;

                        }
                    }

                    finalDepth /= Z;
                }


                return finalDepth;
            }
            ENDCG
        }
    }
}
