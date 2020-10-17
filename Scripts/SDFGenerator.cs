using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System;

public class SDFGenerator : MonoBehaviour
{
    public Shader m_JumpFloodShader;
    public int m_debugMaxIterations = 100;
    public bool m_debugAnimateIterations = false;
    public Material m_FinalRenderingMaterial;
    
    private Camera m_camera;
    private Vector2Int m_ScreenSize;
    private RenderTexture m_NearestPointBufferA;
    private RenderTexture m_NearestPointBufferB;
    private RenderTexture m_DistanceFieldTexture;
    private Material m_JumpFloodMaterial;

    // Start is called before the first frame update
    void Start()
    {
        m_camera = GetComponent<Camera>();
        m_JumpFloodMaterial = new Material(m_JumpFloodShader);
    }

    // Update is called once per frame
    void Update()
    {
        
    }

    void UpdateTextureSize(Vector2Int newSize)
    {
        bool needsRebuild = m_ScreenSize.x != newSize.x || m_ScreenSize.y != newSize.y;
        m_ScreenSize = newSize;

        RenderTextureDescriptor rtDescNearest = new RenderTextureDescriptor(newSize.x, newSize.y, RenderTextureFormat.RGInt, 0, 0);
        RenderTextureDescriptor rtDescDistanceField = new RenderTextureDescriptor(newSize.x, newSize.y, RenderTextureFormat.RFloat, 0, 0);

        if (needsRebuild || m_NearestPointBufferA == null)
        {
            if(m_NearestPointBufferA != null)
            {
                m_NearestPointBufferA.Release();
            }

            m_NearestPointBufferA = new RenderTexture(rtDescNearest);
            m_NearestPointBufferA.filterMode = FilterMode.Point;
            m_NearestPointBufferA.Create();
        }

        if (needsRebuild || m_NearestPointBufferB == null)
        {
            if (m_NearestPointBufferB != null)
            {
                m_NearestPointBufferB.Release();
            }

            m_NearestPointBufferB = new RenderTexture(rtDescNearest);
            m_NearestPointBufferB.filterMode = FilterMode.Point;
            m_NearestPointBufferB.Create();
        }

        if(needsRebuild || m_DistanceFieldTexture == null)
        {
            if (m_DistanceFieldTexture != null)
            {
                m_DistanceFieldTexture.Release();
            }

            m_DistanceFieldTexture = new RenderTexture(rtDescDistanceField);
            m_DistanceFieldTexture.filterMode = FilterMode.Bilinear;
            m_DistanceFieldTexture.Create();
        }
    }

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        UpdateTextureSize(new Vector2Int(Screen.width, Screen.height));
        int startingStride = Mathf.NextPowerOfTwo(Math.Max(Screen.width, Screen.height)) / 2;

        //for debug visualization
        int capIterationsAt = 0;
        if(m_debugAnimateIterations)
        {
            capIterationsAt = (int)Time.time % (m_debugMaxIterations + 1);
        }
        else
        {
            capIterationsAt = m_debugMaxIterations;
        }

        if(m_JumpFloodMaterial != null)
        {
            //inititlize the jump flood
            Graphics.Blit(source, m_NearestPointBufferA, m_JumpFloodMaterial, 0);

            //do the jump flood iterations back and forth between the two buffers
            bool doesBHaveNewest = false;
            for(int stride = startingStride, i = 0; stride > 0 && i < capIterationsAt; stride /= 2, i++)
            {
                m_JumpFloodMaterial.SetInt("_JumpStride", stride);

                if (doesBHaveNewest)
                {
                    Graphics.Blit(m_NearestPointBufferB, m_NearestPointBufferA, m_JumpFloodMaterial, 1);
                }
                else
                {
                    Graphics.Blit(m_NearestPointBufferA, m_NearestPointBufferB, m_JumpFloodMaterial, 1);
                }

                doesBHaveNewest = !doesBHaveNewest;
            }

            //output the final distancce field
            if(doesBHaveNewest)
            {
                Graphics.Blit(m_NearestPointBufferB, m_DistanceFieldTexture, m_JumpFloodMaterial, 2);
                Shader.SetGlobalTexture("_ScreenClosestPointBuffer", m_NearestPointBufferB);
            }
            else
            {
                Graphics.Blit(m_NearestPointBufferA, m_DistanceFieldTexture, m_JumpFloodMaterial, 2);
                Shader.SetGlobalTexture("_ScreenClosestPointBuffer", m_NearestPointBufferA);
            }

            Shader.SetGlobalTexture("_ScreenDistanceFieldBuffer", m_DistanceFieldTexture);
        }

        //do the final blit and render something using our generated distance field
        if(m_JumpFloodMaterial != null && m_FinalRenderingMaterial != null)
        {
            Graphics.Blit(source, destination, m_FinalRenderingMaterial);
        }
        else
        {
            Graphics.Blit(source, destination);
        }
    }
}
