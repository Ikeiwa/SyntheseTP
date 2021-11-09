using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using Random = UnityEngine.Random;

public class FluidSimulation : MonoBehaviour
{
    public Texture3D initialColors;
    public ComputeShader updateCompute;
    [Space]
    public int maxParticles = 100000;
    public Vector3 volume;
    [Range(0.01f, 1)] public float particleVisualRadius = 0.05f;
    [Range(1, 100)] public float particleElasticity = 5;
    [Space]
    

    [Header("Simulation Settings")]
    [Header("World")]
    [Range(0, 10)] public float simulationSpeed = 1;
    public Vector3 gravity = new Vector3(0, -9.81f, 0);
    [Range(0, 100)] public float spring = 1;
    [Range(0.01f, 1)] public float particleRadius = 0.05f;
    [Header("Density")]
    public float density = 1;
    public float stiffness = 0.1f;
    [Header("Viscosity")]
    public float omega = 1;
    public float beta = 0.1f;

    private Material particleMaterial;
    private ComputeBuffer positionBuffer;
    private ComputeBuffer oldPositionBuffer;
    private ComputeBuffer velocityBuffer;
    private ComputeBuffer colorBuffer;
    private ComputeBuffer argsBuffer;

    private Mesh mesh;
    private Bounds bounds;


    private int gravityKernel;
    private int viscosityKernel;
    private int movementKernel;
    private int relaxationKernel;
    private int finalVelKernel;


    private uint[] args = new uint[5] { 0, 0, 0, 0, 0 };

    private struct Particle {
        public Vector3 pos;
        public Vector3 vel;
        public Vector4 color;

        public static int Size() {
            return
                sizeof(float) * 3 + // pos;
                sizeof(float) * 3 + // vel;
                sizeof(float) * 4;      // color;
        }
    }

    private Vector3[] positionArray;
    private Vector3[] oldPositionArray;
    private Vector3[] velocityArray;
    private Vector4[] colorArray;

    private void Setup() {
        Mesh mesh = CreateQuad(1, 1);
        this.mesh = mesh;

        // Boundary surrounding the meshes we will be drawing.  Used for occlusion.
        bounds = new Bounds(transform.position, volume*2);
        particleMaterial = new Material(Shader.Find("Hidden/Fluid Particle"));

        InitializeBuffers();
    }

    private void SetKernelBuffers(int kernel)
    {
        updateCompute.SetBuffer(kernel, "ParticlesPos", positionBuffer);
        updateCompute.SetBuffer(kernel, "ParticlesOldPos", oldPositionBuffer);
        updateCompute.SetBuffer(kernel, "ParticlesVel", velocityBuffer);
        updateCompute.SetBuffer(kernel, "ParticlesCol", colorBuffer);
    }

    public void ResetSimulation()
    {
        // Initialize buffer with the given population.
        positionArray = new Vector3[maxParticles];
        oldPositionArray = new Vector3[maxParticles];
        velocityArray = new Vector3[maxParticles];
        colorArray = new Vector4[maxParticles];

        for (int i = 0; i < maxParticles; i++)
        {
            Vector3 position = new Vector3(Random.Range(0, volume.x), Random.Range(0, volume.y), Random.Range(0, volume.z));

            Vector3 velocity = Vector3.zero;
            //props.color = Color.Lerp(Color.red, Color.blue, Random.value);

            Vector3 pos = position + volume;
            pos.x /= volume.x * 2;
            pos.y /= volume.y * 2;
            pos.z /= volume.z * 2;

            Vector4 color = initialColors.GetPixel((int)(pos.x * initialColors.width),
                (int)(pos.y * initialColors.height),
                (int)(pos.z * initialColors.depth));

            positionArray[i] = position;
            oldPositionArray[i] = position;
            velocityArray[i] = velocity;
            colorArray[i] = color;
        }

        positionBuffer.SetData(positionArray);
        oldPositionBuffer.SetData(oldPositionArray);
        velocityBuffer.SetData(velocityArray);
        colorBuffer.SetData(colorArray);
    }

