// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "MyShader/Ex008 - Shadow Map"
{
	Properties {
		ambientColor		("Ambient Color", Color) = (0,0,0,0)
		diffuseColor		("Diffuse Color", Color) = (1,1,1,1)
		specularColor		("Specular Color", Color) = (1,1,1,1)
		specularShininess	("Specular Shininess", Range(1,128)) = 10
		shadowBias			("shadow bias", Range(0, 0.1)) = 0.05
		_strength			("shadow strength", Range(0, 1.0)) = 0.0
	}

	SubShader
	{
		Tags { "RenderType"="Opaque" }

		Pass
		{			
		//---------------
			CGPROGRAM
			#pragma vertex vs_main
			#pragma fragment ps_main
			
			#include "UnityCG.cginc"

			struct appdata {
				float4 pos		: POSITION;
				float4 color	: COLOR;
				float2 uv		: TEXCOORD0;
				float3 normal	: NORMAL;
			};

			struct v2f {
				float4 pos		: SV_POSITION;
				float3 wpos		: TEXCOORD7;
				float4 color	: COLOR;
				float2 uv		: TEXCOORD0;
				float3 normal	: NORMAL;
				float4 shadowPos : TEXCOORD1;
			};
			int _ShadowMode;//阴影模式 pcf3X3 4-tap only-shdowmap等
			int _tap4;//在pcf3X3同时是否开启4-tap pcf 此处借鉴《DX12开发实战》20.5.2
			int _Debug_Shadow;//仅输出shadow
			float4x4 MyShadowVP;//转换至光源空间矩阵 proj*view
			static float _TexSize = 512.0f;//float const float都不可以
			float _strength;//阴影强度

			//static const float _TexSize = 512.0f;//float,const float都不可以
			//float _TexSize = 512.0f;//float const float都不可以
			//原因见：
			//https://forum.unity.com/threads/changing-global-shader-variables-in-cginc.495857/
			
			v2f vs_main (appdata v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.pos);
				o.wpos = mul(UNITY_MATRIX_M, v.pos).xyz;

				o.color = v.color;
				o.uv = v.uv;
				o.normal = mul((float3x3)UNITY_MATRIX_M, v.normal); // normal has no translation, that's why mul float3x3

				float4 wpos = mul(unity_ObjectToWorld, v.pos);
				// transform coordinates into Light Space 
				o.shadowPos = mul(MyShadowVP, wpos);
				o.shadowPos.xyz /= o.shadowPos.w;//prespective division
				return o;
			}

			float4 MyLightDir;

			float4 ambientColor;
			float4 diffuseColor;
			float4 specularColor;
			float  specularShininess;

			sampler2D uvChecker;
			sampler2D MyShadowMap;
			float shadowBias;

			float4 basicLighting(float3 wpos, float3 normal)
			{
				float3 N = normalize(normal);
				float3 L = normalize(-MyLightDir.xyz);
				float3 V = normalize(wpos - _WorldSpaceCameraPos);

				float3 R = reflect(L,N);

				float4 ambient  = ambientColor;
				float4 diffuse  = diffuseColor * max(0, dot(N,L));

				float  specularAngle = max(0, dot(R,V));
				float4 specular = specularColor * pow(specularAngle, specularShininess);

				float4 color = 0;
				color += ambient;
				color += diffuse;
				color += specular;

				return color;
			}

			float4 shadow_Debug(v2f i) {
				float4 s = i.shadowPos;
				float3 uv = s.xyz * 0.5 + 0.5;
				float d = uv.z;


				if (false) {
					float3 N = normalize(i.normal);
					float3 L = normalize(-MyLightDir.xyz);
					float slope = tan(acos(dot(N,L)));

					d -= shadowBias * slope;
				} else {
					d -= shadowBias;
				}

				// depth checking
				if (false) {
					if (d < 0) return float4(1,0,0,1);
					if (d > 1) return float4(0,1,0,1);
					return float4(0, 0, d, 1);
				}

				//return tex2D(uvChecker, uv); // projection checking

				float m = tex2D(MyShadowMap, uv).r;
				//return float4(m,m,m,1); // shadowMap checking
				//return float4(d, m, 0, 1);
				float c = 0;
				if (d > m.r)
					return float4(c,c,c,1);
				return float4(1,1,1,1);
				
				//PCF
				float shadow = 0;
				float dx = 1.0f/_TexSize;
				//dx = 1.0f/512.0f;
				for(int x = -1;x<=1;++x)
				 for(int y=-1;y<=1;++y)
					{
						float2 _offset = dx*float2(x,y);
						m = tex2D(MyShadowMap,uv+_offset).r;
						shadow += d>m.r?0:1;
					}
				
				float s0 = tex2D(MyShadowMap,uv+float2(dx,0.0)).r<d?0:1;


				//shadow = s0;
				shadow/=9.0;

				//debug,Shadow Map Only
				//m = tex2D(MyShadowMap,uv+dx*float2(0,0)).r;
				//shadow = d>m.r?0:1;

				
				return float4(shadow,shadow,shadow,1);

			}


			float shadowMap(float d1,float d2)
			{
				return d1<=d2?1:_strength;//true : not shadow , false in the shadow
			}

			//refer:《DX12开发实战》20章阴影贴图 & https://www.youtube.com/watch?v=3AdLu0PHOnE&t=413s
			float tap4PCF(float d,float2 uv)
			{
			// Transform to texel space
				float2 texPos = _TexSize*uv.xy;
			// Determine the lerp amounts.    
				float2 t = frac(texPos);
			 // sample shadow map
				float dx = 1.0f/_TexSize;
				float s0 = tex2D(MyShadowMap, uv).r;
				float s1 = tex2D(MyShadowMap, uv+float2(dx,0)).r;
				float s2 = tex2D(MyShadowMap, uv+float2(0,dx)).r;
				float s3 = tex2D(MyShadowMap, uv+float2(dx,dx)).r;
				float result0 = shadowMap(d,s0);
				float result1 = shadowMap(d,s1);
				float result2 = shadowMap(d,s2);
				float result3 = shadowMap(d,s3);

				float shadow = lerp( lerp( result0, result1, t.x ), lerp( result2, result3, t.x ), t.y );
				return shadow;
			}

			float PCF_Filter(float d,float2 uv)
			{
				//PCF
				float shadow = 0;
				float dx = 1.0f/_TexSize;
				for(int x = -1;x<=1;++x)
				 for(int y=-1;y<=1;++y)
					{
						float2 _offset = dx*float2(x,y);
						float m = tex2D(MyShadowMap,uv+_offset).r;
						if(_tap4)
							shadow += tap4PCF(d,uv+_offset);							
						else
							shadow += shadowMap(d,m);
					}		
				return shadow/9.0f;
			}


			float shadow(v2f i)
			{
				// transform coordinates into texture coordinates [shadow map]
				float4 s = i.shadowPos;
				float3 shadow_uv = s.xyz * 0.5 + 0.5;
				float current_depth = shadow_uv.z;	//fragment depth in shadow map	
				
				//shadow bias
				float slope = 1.0;
				if(false)//bias according to slope
				{
					float3 N = normalize(i.normal);
					float3 L = normalize(-MyLightDir.xyz);
					slope = tan(acos(dot(N,L)));
				}
				float _bias = shadowBias*slope;
				current_depth-=_bias;

				float orgin_depth=0.0;//depth in shadow map,the closest point towards light
				orgin_depth=tex2D(MyShadowMap, shadow_uv).r;
				
				float shadow = 0.0;

				if(3==_ShadowMode)
				{
					shadow = PCF_Filter(current_depth,shadow_uv);
				}
				else if(2==_ShadowMode)
				{
					shadow = tap4PCF(current_depth,shadow_uv);
				}
				else
				{
					shadow = shadowMap(current_depth,orgin_depth);					
				}



				return float4(shadow,shadow,shadow,1);
			}

			float4 ps_main (v2f i) : SV_Target {
				//float4 s = shadow_Debug(i);
				float4 s = shadow(i);
				if(_Debug_Shadow)
					return s;

				float4 c = basicLighting(i.wpos, i.normal);
				return c * s;
			}
			ENDCG
		}
	}
}
