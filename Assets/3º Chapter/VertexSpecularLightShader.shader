// Shader beginning and name
Shader "Custom/Research/Specular (Vertex)" {

	// Properties to the Unity
	Properties {
		_Color ("Color", Color) = (1.0,1.0,1.0,1.0)
		_SpecColor ("Specular Color", Color) = (1.0,1.0,1.0,1.0)
		_Shineness ("Shineness", Float) = 10
	}
	
	// Single subshader
	SubShader{
		// Forward Rendering Lightning
		Tags { "LightMode" = "ForwardBase" }
		
		// Single pass.
		Pass {
			// Start CG programming
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			// Properties Variables
			uniform float4 _Color;
			uniform float4 _SpecColor;
			uniform float _Shineness;
			
			// User defined Variables
			
			// Unity defined variables
			uniform float4 _LightColor0; // Color of the Light affecting the actual object.
			
			// Others
			// float4x4 _Object2World; // 4x4 Matrix to transform Object position to World position
			// float4x4 _World2Object; // 4x4 Matrix to transform World position to Object position
			// float4 _WorldSpaceLightPos0 // Position of the light that is affecting the actual object.
			// float3 _WorldSpaceCameraPos // Position of the main camera in the World Space. It's an FLOAT3!!!
			
			// Structs
			
			// Input of the Vertex function
			struct vertexInput {
				float4 vertex : POSITION; // Position of the vertex in object space.
				float3 normal : NORMAL; // Normal of the vertex in world space.
			};
			
			// Output of the Vertex function
			struct vertexOutput {
				float4 pos : SV_POSITION; // Position of the vertex in World Space (Or like a screen space, anyway).
				float4 col : COLOR; // Color of the vertex after the vertex function.
			};
			
			// Help functions
			
			// Diffuse calculations.
			float3 calculateDiffuseReflection(float3 normalDirection, float3 lightDirection, float attenuation){
				float3 diffuseReflection;
				
				// To calculate our diffuse, we just need the dot product of the light and the normal of the vertex
				diffuseReflection = max(0.0, dot(normalDirection, lightDirection));
				
				// Then we add the details, like attenuation and light color.
				// Since we are calculating two reflections, we add the surface color at the end of it.
				
				// Define the attenuation of light
				diffuseReflection *= attenuation;
				
				// Blend it with the color of the light.
				diffuseReflection *= _LightColor0.xyz;
				
				return diffuseReflection;
			}
			
			// Specular calculations.
			float3 calculateSpecularReflection(float3 normalDirection, float3 lightDirection, float3 viewDirection){
				float3 specularReflection;
				
				// To calculate the specular reflection, we need to reflect the light on the vertex normal
				specularReflection = reflect(-lightDirection, normalDirection);
				
				// And we need it to reflect only to the viewers direction
				specularReflection = dot(viewDirection, specularReflection);
				
				// We are getting some negative numbers, so we must enclose it
				specularReflection = max(0.0, specularReflection);
				
				// To do the glowing effect of the specular reflection, we use the pow function
				specularReflection = pow(specularReflection, _Shineness);
				
				// And we are getting some light on the back of the object
				// So we need to use the "normal" or "diffuse" reflection
				// That way, we get light only where it should be reflected.
				specularReflection *= max(0.0, dot(normalDirection, lightDirection));
				
				// We just need to blend the specular light color
				specularReflection *= _SpecColor.rgb;
				
				return specularReflection;
			}
			
			// Calculate normal direction
			float3 calculateNormalDirection(float3 normal)
			{
			
				// Normal is in the world space, so we must put it in the object space
				// _WorldToObject is an float4x4, so we need to convert Normal to float4
				// After calculating, normal we only need the xyz components (ignoring w)
				// And as we only need it's direction, we normalize it.
				
				return normalize(mul(_World2Object, float4(normal, 0.0)).xyz);
				//return v.normal; // It seams to work too.
			}
			
			// Calculate view direction
			float3 calculateViewDirection(float4 viewPos, bool isWorldPosition) 
			{
			
				// Now, we need our view position which is the direction from the vertex and the camera position.
				// We have the camera position at _WorldSpaceCameraPos and we have our vertex WORLD position at o.pos so...
				
				// If we haven't calculated viewPos in world position
				if (!isWorldPosition){
					viewPos = mul(_Object2World, viewPos);
				}
				  
				return normalize(float4(_WorldSpaceCameraPos.xyz, 1.0) - viewPos);;
			}
			
			// Calculate directional light direction
			float3 calculateLightDirection(){
			
				// As we learned, the Unity gives you the light position/rotation with the _WorldSpaceLightPos0.xyz
				// As we are using directional light, this is the rotation of the light, so it already is it's direction.
				// So we just need to normalize it.
				
				return normalize( _WorldSpaceLightPos0.xyz );
			}
			
			// Functions
			
			// Vertex function
			vertexOutput vert(vertexInput v){
				vertexOutput o;
				
				// First thing, always must return the Vertex position in the World position:
				o.pos = mul(UNITY_MATRIX_MVP, v.vertex); // Now o.pos has Vertex World Position.
				
				// Normal direction
				float3 normalDirection = calculateNormalDirection(v.normal);
				
				// View direction
				float3 viewDirection = calculateViewDirection(v.vertex, false);
				
				// Light direction
				float3 lightDirection = calculateLightDirection();
				
				//We have all of needed directions, so we can calculate those reflections:				
				
				// Light attenuation handles the "distance" from the light, when dealing with point light...
				// Right now, we just consider it 1.0
				float attenuation = 1.0;
				
				float3 diffuseReflection = calculateDiffuseReflection(normalDirection, lightDirection, attenuation);
				float3 specularReflection = calculateSpecularReflection(normalDirection, lightDirection, viewDirection);
				
				// We have our lights, so we add then together
				float3 lightFinal = diffuseReflection + specularReflection;
				
				// And blend the surface color
				lightFinal *= _Color.rgb;
				
				// Now, just set the output
				o.col = float4(lightFinal, 1.0);
				
				return o;
			}
			
			// Fragment function
			float4 frag(vertexOutput o) : COLOR{
				return o.col;
			}
			
			
			ENDCG
		}
	}
	//Fallback "Diffuse"
}