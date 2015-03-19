Shader "Custom/Research/Multiple Lights" {
	
	// Properties to the Unity
	Properties {
		// Surface Properties
		_Color ("Color", Color) = (1.0,1.0,1.0,1.0)
		
		// Specular Lightning properties
		_SpecColor ("Specular Color", Color) = (1.0,1.0,1.0,1.0)
		_Shineness ("Shineness", Float) = 10
		
		// Rim Lightning Properties
		_RimColor ("Rim Color", Color) = (1.0,1.0,1.0,1.0)
		_RimPower ("Rim Power", Range(0.1, 10.0)) = 3.0
	}
	
	// Single subshader
	SubShader {
		Pass {
		
			// Forward Rendering Lightning
			Tags { "LightMode" = "ForwardBase" }
			
			// Start CG programming
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			// Properties Variables
			uniform float4 _Color;
			uniform float4 _SpecColor;
			uniform float _Shineness;
			uniform float4 _RimColor;
			uniform float _RimPower;
			
			// Unity defined variables
			uniform float4 _LightColor0; // Color of the Light affecting the actual object.
			
			// Structs
			
			// Input of the Vertex function
			struct vertexInput {
				float4 vertex : POSITION; // Position of the vertex in object space.
				float3 normal : NORMAL; // Normal of the vertex in world space.
			};
			
			// Output of the Vertex function
			struct vertexOutput {
				float4 pos : SV_POSITION; // Position of the vertex in World Space (Or like a screen space, anyway).
				float4 worldPos : TEXCOORD0; // World position of the vertex (_Object2World * v.vertex)
				float3 normalDir : TEXCOORD1; // Normal direction of the vertex (_World2Object, float4(v.normal, 0.0))
			};
			
			// Calculate normal direction
			float3 calculateNormalDirection(vertexInput v)
			{
			
				// Normal is in the world space, so we must put it in the object space
				// _WorldToObject is an float4x4, so we need to convert Normal to float4
				// After calculating, normal we only need the xyz components (ignoring w)
				// And as we only need it's direction, we normalize it.
				
				//return normalize(mul(_World2Object, float4(v.normal, 0.0)).xyz);
				return v.normal; // It seams to work too.
			}
			
			// Vertex function
			vertexOutput vert(vertexInput v){
				vertexOutput o;
				
				// First thing, always must return the Vertex position in the World position:
				o.pos = mul(UNITY_MATRIX_MVP, v.vertex); // Now o.pos has vertex MVP position.
				
				// World position of the vertex
				// Above we have the Model * View * Projection position... learn about later.
				o.worldPos = mul(_Object2World, v.vertex); // Now o.worldPos has the vertex in world position
				
				o.normalDir = calculateNormalDirection(v);
				
				return o;
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
			
			// Diffuse calculations.
			float3 calculateDiffuseReflection(float3 normalDirection, float3 lightDirection, float attenuation){
				float3 diffuseReflection;
				
				// To calculate our diffuse, we just need the dot product of the light and the normal of the vertex
				diffuseReflection = saturate(dot(normalDirection, lightDirection));
				
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
				specularReflection = saturate(specularReflection);
				
				// To do the glowing effect of the specular reflection, we use the pow function
				specularReflection = pow(specularReflection, _Shineness);
				
				// And we are getting some light on the back of the object
				// So we need to use the "normal" or "diffuse" reflection
				// That way, we get light only where it should be reflected.
				specularReflection *= saturate(dot(normalDirection, lightDirection));
				
				// We just need to blend the specular light color
				specularReflection *= _SpecColor.rgb;
				
				return specularReflection;
			}
			
			// Rim Lightning calculation
			float3 calculateRimLightning(float3 normalDirection, float3 lightDirection, float3 viewDirection, float attenuation){
				// Rim must be shown where the viewDirection and normalDirection gets more separated from each other
				// We can get the point where it gets parallel using dot(viewDirection, normalDirection)
				// So we saturate it (from 0 to 1), then "invert" it subtracting it by 1
				// Where it is more parallel (= 1), it goes to 0, and when it gets more perpendicular (=0), it goes to 1.
				float rim = 1 - saturate(dot(viewDirection, normalDirection));
				
				
				// Try out: return dot(viewDirection, normalDirection);
				// Then: 1 - saturate(dot(viewDirection, normalDirection));
				// To see the difference between those two modes.
				
				// Then, we scale it with the light attenuation, blend it with the light color, rim color, 
				// light it up only where the normals and light directions gets parallel and control its intensity using the pow function
				return attenuation * _LightColor0.xyz * _RimColor * saturate(dot(normalDirection, lightDirection)) * pow (rim, _RimPower);
			}
			
			// Light attenuation and direction
			struct lightProperties {
				float attenuation;
				float3 lightDirection;
			};
			
			// Calculate light attenuation and direction
			// Verifying if it is directional or point light.
			lightProperties calculateLightProperties(float4 position){
				lightProperties o;
				
				// Directional Light
				if (_WorldSpaceLightPos0.w == 0) {
					
					// Light is always at full attenuation
					o.attenuation = 1.0;
					
					// And the direction is just the normal of its position
					o.lightDirection = normalize( _WorldSpaceLightPos0.xyz );
					
				// Point light
				} else {
				
					// F2L = Fragment to Light
					float3 f2lVector = (_WorldSpaceLightPos0.xyz - position);
					
					// Distance = H² = Ca² + Cb²
					float f2lDistance = length (f2lVector);
					
					// Since the attenuation of the light falls of as the distance gets bigger
					// It falls inversely proportional to the distance.
					o.attenuation = 1/f2lDistance;
					
					// As we normalize it, we get its direction.
					o.lightDirection = normalize(f2lVector);
				}
				
				return o;
			}
			
			// Fragment function
			float4 frag(vertexOutput i) : COLOR{
				// Now, we are going to do all those vert calculations on the fragment
				// Which is pretty much the same...
				
				// Vectors
				
				// Again, we will need the normalDirection, viewDirection and lightDirection
				float3 normalDirection = i.normalDir;
				float3 viewDirection = calculateViewDirection(i.worldPos, true);
				
				// Lightning
				
				lightProperties lp = calculateLightProperties(i.worldPos);
				
				// Diffuse and Specular
				float3 diffuseReflection = calculateDiffuseReflection(normalDirection, lp.lightDirection, lp.attenuation);
				float3 specularReflection = calculateSpecularReflection(normalDirection, lp.lightDirection, viewDirection);
				
				// Rim Lightning
				float3 rimLightning = calculateRimLightning(normalDirection, lp.lightDirection, viewDirection, lp.attenuation);
				
				// We have our lights, so we add then together
				float3 lightFinal = diffuseReflection + specularReflection + rimLightning;
				
				// And blend the surface color
				lightFinal *= _Color.rgb;
				
				return  float4(lightFinal,1.0);
			}
			
			ENDCG
		}
		Pass {
		
			// Forward Rendering Lightning
			Tags { "LightMode" = "ForwardAdd" }
			Blend One One
			
			// Start CG programming
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			// Properties Variables
			uniform float4 _Color;
			uniform float4 _SpecColor;
			uniform float _Shineness;
			uniform float4 _RimColor;
			uniform float _RimPower;
			
			// Unity defined variables
			uniform float4 _LightColor0; // Color of the Light affecting the actual object.
			
			// Structs
			
			// Input of the Vertex function
			struct vertexInput {
				float4 vertex : POSITION; // Position of the vertex in object space.
				float3 normal : NORMAL; // Normal of the vertex in world space.
			};
			
			// Output of the Vertex function
			struct vertexOutput {
				float4 pos : SV_POSITION; // Position of the vertex in World Space (Or like a screen space, anyway).
				float4 worldPos : TEXCOORD0; // World position of the vertex (_Object2World * v.vertex)
				float3 normalDir : TEXCOORD1; // Normal direction of the vertex (_World2Object, float4(v.normal, 0.0))
			};
			
			// Calculate normal direction
			float3 calculateNormalDirection(vertexInput v)
			{
			
				// Normal is in the world space, so we must put it in the object space
				// _WorldToObject is an float4x4, so we need to convert Normal to float4
				// After calculating, normal we only need the xyz components (ignoring w)
				// And as we only need it's direction, we normalize it.
				
				//return normalize(mul(_World2Object, float4(v.normal, 0.0)).xyz);
				return v.normal; // It seams to work too.
			}
			
			// Vertex function
			vertexOutput vert(vertexInput v){
				vertexOutput o;
				
				// First thing, always must return the Vertex position in the World position:
				o.pos = mul(UNITY_MATRIX_MVP, v.vertex); // Now o.pos has vertex MVP position.
				
				// World position of the vertex
				// Above we have the Model * View * Projection position... learn about later.
				o.worldPos = mul(_Object2World, v.vertex); // Now o.worldPos has the vertex in world position
				
				o.normalDir = calculateNormalDirection(v);
				
				return o;
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
			
			// Diffuse calculations.
			float3 calculateDiffuseReflection(float3 normalDirection, float3 lightDirection, float attenuation){
				float3 diffuseReflection;
				
				// To calculate our diffuse, we just need the dot product of the light and the normal of the vertex
				diffuseReflection = saturate(dot(normalDirection, lightDirection));
				
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
				specularReflection = saturate(specularReflection);
				
				// To do the glowing effect of the specular reflection, we use the pow function
				specularReflection = pow(specularReflection, _Shineness);
				
				// And we are getting some light on the back of the object
				// So we need to use the "normal" or "diffuse" reflection
				// That way, we get light only where it should be reflected.
				specularReflection *= saturate(dot(normalDirection, lightDirection));
				
				// We just need to blend the specular light color
				specularReflection *= _SpecColor.rgb;
				
				return specularReflection;
			}
			
			// Rim Lightning calculation
			float3 calculateRimLightning(float3 normalDirection, float3 lightDirection, float3 viewDirection, float attenuation){
				// Rim must be shown where the viewDirection and normalDirection gets more separated from each other
				// We can get the point where it gets parallel using dot(viewDirection, normalDirection)
				// So we saturate it (from 0 to 1), then "invert" it subtracting it by 1
				// Where it is more parallel (= 1), it goes to 0, and when it gets more perpendicular (=0), it goes to 1.
				float rim = 1 - saturate(dot(viewDirection, normalDirection));
				
				
				// Try out: return dot(viewDirection, normalDirection);
				// Then: 1 - saturate(dot(viewDirection, normalDirection));
				// To see the difference between those two modes.
				
				// Then, we scale it with the light attenuation, blend it with the light color, rim color, 
				// light it up only where the normals and light directions gets parallel and control its intensity using the pow function
				return attenuation * _LightColor0.xyz * _RimColor * saturate(dot(normalDirection, lightDirection)) * pow (rim, _RimPower);
			}
			
			// Light attenuation and direction
			struct lightProperties {
				float attenuation;
				float3 lightDirection;
			};
			
			// Calculate light attenuation and direction
			// Verifying if it is directional or point light.
			lightProperties calculateLightProperties(float4 position){
				lightProperties o;
				
				// Directional Light
				if (_WorldSpaceLightPos0.w == 0) {
					
					// Light is always at full attenuation
					o.attenuation = 1.0;
					
					// And the direction is just the normal of its position
					o.lightDirection = normalize( _WorldSpaceLightPos0.xyz );
					
				// Point light
				} else {
				
					// F2L = Fragment to Light
					float3 f2lVector = (_WorldSpaceLightPos0.xyz - position);
					
					// Distance = H² = Ca² + Cb²
					float f2lDistance = length (f2lVector);
					
					// Since the attenuation of the light falls of as the distance gets bigger
					// It falls inversely proportional to the distance.
					o.attenuation = 1/f2lDistance;
					
					// As we normalize it, we get its direction.
					o.lightDirection = normalize(f2lVector);
				}
				
				return o;
			}
			
			// Fragment function
			float4 frag(vertexOutput i) : COLOR{
				// Now, we are going to do all those vert calculations on the fragment
				// Which is pretty much the same...
				
				// Vectors
				
				// Again, we will need the normalDirection, viewDirection and lightDirection
				float3 normalDirection = i.normalDir;
				float3 viewDirection = calculateViewDirection(i.worldPos, true);
				
				// Lightning
				
				lightProperties lp = calculateLightProperties(i.worldPos);
				
				// Diffuse and Specular
				float3 diffuseReflection = calculateDiffuseReflection(normalDirection, lp.lightDirection, lp.attenuation);
				float3 specularReflection = calculateSpecularReflection(normalDirection, lp.lightDirection, viewDirection);
				
				// Rim Lightning
				float3 rimLightning = calculateRimLightning(normalDirection, lp.lightDirection, viewDirection, lp.attenuation);
				
				// We have our lights, so we add then together
				float3 lightFinal = diffuseReflection + specularReflection + rimLightning;
				
				// And blend the surface color
				lightFinal *= _Color.rgb;
				
				return  float4(lightFinal,1.0);
			}
			
			ENDCG
		}
	}
}	