﻿Shader "2D/VoronoiVisualization"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

			sampler2D _ScreenClosestPointBuffer;
            sampler2D _MainTex;

            float4 frag (v2f i) : SV_Target
            {
				float2 uvOfNearest = (tex2D(_ScreenClosestPointBuffer, i.uv).xy + 0.5f) / _ScreenParams.xy;

				if (uvOfNearest.x < 0.0 || uvOfNearest.y < 0.0 || uvOfNearest.x > 1.0 || uvOfNearest.y > 1.0)
				{
					return 0.0;
				}

				return tex2D(_MainTex, uvOfNearest);
            }
            ENDCG
        }
    }
}
