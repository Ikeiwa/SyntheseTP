using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering;

public class LiquidFilter : MonoBehaviour
{
    public Material filterMaterial;
    public bool smoothRendering = true;
    [HideInInspector] public RenderTexture bluredDepth;
    [HideInInspector] public RenderTexture backgroundTexture;

    private Camera cam;
    private Material depthCopyMaterial;
    private Material blurMaterial;

    private static readonly int Depth = Shader.PropertyToID("_Depth");
    private static readonly int UnityMatrixIv = Shader.PropertyToID("UNITY_MATRIX_IV");
    private static readonly int Background = Shader.PropertyToID("_Background");

    void Awake()
    {
        if (null == filterMaterial || null == filterMaterial.shader || !filterMaterial.shader.isSupported)
        {
            enabled = false;
            return;
        }

        depthCopyMaterial = new Material(Shader.Find("Hidden/Compute Liquid Data"));
        blurMaterial = new Material(Shader.Find("Hidden/DepthBlur"));

        cam = GetComponent<Camera>();
    }

    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        RenderTexture tmpDepth = RenderTexture.GetTemporary(bluredDepth.width,bluredDepth.height,bluredDepth.depth,bluredDepth.graphicsFormat);
        Graphics.Blit(source, bluredDepth, depthCopyMaterial);

        if (smoothRendering)
        {
            Graphics.Blit(bluredDepth, tmpDepth, blurMaterial);
            Graphics.Blit(tmpDepth, bluredDepth, blurMaterial);
            Graphics.Blit(bluredDepth, tmpDepth, blurMaterial);
            Graphics.Blit(tmpDepth, bluredDepth, blurMaterial);
        }

        filterMaterial.SetMatrix(UnityMatrixIv, transform.localToWorldMatrix);
        filterMaterial.SetTexture(Depth,bluredDepth);
        filterMaterial.SetTexture(Background, backgroundTexture);
        Graphics.Blit(source, destination, filterMaterial);

        RenderTexture.ReleaseTemporary(tmpDepth);
    }
}
