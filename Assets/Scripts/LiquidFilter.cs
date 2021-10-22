using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering;

public class LiquidFilter : MonoBehaviour
{
    public Material filterMaterial;
    public Material blurMaterial;
    [HideInInspector]
    public RenderTexture bluredDepth;

    private Camera cam;
    
    private static readonly int Depth = Shader.PropertyToID("_Depth");
    private static readonly int UnityMatrixIv = Shader.PropertyToID("UNITY_MATRIX_IV");

    void Start()
    {
        if (null == filterMaterial || null == filterMaterial.shader || !filterMaterial.shader.isSupported ||
            null == blurMaterial || null == blurMaterial.shader || !blurMaterial.shader.isSupported)
        {
            enabled = false;
            return;
        }

        cam = GetComponent<Camera>();
    }

    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        Graphics.Blit(source, bluredDepth, blurMaterial);

        filterMaterial.SetMatrix(UnityMatrixIv, transform.localToWorldMatrix);
        filterMaterial.SetTexture(Depth,bluredDepth);
        Graphics.Blit(source, destination, filterMaterial);
    }
}