    private void InitializeBuffers() {
        gravityKernel = updateCompute.FindKernel("ApplyGravity");
        viscosityKernel = updateCompute.FindKernel("ApplyViscosity");
        movementKernel = updateCompute.FindKernel("ApplyMovement");
        relaxationKernel = updateCompute.FindKernel("DoubleRelaxation");
        finalVelKernel = updateCompute.FindKernel("UpdateFinalVel");

        // Arguments for drawing mesh.
        // 0 == number of triangle indices, 1 == population, others are only relevant if drawing submeshes.
        args[0] = (uint)mesh.GetIndexCount(0);
        args[1] = (uint)maxParticles;
        args[2] = (uint)mesh.GetIndexStart(0);
        args[3] = (uint)mesh.GetBaseVertex(0);
        argsBuffer = new ComputeBuffer(1, args.Length * sizeof(uint), ComputeBufferType.IndirectArguments);
        argsBuffer.SetData(args);

        positionBuffer = new ComputeBuffer(maxParticles, sizeof(float)*3);
        oldPositionBuffer = new ComputeBuffer(maxParticles, sizeof(float)*3);
        velocityBuffer = new ComputeBuffer(maxParticles, sizeof(float)*3);
        colorBuffer = new ComputeBuffer(maxParticles, sizeof(float) * 4);

        ResetSimulation();
        
        updateCompute.SetVector("volume",volume);
        updateCompute.SetInt("particleCount",maxParticles);

        SetKernelBuffers(gravityKernel);
        SetKernelBuffers(viscosityKernel);
        SetKernelBuffers(movementKernel);
        SetKernelBuffers(relaxationKernel);
        SetKernelBuffers(finalVelKernel);

        particleMaterial.SetBuffer("ParticlesPos", positionBuffer);
        particleMaterial.SetBuffer("ParticlesOldPos", oldPositionBuffer);
        particleMaterial.SetBuffer("ParticlesVel", velocityBuffer);
        particleMaterial.SetBuffer("ParticlesCol", colorBuffer);
    }

    private Mesh CreateQuad(float width = 1f, float height = 1f) {
        var mesh = new Mesh();

        float w = width * .5f;
        float h = height * .5f;
        var vertices = new Vector3[4] {
            new Vector3(-w, -h, 0),
            new Vector3(w, -h, 0),
            new Vector3(-w, h, 0),
            new Vector3(w, h, 0)
        };

        var tris = new int[6] {
            0, 2, 1,
            2, 3, 1
        };

        var uv = new Vector2[4] {
            new Vector2(0, 0),
            new Vector2(1, 0),
            new Vector2(0, 1),
            new Vector2(1, 1),
        };

        mesh.vertices = vertices;
        mesh.triangles = tris;
        mesh.uv = uv;

        return mesh;
    }

    private void Start() {
        Setup();
    }

    private void FixedUpdate() {

        updateCompute.SetVector("gravity",gravity);
        updateCompute.SetFloat("particleRadius", (particleRadius*2)*(particleRadius*2));
        updateCompute.SetFloat("stiffness", stiffness);
        updateCompute.SetFloat("density",density);
        updateCompute.SetFloat("omega",omega);
        updateCompute.SetFloat("beta", beta);
        updateCompute.SetFloat("springForce", spring);
        updateCompute.SetFloat("timeDelta",Time.fixedDeltaTime/(1/ simulationSpeed));

        updateCompute.Dispatch(gravityKernel, Mathf.CeilToInt(maxParticles / 64f), 1, 1);
        updateCompute.Dispatch(viscosityKernel, Mathf.CeilToInt(maxParticles / 64f), 1, 1);
        updateCompute.Dispatch(movementKernel, Mathf.CeilToInt(maxParticles / 64f), 1, 1);
        updateCompute.Dispatch(relaxationKernel, Mathf.CeilToInt(maxParticles / 64f), 1, 1);
        updateCompute.Dispatch(finalVelKernel, Mathf.CeilToInt(maxParticles / 64f), 1, 1);
    }

    private void Update()
    {
        if(Input.GetKeyDown(KeyCode.R))
            ResetSimulation();

        particleMaterial.SetFloat("_ParticleRadius", particleVisualRadius);
        particleMaterial.SetFloat("_Elasticity", particleElasticity);

        Graphics.DrawMeshInstancedIndirect(mesh, 0, particleMaterial, bounds, argsBuffer, 0, null, ShadowCastingMode.On, false, gameObject.layer);
    }

    private void OnDestroy() {
        // Release gracefully.
        positionBuffer.Release();
        oldPositionBuffer.Release();
        velocityBuffer.Release();
        colorBuffer.Release();

        if (argsBuffer != null) {
            argsBuffer.Release();
        }
        argsBuffer = null;
    }

    private void OnDrawGizmos()
    {
        Gizmos.color = Color.red;
        Gizmos.DrawWireCube(transform.position,volume*2);
    }
}
