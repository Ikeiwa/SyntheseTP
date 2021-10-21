using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering;

[RequireComponent(typeof(Camera))]
public class LiquidRenderer : MonoBehaviour
{
    public Material material;
    public Camera liquidCam;

    private RenderTexture liquidTexture;

    void Start()
    {
        Camera cam = GetComponent<Camera>();
        cam.depthTextureMode |= DepthTextureMode.Depth;
        liquidCam.depthTextureMode |= DepthTextureMode.Depth;

        liquidTexture = new RenderTexture(Screen.width, Screen.height, 32, GraphicsFormat.R16G16B16A16_SFloat);
        liquidTexture.depth = 16;
        liquidTexture.filterMode = FilterMode.Point;
        liquidCam.targetTexture = liquidTexture;
        
        material.SetTexture("_LiquidTex", liquidTexture);

        if (null == material || null == material.shader ||
            !material.shader.isSupported)
        {
            enabled = false;
            return;
        }
    }

    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        Graphics.Blit(source, destination, material);
    }
}
