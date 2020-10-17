using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Lightmanager2D : MonoBehaviour
{
    private Camera m_camera;

    private static readonly int m_maxLights = 256;
    private Vector4[] m_lightData = new Vector4[m_maxLights];
    private Vector4[] m_lightColors = new Vector4[m_maxLights];

    // Start is called before the first frame update
    void Start()
    {
        m_camera = GetComponent<Camera>();
        
        //initilize light values
        for(int i = 0; i < m_maxLights; i++)
        {
            m_lightData[i] = Vector4.zero;
        }

        Shader.SetGlobalFloat("_PixelsPerUnit", 1.0f);
        Shader.SetGlobalInt("_2DLightCount", 0);
        Shader.SetGlobalVectorArray("_2DLightData", m_lightData);
        Shader.SetGlobalVectorArray("_2DLightColors", m_lightColors);
    }

    // Update is called once per frame
    void Update()
    {
        if(m_camera != null)
        {
            //get all the lights in the scene
            Light2D[] lights = FindObjectsOfType<Light2D>();
            int numLights = lights.Length;
            if(numLights > m_maxLights)
            {
                numLights = m_maxLights;
            }

            //load their data into intermediate arrays
            for (int i = 0; i < numLights; i++)
            {
                m_lightData[i] = m_camera.WorldToScreenPoint(lights[i].transform.position);
                m_lightData[i].z = lights[i].m_radius;

                m_lightColors[i] = lights[i].m_color;
            }

            //send that data to the GPU
            Shader.SetGlobalFloat("_PixelsPerUnit", Screen.height / (m_camera.orthographicSize * 2));
            Shader.SetGlobalInt("_2DLightCount", numLights);
            Shader.SetGlobalVectorArray("_2DLightData", m_lightData);
            Shader.SetGlobalVectorArray("_2DLightColors", m_lightColors);
        }
    }
}
