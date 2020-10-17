Shader "Hidden/JumpFlood"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

		//initialize solid pixels
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
				float4 pos : SV_POSITION;
			};

			v2f vert(appdata v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				return o;
			}

			sampler2D _MainTex;

			float2 frag(v2f i) : SV_Target
			{
				//determine what is solid based on final alpha of rendered image
				bool isSolid = tex2D(_MainTex, i.uv).a > 0.000001;
				//use -10, -10 to indicate empty space
				return isSolid ? int2(i.pos.xy) : int2(-10, -10);
			}
			ENDCG
		}

		//jump flooding
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
                float4 pos : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            sampler2D _MainTex;

			int _JumpStride;

            float2 frag (v2f i) : SV_Target
            {
				float2 pixelCoord = i.pos.xy;
				float2 uvStride = (float)_JumpStride.xx / _ScreenParams.xy;

				int2 index = int2(-10, -10);
				float smallestDistance = 10000000000.0f;

				for (int x = -1; x <= 1; x++)
				{
					for (int y = -1; y <= 1; y++)
					{
						float2 sampleUV = i.uv + (uvStride * float2(x, y));

						//if this sample is in bounds
						if (sampleUV.x > 0.0 && sampleUV.y > 0.0 && sampleUV.x < 1.0 && sampleUV.y < 1.0)
						{
							//add 0.5 to sampled pixel index so the point is in the middle of the pixel
							float2 sampleIndex = tex2D(_MainTex, sampleUV).xy + 0.5;

							//if this index is valid
							if (sampleIndex.x >= 0 && sampleIndex.y >= 0 && sampleIndex.x < _ScreenParams.x && sampleIndex.y < _ScreenParams.y)
							{
								float sampleDistance = length(sampleIndex - pixelCoord);

								//set the output to the sampled pixel coord closest to this one
								if (sampleDistance < smallestDistance)
								{
									smallestDistance = sampleDistance;
									index = sampleIndex;
								}
							}
						}
					}
				}

				return index;
            }
            ENDCG
        }
		
		//generate distance field from jump flood output
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
				float4 pos : SV_POSITION;
			};

			v2f vert(appdata v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				return o;
			}

			sampler2D _MainTex;

			float frag(v2f i) : SV_Target
			{
				float2 pixelCoord = i.pos.xy;
				float2 sampledCoord = tex2D(_MainTex, i.uv).xy + 0.5;

				float distance = length(sampledCoord - pixelCoord);

				return distance;
			}
			ENDCG
		}
    }
}
