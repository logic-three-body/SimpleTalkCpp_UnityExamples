﻿Shader "Unlit/Extra004_Block"
{
    Properties
    {
    }
    SubShader
    {
        Tags { 
            "Queue" = "Geometry+1"
            "RenderType"="Opaque" 
         }
        LOD 100
        ColorMask 0

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                return float4(1,0,0,0);
            }
            ENDCG
        }
    }
}
