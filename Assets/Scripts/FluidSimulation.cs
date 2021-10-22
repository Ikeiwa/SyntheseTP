using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public class FluidSimulation : MonoBehaviour
{
    public int population;
    public Vector3 volume;
    [Range(0.01f,1)]
    public float particleRadius = 0.05f;
    [Range(0, 10)]
    public float simulationSpeed = 1;

    public Material material;
    public ComputeShader compute;
    private ComputeBuffer meshPropertiesBuffer;
    private ComputeBuffer argsBuffer;

    private Mesh mesh;
    private Bounds bounds;


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

    private void Setup() {
        Mesh mesh = CreateQuad(particleRadius*2, particleRadius*2);
        this.mesh = mesh;

        // Boundary surrounding the meshes we will be drawing.  Used for occlusion.
        bounds = new Bounds(transform.position, volume*2);
        material.SetFloat("_ParticleRadius", particleRadius);

        InitializeBuffers();
    }

    private void InitializeBuffers() {
        int kernel = compute.FindKernel("CSMain");

        // Argument buffer used by DrawMeshInstancedIndirect.
        uint[] args = new uint[5] { 0, 0, 0, 0, 0 };

        // Arguments for drawing mesh.
        // 0 == number of triangle indices, 1 == population, others are only relevant if drawing submeshes.
        args[0] = (uint)mesh.GetIndexCount(0);
        args[1] = (uint)population;
        args[2] = (uint)mesh.GetIndexStart(0);
        args[3] = (uint)mesh.GetBaseVertex(0);
        argsBuffer = new ComputeBuffer(1, args.Length * sizeof(uint), ComputeBufferType.IndirectArguments);
        argsBuffer.SetData(args);

        // Initialize buffer with the given population.
        Particle[] properties = new Particle[population];
        for (int i = 0; i < population; i++) {
            Particle props = new Particle();
            Vector3 position = new Vector3(Random.Range(-volume.x, volume.x), Random.Range(-volume.y, volume.y),Random.Range(-volume.z, volume.z));

            props.pos = position;
            props.vel = Vector3.zero;
            //props.color = Color.Lerp(Color.red, Color.blue, Random.value);
            props.color = Color.blue;

            properties[i] = props;
        }

        meshPropertiesBuffer = new ComputeBuffer(population, Particle.Size());
        meshPropertiesBuffer.SetData(properties);
        compute.SetVector("volume",volume);
        compute.SetBuffer(kernel, "Particles", meshPropertiesBuffer);
        material.SetBuffer("Particles", meshPropertiesBuffer);
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

    private void Update() {
        int kernel = compute.FindKernel("CSMain");

        compute.SetVector("_PusherPosition", Camera.main.transform.position);
        compute.SetFloat("timeDelta",Time.deltaTime/(1/ simulationSpeed));
        compute.Dispatch(kernel, Mathf.CeilToInt(population / 64f), 1, 1);

        Graphics.DrawMeshInstancedIndirect(mesh, 0, material, bounds, argsBuffer,0,null,ShadowCastingMode.On,false,gameObject.layer);
    }

    private void OnDestroy() {
        // Release gracefully.
        if (meshPropertiesBuffer != null) {
            meshPropertiesBuffer.Release();
        }
        meshPropertiesBuffer = null;

        if (argsBuffer != null) {
            argsBuffer.Release();
        }
        argsBuffer = null;
    }
}
