// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// From an nVIDIA Ray Traced - Cg browser example
//1 BOUNCE
Shader "RayTracing" 
{
 	Properties 
 	{
		checkSampler("Base (RGB)", 2D) = "white" {}
		OrginPos("OrginPos",Vector) = (0,0,0,1)//发射光线的原点
		Focus("CameraFocus",Float) = 500
		DebugShadow("DebugShadow",Range(0,3)) = 0
		LightPos("LightPos",Vector)=(10.0, 10.0, -10.0,1)
	}	
    
    SubShader 
	{
  		Pass 
  		{ 
			CGPROGRAM
			
	        #pragma vertex RayTraceVS 
	        #pragma fragment RayTracePS
	        #pragma target 3.0
	        
			#include "UnityCG.cginc"
			
			sampler2D checkSampler;
			float4 OrginPos;
			float Focus;
			int DebugShadow;
			float3 LightPos;

			uniform float4x4 view;
			static float2 viewport 			= {256.0f, 256.0f};
			static float foclen 			= 500.0;
			static float3 lightPosition 	= { 10.0, 10.0, -10.0 };
			static float4 lightColor 		= { 1.0, 1.0, 1.0, 1.0 };
			static float shininess 			= 40.0;
			static float4 backgroundColor 	= { 0.0, 0.0, 0.0, 1.0 };

			struct Ray 
			{
				float3 o;	// origin
				float3 d;	// direction
			};

			struct Sphere 
			{
			  	float3 centre;
			  	float rad2;	// radius^2
			  	float4 color;
			  	float Kd;
			  	float Ks;
			  	float Kr;
			};

			// Object database stored in constants
			#define SQR(N) (N*N)
			#define NOBJECTS 3
			
			static Sphere object[NOBJECTS] = 
			/*	centre					radius^2	COLOR					Kd	Ks	Kr*/
			{
				{{0.0, 	 0.0, 10.0}, 	SQR(1.0), 	 {0.0, 0.5, 1.0, 1.0}, 1.0, 1.0, 0.5},//blue
				{{1.5,   -0.5, 10.0}, 	SQR(0.5), 	 {0.0, 1.0, 0.0, 1.0}, 1.0, 1.0, 0.5},//green	
				{{0.0, -101.0, 10.0}, 	SQR(100.0),  {1.0, 1.0, 1.0, 1.0}, 1.0, 1.0, 0.5}//big sphere as plane
			};
			
			static const float eps = 0.001;	// error epsilon
			
			Sphere SphereIndex(int i) // RB: NB cannot use arrays of structs in CG.
			{
				Sphere temp;
				
				if (i == 0)
					temp = object[0];
				else if (i == 1)
					temp = object[1];
				else
					temp = object[2];
					
				return temp;
			}

			
			float SphereIntersect(Sphere s, Ray ray, out bool hit)
			{
			//《tiger book》->4.4.1 P76-77

			/*
			闫老师Games101 L13 35:00
			Ray:r(t)=o+td; 0<t<∞
			Sphere:p:(p-c)^2-R^2=0;
			on intersect:r(t)=p;
			(o+td-c)^2-R^2=0;
			at^2+bt+c=0,where a=d^2 b=2(o-c)d c=(o-c)^2-R^2
			t=[-b±sqrt(b^2-4ac)]/2a

			相交：求出两个t值，t1,t2 取小值作为最近交点
			相离

			*/


			  	float3 v = s.centre - ray.o;
			  	float b = dot(v, ray.d);
			  	float discriminant = (b * b) - dot(v, v) + s.rad2;//b2-4ac

			  	hit = true;
			  	
			  	// note - early returns not supported by HLSL compiler currently:
				//  if (discriminant<=0) return -1.0; // ray misses
			  	if (discriminant <= 0) 
			  		hit = false;

			  	discriminant = sqrt(discriminant);
			  	float t2 = b + discriminant;

				//  if (t2<=eps) return -1.0; // behind ray origin
			  	if (t2 <= eps) 
			  		hit = false; // behind ray origin

			  	float t1 = b - discriminant;
				
			  	if ((t1 > eps) && (t1 < t2))  // return nearest intersection
			    	return t1;
			  	else
			    	return t2;
			}

			float3 SphereNormal(Sphere s, float3 i)
			{
				return normalize(i - s.centre);
			}

			// find nearest hit
			// returns intersection point
			float3 NearestHit(Ray ray, out int hitobj, out bool anyhit)
			{
				float mint = 1e10;
				hitobj = -1;
			 	anyhit = false;
			 	
				for(int i = 0; i < NOBJECTS; i++) //search for the nearest object
				{
					bool hit;
					//return the nearest value to t
					float t = SphereIntersect(SphereIndex(i), ray, hit);
					
					if (hit) 
					{
						if (t < mint) 
						{
							hitobj = i;
							mint = t;//nearest value t
							anyhit = true;
						}
					}
				}
				
				return ray.o + ray.d * mint;
			}

			
			// test for any hit (for shadow rays)
			//Very similar to shadow map,we emit a ray from our shading point to light,if it hits anything
			//then this pos should be in the shadow area 
			bool ShadowCheck(Ray ray)
			{
				bool anyhit = false;
				
				for(int i = 0; i < NOBJECTS; i++) 
				{
					bool hit;
					
					float t = SphereIntersect(SphereIndex(i), ray, hit);
					
					if (hit) 
					{
						anyhit = true;
					}
				}
				
				return anyhit;
			}

			// Phong lighting model
			float4 Phong(float3 n, float3 l, float3 v, float shininess, float4 diffuseColor, float4 specularColor)
			{
				float ndotl 	= dot(n, l);
				float diff 		= saturate(ndotl);
				float3 r 		= reflect(l, n);
				float spec 		= pow(saturate(dot(v, r)), shininess) * (ndotl > 0.0);
				
				return diff * diffuseColor + spec * specularColor;
			}

			float4 Lambert(float3 n, float3 l,float4 diffuseColor)
			{
				float ndotl 	= dot(n, l);
				float diff 		= saturate(ndotl);	
				return diff * diffuseColor;
			}

			float4 Shade(float3 hitpos, float3 n, float3 v, int hitobj)
			{
				//float3 l = normalize(lightPosition - i);
				float3 l = normalize(LightPos - hitpos);//light dir

				// check if shadowed
				Ray shadowray;
				shadowray.o = hitpos;
				shadowray.d = l;
				bool shadowed = ShadowCheck(shadowray);

				// lighting
				float4 diff = SphereIndex(hitobj).color * SphereIndex(hitobj).Kd;
								
				if (hitobj == 2) 
				{
					// Windows profile does not allow for texture accesses within an if.
					// uncomment the next line to run on a Mac with a checkered floor.
					//diff *= 1.0; //tex2D(checkSampler, hitpos.xz);	// floor texture
					diff *=tex2D(checkSampler,hitpos.xz);
				}
				
				float4 spec = lightColor * SphereIndex(hitobj).Ks;
				float shadowFactor = 0.25f + 0.75f * !shadowed;	
				//shadowFactor=1.0f;
				if(DebugShadow==0)
					return shadowFactor;
				else if(DebugShadow==1)
					return Lambert(n,l,diff)*shadowFactor;
				else
					return Phong(n,	l, v, shininess, diff, spec) * shadowFactor;
			}

			// Vertex shader
			struct Vertex
			{
			    float4 pos		: POSITION;
			    float4 texcoord	: TEXCOORD0;
			};

			Vertex RayTraceVS(Vertex v)
			{
			
				Vertex temp;
				
				temp.pos = UnityObjectToClipPos(v.pos);
				temp.texcoord = v.texcoord;
			    return temp;
			}

			void animate_scene(float time)
			{
				object[1].centre.x = _SinTime.w * 1.5f;
				object[1].centre.z = 10.0f + _CosTime.w * 1.5f;
			}



			// Pixel shader
			float4 RayTracePS(Vertex IN) : COLOR
			{
				animate_scene(_Time.w * 3.0f);
				
				// calculate eye ray
				float3 d;
				d.xy = ((IN.texcoord.xy * 2.0) - 1.0) * viewport;//[-1,1] to NDC->ScreenPos
				//d.xy=IN.texcoord.xy*viewport;
				//d.xy = ((IN.texcoord.xy * 2.0) - 1.0);//NDC->ScreenPos ortho?
				//d.y = d.y;	// flip y axis
				//d.z = foclen;
				d.z = Focus;//forward direction
				//d.z=30;




				// transform by view matrix
				Ray eyeray;
				//float3 orgin_pos = float3(0,2.5,-1);//从世界原点或其他点出发
				//float4 orgin_pos = OrginPos;//从世界原点或其他点出发

				//ortho?
				//OrginPos.xy=IN.texcoord.xy * 2.0 - 1.0;//uv
				//OrginPos.x+=0.7;
			

				eyeray.o = mul(OrginPos, view).xyz;//camera to world,相当于view的转置即逆矩阵
				eyeray.d = mul(d, (float3x3)view);
				eyeray.d = normalize(eyeray.d);

				


				// find nearest hit
				int hitobj;
				bool hit;
				float3 hitpos = NearestHit(eyeray, hitobj, hit);
				float4 c = 0;
				
				if (hit) 
				{
					// shade surface
					float3 n = SphereNormal(SphereIndex(hitobj), hitpos) ;
					c = Shade(hitpos, n, eyeray.d, hitobj);
				
					// shoot reflection ray
					float3 r = reflect(eyeray.d, n);
					Ray reflray;
					reflray.o = hitpos;
					reflray.d = r;
					int hitobj2;
					
					hitpos = NearestHit(reflray, hitobj2, hit);
					
					if (hit) 
					{
						n = SphereNormal(SphereIndex(hitobj), hitpos);
						c += Shade(hitpos, n, reflray.d, hitobj2) * SphereIndex(hitobj).Kr;
					} 
					else
					{
						c += backgroundColor;
					}
				} 
				else 
				{
					c = backgroundColor;
				}
				
				return c;
			}
		
		ENDCG
		}
	} 
}
