using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

#if UNITY_EDITOR
using UnityEditor;
#endif

public class IKArm : MonoBehaviour
{
    public Vector3[] points;
    public Vector3 target;
    public Vector3 pole;

    [Range(1,10)] public int iterations = 1;
    [Range(0, 180)] public float constraintAngle = 45;

    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        
    }

    private void GizmosDrawCone(Vector3 position, Vector3 direction, float angle = 45, float length = 0.5f)
    {
        Matrix4x4 originalMatGizmos = Gizmos.matrix;
        Matrix4x4 originalMatHandles = Handles.matrix;

        Matrix4x4 trs = Matrix4x4.TRS(position,Quaternion.LookRotation(direction),Vector3.one );
        Gizmos.matrix = trs;
        Handles.matrix = trs;

        float size = Mathf.Cos(angle*Mathf.Deg2Rad);
        float radius = (Quaternion.AngleAxis(constraintAngle, Vector3.right) * Vector3.forward * length).y;

        Gizmos.DrawRay(Vector3.zero, Quaternion.AngleAxis(constraintAngle,Vector3.right)*Vector3.forward*length);
        Gizmos.DrawRay(Vector3.zero, Quaternion.AngleAxis(-constraintAngle,Vector3.right)*Vector3.forward*length);
        Gizmos.DrawRay(Vector3.zero, Quaternion.AngleAxis(constraintAngle,Vector3.up)*Vector3.forward*length);
        Gizmos.DrawRay(Vector3.zero, Quaternion.AngleAxis(-constraintAngle,Vector3.up)*Vector3.forward*length);

        Handles.CircleHandleCap(0,Vector3.forward*length*size,Quaternion.identity, radius,EventType.Repaint );

        Gizmos.matrix = originalMatGizmos;
        Handles.matrix = originalMatHandles;
    }

    private void OnDrawGizmos()
    {
        Gizmos.color = Color.red;
        for (int i = 0; i < points.Length-1; i++)
        {
            Gizmos.DrawSphere(points[i],0.025f);
            Gizmos.DrawLine(points[i],points[i+1]);
        }
        Gizmos.DrawSphere(points[points.Length-1],0.025f);
        
        Gizmos.color = Color.green;
        Handles.color = Color.green;
        Gizmos.DrawSphere(target,0.025f);

        float size = Mathf.Cos(constraintAngle*Mathf.Deg2Rad);

        for (int i = 1; i < points.Length-1; i++)
        {
            Gizmos.color = Color.green;
            Handles.color = Color.green;
            Vector3 dir = (points[i] - points[i + 1])*0.25f;
            GizmosDrawCone(points[i],dir,constraintAngle,dir.magnitude);

            Gizmos.color = Color.blue;
            Handles.color = Color.blue;
            dir = (points[i] - points[i - 1])*0.25f;
            GizmosDrawCone(points[i],dir,constraintAngle,dir.magnitude);
        }
    }

    [ContextMenu("Reset")]
    public void Reset()
    {
        for (int i = 0; i < points.Length; i++)
        {
            points[i] = new Vector3(0, 0, i);
        }
    }

    private Vector3 ClampInCone(Vector3 dir, Vector3 coneDir, float angle)
    {
        float length = dir.magnitude;

        Vector3 axis = Vector3.Cross(coneDir, dir).normalized;
        Vector3 newDir = Quaternion.AngleAxis(angle,axis) * coneDir;

        return newDir.normalized * length;
    }

    [ContextMenu("Update Points")]
    public void UpdatePoints()
    {
        float constAngle = Mathf.Cos(constraintAngle * Mathf.Deg2Rad);

        Vector3[] newPoints = new Vector3[points.Length];
        points.CopyTo(newPoints,0);

        if (points.Length % 2 == 0)
        {
            int middleIndex = Mathf.FloorToInt((float)points.Length / 2.0f);
            Vector3 middle = newPoints[middleIndex] + ((newPoints[middleIndex + 1] - newPoints[middleIndex]) / 2.0f);
            Vector3 offset = pole - middle;

            newPoints[middleIndex] += offset;
            newPoints[middleIndex+1] += offset;
        }
        else
        {
            int middleIndex = Mathf.FloorToInt((float)points.Length / 2.0f);
            Vector3 offset = pole - newPoints[middleIndex];

            newPoints[middleIndex] += offset;
        }
        

        for (int i = 0; i < iterations; i++)
        {
            newPoints[newPoints.Length - 1] = target;

            for (int p = points.Length - 2; p >= 0; p--)
            {
                newPoints[p] =  newPoints[p + 1] + ((newPoints[p] - newPoints[p + 1]).normalized * (points[p] - points[p + 1]).magnitude);
                
                if (p < points.Length-2)
                {
                    Vector3 lineDir = newPoints[p] - newPoints[p + 1];
                    Vector3 coneDir = newPoints[p + 1] - newPoints[p + 2];

                    if(Vector3.Dot(lineDir,coneDir)<constAngle)
                        newPoints[p] = newPoints[p + 1] + ClampInCone(lineDir, coneDir, constraintAngle);
                }
            }

            newPoints[0] = points[0];

            for (int p = 1; p < points.Length; p++)
            {
                newPoints[p] = newPoints[p - 1] +  ((newPoints[p] - newPoints[p - 1]).normalized * (points[p] - points[p - 1]).magnitude);

                if (p > 1)
                {
                    Vector3 lineDir = newPoints[p] - newPoints[p - 1];
                    Vector3 coneDir = newPoints[p - 1] - newPoints[p - 2];

                    if(Vector3.Dot(lineDir,coneDir)<constAngle)
                        newPoints[p] = newPoints[p - 1] + ClampInCone(lineDir, coneDir, constraintAngle);
                }
            }
        }

        newPoints.CopyTo(points,0);
        points = newPoints;
    }
}

#if UNITY_EDITOR
[CustomEditor(typeof(IKArm))]
public class IKArmDrawer : Editor
{

    void OnSceneGUI()
    {
        IKArm curve = (IKArm)target;

        Handles.color = Color.green;
        Handles.SphereHandleCap(0,curve.target,Quaternion.identity, 0.1f, EventType.Repaint);
        curve.target = Handles.PositionHandle(curve.target, Quaternion.identity);

        Handles.color = Color.blue;
        Handles.SphereHandleCap(0,curve.pole,Quaternion.identity, 0.1f, EventType.Repaint);
        curve.pole = Handles.PositionHandle(curve.pole, Quaternion.identity);

        curve.UpdatePoints();
    }
}
#endif
