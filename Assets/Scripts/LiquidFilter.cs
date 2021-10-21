using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering;

public class LiquidFilter : MonoBehaviour
{
    public Material filterMaterial;
    public Material blurMaterial;

    private static readonly int Depth = Shader.PropertyToID("_Depth");

    void Start()
    {
        if (null == filterMaterial || null == filterMaterial.shader || !filterMaterial.shader.isSupported ||
            null == blurMaterial || null == blurMaterial.shader || !blurMaterial.shader.isSupported)
        {
            enabled = false;
            return;
        }
    }

    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        RenderTexture bluredDepth = RenderTexture.GetTemporary(source.width, source.height, source.depth, GraphicsFormat.R16_SFloat);
        Graphics.Blit(source, bluredDepth, blurMaterial);

        filterMaterial.SetTexture("_Depth",bluredDepth);
        Graphics.Blit(source, destination, filterMaterial);

        RenderTexture.ReleaseTemporary(bluredDepth);
    }
}
