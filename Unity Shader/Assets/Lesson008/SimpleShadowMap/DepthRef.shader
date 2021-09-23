// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "DepthRef" 
{
 	Properties 
 	{
		_MainTex("Base (RGB)", 2D) = "white" {}    
	}	
    
    SubShader 
	{
  		Pass 
  		{ 
			CGPROGRAM
			
	        #pragma vertex VS_Texture 
	        #pragma fragment PS_Texture
	        #pragma target 3.0
	        
			#include "UnityCG.cginc"
			
			// used to transform vertices from local space into homogenous clipping space
			sampler2D _MainTex;
			static float4 _MainTex_ST; 		// needed by TRANSFORM_TEX

			// vertex shader input structure
			struct VSInput_PosTex 
			{
				float4 pos: POSITION;
				float2 tex: TEXCOORD0;
			};
			
			// vertex shader output structure
			struct VSOutput_PosTex 
			{
				float4 pos: SV_POSITION;
				float2 tex: TEXCOORD0;
			};
			
			// position and texture vertex shader
			VSOutput_PosTex VS_Texture(VSInput_PosTex a_Input)
			{
				VSOutput_PosTex Output;
			
				// compute vertex transformation
				Output.pos = UnityObjectToClipPos(a_Input.pos);
				Output.tex = TRANSFORM_TEX(a_Input.tex, _MainTex);
				
				// adjust texture coordinates based on inputs
				Output.tex.x = a_Input.tex.x;
				Output.tex.y = a_Input.tex.y;
			
				return Output;
			}

			float4 PS_Texture(VSOutput_PosTex a_Input) : COLOR
			{
				float depth = 0;
				
				depth = DecodeFloatRGBA(tex2D(_MainTex, a_Input.tex));
				
				return float4(depth, depth, depth, 1.0f);
			}
						
			ENDCG
		}
	} 
}
