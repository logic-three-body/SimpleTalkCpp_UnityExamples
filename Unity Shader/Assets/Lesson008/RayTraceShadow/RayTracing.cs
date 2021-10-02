using UnityEngine;
using System.Collections;


public class RayTracing : MonoBehaviour 
{
	private GameObject origCam;
	private Matrix4x4 ViewMatrix;

	// Use this for initialization
	void Start ()
	{
		//		Author
		//
		//		Textures are the work of Emil Persson, aka Humus. http://www.humus.name
		//				
		//		License
		//				
		//		This work is licensed under a Creative Commons Attribution 3.0 Unported License.
		//		http://creativecommons.org/licenses/by/3.0/
		origCam = GameObject.FindWithTag("MainCamera");
		ViewMatrix = origCam.GetComponent<Camera>().cameraToWorldMatrix;
		GetComponent<Renderer>().material.SetMatrix("view", ViewMatrix);
	}
	
	// Update is called once per frame
	void Update () 
	{
		ViewMatrix = origCam.GetComponent<Camera>().cameraToWorldMatrix;
		GetComponent<Renderer>().material.SetMatrix("view", ViewMatrix);
	}
	
}
