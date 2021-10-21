Shader "Hidden/DepthBlur"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    	_ParticleRadius ("Particle Radius",Float) = 0.05
        _FilterSize ("Filter Size", Int) = 5
        _MaxFilterSize("Max Filter Size", Int) = 25
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

            sampler2D _CameraDepthTexture;
            float _ParticleRadius;
            int _FilterSize;
            int _MaxFilterSize;

            const float thresholdRatio = 10.0;

            float compute_weight2D(float2 r, float two_sigma2)
            {
                return exp(-dot(r, r) / two_sigma2);
            }

            float compute_weight1D(float r, float two_sigma2)
            {
                return exp(-r * r / two_sigma2);
            }

            float frag (v2f i) : SV_Target
            {
                float2 blurRadius = 1.0 / _ScreenParams.xy;

                float pixelDepth = tex2D(_CameraDepthTexture, i.uv).r;
                pixelDepth = Linear01Depth(pixelDepth);
                pixelDepth = pixelDepth * _ProjectionParams.z;
				float finalDepth;

                if (pixelDepth <= 0.0f || pixelDepth >= _ProjectionParams.z) {
                    finalDepth = pixelDepth;
                }
                else {
                    float ratio = _ScreenParams.y / 2.0 / tan(45.0 / 2.0);
                    float K = -_FilterSize * ratio * _ParticleRadius * 0.1f;
                    int   filterSize = min(_MaxFilterSize, int(ceil(K / pixelDepth)));
                    filterSize = _FilterSize;
                    float sigma = filterSize / 3.0f;
                    float two_sigma2 = 2.0f * sigma * sigma;

                    float threshold = _ParticleRadius * thresholdRatio;
                    float sigmaDepth = threshold / 3.0f;
                    float two_sigmaDepth2 = 2.0f * sigmaDepth * sigmaDepth;
                     
                    float4 f_tex = i.uv.xyxy;
                    float2 r = float2(0, 0);
                    float4 sum4 = float4(pixelDepth, 0, 0, 0);
                    float4 wsum4 = float4(1, 0, 0, 0);

                    for (int x = 1; x <= 5; ++x) {
                        r.x += blurRadius.x;
                        f_tex.x += blurRadius.x;
                        f_tex.z -= blurRadius.x;
                        float4 f_tex1 = f_tex.xyxy;
                        float4 f_tex2 = f_tex.zwzw;

                        for (int y = 1; y <= 5; ++y) {
	                        float4 w4_depth;
	                        float4 sampleDepth;
	                        r.y += blurRadius.y;

                            f_tex1.y += blurRadius.y;
                            f_tex1.w -= blurRadius.y;
                            f_tex2.y += blurRadius.y;
                            f_tex2.w -= blurRadius.y;

                            sampleDepth.x = tex2D(_CameraDepthTexture, f_tex1.xy).r;
                            sampleDepth.y = tex2D(_CameraDepthTexture, f_tex1.zw).r;
                            sampleDepth.z = tex2D(_CameraDepthTexture, f_tex2.xy).r;
                            sampleDepth.w = tex2D(_CameraDepthTexture, f_tex2.zw).r;

                            float4 rDepth = sampleDepth - pixelDepth;
                            float4 w4_r = compute_weight2D(blurRadius * r, two_sigma2);
                            w4_depth.x = compute_weight1D(rDepth.x, two_sigmaDepth2);
                            w4_depth.y = compute_weight1D(rDepth.y, two_sigmaDepth2);
                            w4_depth.z = compute_weight1D(rDepth.z, two_sigmaDepth2);
                            w4_depth.w = compute_weight1D(rDepth.w, two_sigmaDepth2);

                            sum4 += sampleDepth * w4_r * w4_depth;
                            wsum4 += w4_r * w4_depth;
                        }
                    }

                    float2 filterVal;
                    filterVal.x = dot(sum4, float4(1, 1, 1, 1));
                    filterVal.y = dot(wsum4, float4(1, 1, 1, 1));

                    finalDepth = filterVal.x / filterVal.y;
                }


                return finalDepth / _ProjectionParams.z;
            }
            ENDCG
        }
    }
}
