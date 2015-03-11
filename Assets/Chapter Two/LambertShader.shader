// Shader beginning and name
Shader "Custom/Research/Lambert" {
	
	// Properties to the Unity
	Properties {
		_Color ("Color", Color) = (1.0,1.0,1.0,1.0)
	}
	
	// Single subshader
	SubShader {
	
		// Single pass.
		Pass {
			// Forward Rendering Lightning
			Tags { "LightMode" = "ForwardBase" }
		
			// Start CG Programming.
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			// User define variables
			uniform float4 _Color;
			
			// Unity defined variables are variables that we can take direct from Unity
			uniform float4 _LightColor0; // Color of the Light affecting the actual object.
			
			// Already defined by unity:
			// float4x4 _Object2World; // 4x4 Matrix to transform Object position to World position
			// float4x4 _World2Object; // 4x4 Matrix to transform World position to Object position
			// float4 _WorldSpaceLightPos0 // Position of the light that is affecting the actual object.
			
			// Structs
			
			// Input of the Vertex function
			struct vertexInput {
				float4 vertex : POSITION; // Position of the vertex in object space.
				float3 normal : NORMAL; // Normal of the vertex in world space.
				// float4 col : COLOR; // Color of the vertex in the object.
			};
			
			// Output of the Vertex function
			struct vertexOutput {
				float4 pos : SV_POSITION; // Position of the vertex in World Space.
				float4 col : COLOR; // Color of the vertex after the vertex function.
			};
			
			// Vertex function
			vertexOutput vert(vertexInput v) {
				vertexOutput o;
				
				// First thing, always must return the Vertex position in the World position:
				o.pos = mul(UNITY_MATRIX_MVP, v.vertex); // Now o.pos has Vertex World Position.
				
				// To the normals then...
				// Normal is in the world space, so we must put it in the object space
				// _WorldToObject is an float4x4, so we need to convert Normal to float4
				// After calculating, normal we only need the xyz components (ignoring w)
				// And as we only need it's direction, we normalize it.
				float3 normalDirection = normalize(mul(_World2Object, float4(v.normal, 0.0)).xyz);
				
				// Light direction now...
				// As we learned, the Unity gives you the light position/rotation with the _WorldSpaceLightPos0.xyz
				// As we are using directional light, this is the rotation of the light, so it already is it's direction.
				// So we just need to normalize it.
				float3 lightDirection = normalize( _WorldSpaceLightPos0.xyz );
				
				// Light attenuation handles the "distance" from the light, when dealing with point light...
				// Right now, we just consider it 1.0
				float attenuation = 1.0;
				
				// With all this, we can calculate the reflection of the light, how much the light is reflected
				// We call it Diffuse, just because the Lambertian Lightning is considered this way.
				// With the max(0.0) we don't let the value goes below 0, because is unrealistic.
				float3 diffuseReflection = max(0.0, dot(normalDirection, lightDirection));
				
				// Define the attenuation of light
				diffuseReflection *= attenuation;
				
				// Blend it with the color of the light.
				diffuseReflection *= _LightColor0.xyz;
				
				// Blend it with the color of the surface.
				// You could use rgb instead of xyz, but for me it makes easier.
				diffuseReflection *= _Color.xyz;
				
				// Now, we must say how the color of the object will be returned
				// As we don't know now, we just return the normal for test
				// As normal is a float3, we need to convert it into a vector4 (which is a Color)
				// Using this, we'll see something like a rainbow material.
				o.col = float4(diffuseReflection, 1.0);
				
				return o;
			}
			
			// Fragment function
			float4 frag(vertexOutput i) : COLOR {
				// Just return the color that vertex function calculated.
				return i.col;
			}
			
			ENDCG
		}
	}
	
	//Fallback "Diffuse";
}