Shader "2D/SDFLighting"
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
			#define EPS 0.0001

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
			sampler2D _ScreenDistanceFieldBuffer;
			sampler2D _ScreenClosestPointBuffer;

			static const uint MAX_LIGHTS = 256;
			float _PixelsPerUnit;
			int _2DLightCount;
			float4 _2DLightData[MAX_LIGHTS]; //xy = pixel position, z = radius
			float4 _2DLightColors[MAX_LIGHTS];

			/*
			 * Circular light light attenuation
			 * Converges to (1 / distanceToLight) as lightRadius aproaches 0
			 * need to divide by light radius to conserve total energy as light gets bigger
			*/
			float GetLightAtten(float distanceToLight, float lightRadius)
			{
				lightRadius = max(0.005, lightRadius); //clamp light radius at a small value to avoid point light singularity
				return asin(saturate(lightRadius / distanceToLight)) / lightRadius;
			}

			//version using distance field only, suffers from ringing artifacts
			float GetSoftShadowOld(float2 pixelPos, float2 dirToLight, float pixelDistanceToLight, float pixelLightRadius)
			{
				float shadowFactor = 1.0;
				float currentDistance = 0.0f;

				for (int i = 0; i < 100; i++)
				{
					float2 sampleUV = (pixelPos + dirToLight * currentDistance) / _ScreenParams.xy;
					float distanceToNearestPoint = max(0.0, tex2Dlod(_ScreenDistanceFieldBuffer, float4(sampleUV, 0, 0)).r);

					float distancePercentage = saturate(currentDistance / pixelDistanceToLight);
					float occlusionRadius = pixelLightRadius * distancePercentage;
					float occlusion = occlusionRadius > 0.001 ? saturate(distanceToNearestPoint / occlusionRadius) : 1.0;
					shadowFactor = min(shadowFactor, occlusion);

					currentDistance += distanceToNearestPoint;

					if (currentDistance >= pixelDistanceToLight)
					{
						return shadowFactor;
					}
				}

				return 0.0;
			}

			//fixed some ringing issues by using closest point instead of just distance
			float GetSoftShadow(float2 pixelPos, float2 dirToLight, float pixelDistanceToLight, float pixelLightRadius)
			{
				float shadowFactor = 1.0;
				float currentDistance = 0.0f;

				float2 lightScreenUV = (pixelPos + dirToLight * pixelDistanceToLight) / _ScreenParams.xy;
				float lightDistanceFromWall = tex2Dlod(_ScreenDistanceFieldBuffer, float4(lightScreenUV, 0, 0)).r;

				//if the light is right next to a wall don't draw it to avoid artifacts
				if (lightDistanceFromWall < 1.0)
				{
					return 0.0;
				}

				//shrink radius if light is intersecting wall to avoid artifacts
				pixelLightRadius = min(pixelLightRadius, lightDistanceFromWall); 

				for (int i = 0; i < 100; i++)
				{
					float2 currentPos = pixelPos + dirToLight * currentDistance;
					float2 sampleUV = currentPos / _ScreenParams.xy;

					float2 nearestPoint = tex2Dlod(_ScreenClosestPointBuffer, float4(sampleUV, 0, 0)).xy + 0.5f;
					float distanceToNearestPoint = length(nearestPoint - currentPos);

					//force a hard shadow if the marching step comes close enough to a wall
					if (distanceToNearestPoint < 0.5)
					{
						return 0;
					}

					float2 toOccPoint = nearestPoint - pixelPos;
					float percentToLightAtOcc = dot(toOccPoint, dirToLight) / pixelDistanceToLight;

					//if the point found is between the pixel being lit and the light
					if (percentToLightAtOcc < 1.0 && percentToLightAtOcc > 0.0 && pixelLightRadius > EPS) 
					{
						//the occlusion from the sample point is the percentage of the cone to the light that it is occluding
						float visableRadius = length(toOccPoint - (dirToLight * percentToLightAtOcc * pixelDistanceToLight));
						float projectedLightRadius = pixelLightRadius * percentToLightAtOcc;
						float occlusion = saturate(visableRadius / projectedLightRadius);

						shadowFactor = min(shadowFactor, occlusion);
					}

					currentDistance += distanceToNearestPoint;

					if (currentDistance >= pixelDistanceToLight)
					{
						return shadowFactor;
					}
				}

				return 0.0;
			}

			float3 Get2DLight(float2 pixelPos, float2 lightPixelPos, float lightRadius, float3 lightColor)
			{
				float2 dirToLight = lightPixelPos - pixelPos;
				float pixelDistanceToLight = length(dirToLight);
				dirToLight /= pixelDistanceToLight; //normalize

				float pixelLightRadius = lightRadius * _PixelsPerUnit;

				return lightColor
						* GetSoftShadow(pixelPos, dirToLight, pixelDistanceToLight, pixelLightRadius)
						* GetLightAtten(pixelDistanceToLight / _PixelsPerUnit, lightRadius);
			}

            float4 frag (v2f i) : SV_Target
            {
				float2 pixelPos = i.pos.xy;
				pixelPos.y = _ScreenParams.y - pixelPos.y;

				float3 finalColor = 0.0;

				if (tex2Dlod(_ScreenDistanceFieldBuffer, float4(i.uv, 0, 0)).r > EPS)
				{
					finalColor += 0.005; //add some ambient lighting if we aren't in a wall

					//evaluate each light
					for (int n = 0; n < _2DLightCount; n++)
					{
						float2 lightPixelPos = _2DLightData[n].xy;
						float radius = _2DLightData[n].z;
						float3 color = _2DLightColors[n].rgb;

						finalColor += Get2DLight(pixelPos, lightPixelPos, radius, color);
					}
				}
				
				return float4(finalColor, 1.0);
            }
            ENDCG
        }
    }
}
