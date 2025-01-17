﻿using UnityEngine;
using System.Collections;

public class ShadowMap : MonoBehaviour
{
	private Camera lightCam = null;

	// Use this for initialization
	void Start ()
	{
	}
	
	// Update is called once per frame
	void Update () 
	{
		if (!lightCam)
		{
			foreach (Camera cam in Camera.allCameras)
			{
				if (cam.name == "Camera")
					lightCam = cam;
			}
		}

		GetComponent<Renderer>().material.SetMatrix("_ProjMatrix", lightCam.projectionMatrix * lightCam.worldToCameraMatrix);
	}
}
