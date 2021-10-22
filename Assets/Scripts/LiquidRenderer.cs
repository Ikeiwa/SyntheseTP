using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering;

[RequireComponent(typeof(Camera))]
public class LiquidRenderer : MonoBehaviour
{
    public Material material;
    public Material colorCopy;
    public LiquidFilter liquidFilter;

    private RenderTexture liquidTexture;

    void Start()
    {
        Camera cam = GetComponent<Camera>();
        cam.depthTextureMode |= DepthTextureMode.Depth;
        Camera liquidCam = liquidFilter.gameObject.GetComponent<Camera>();
        liquidCam.depthTextureMode |= DepthTextureMode.Depth;

        liquidTexture = new RenderTexture(Screen.width, Screen.height, 32, GraphicsFormat.R16G16B16A16_SFloat);
        liquidTexture.depth = 16;
        liquidTexture.filterMode = FilterMode.Bilinear;
        liquidCam.targetTexture = liquidTexture;
        liquidFilter.bluredDepth = new RenderTexture(liquidTexture.width, liquidTexture.height, liquidTexture.depth, GraphicsFormat.R16G16_SFloat);
        liquidFilter.backgroundTexture = new RenderTexture(Screen.width,Screen.height,16,cam.allowHDR? DefaultFormat.HDR:DefaultFormat.LDR);

        material.SetTexture("_LiquidTex", liquidTexture);
        material.SetTexture("_LiquidDepth", liquidFilter.bluredDepth);

        if (null == material || null == material.shader ||
            !material.shader.isSupported)
        {
            enabled = false;
            return;
        }
    }

    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        Graphics.Blit(source, liquidFilter.backgroundTexture, colorCopy);
        Graphics.Blit(source, destination, material);
    }
}
