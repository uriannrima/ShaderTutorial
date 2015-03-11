// Shader declaration and Name
Shader "Custom/Research/FlatColor" {

	// Properties from this Shader
	// Some might come from Unity (denoted with the "_")
	Properties {
		// Color parameter with the name Color and Type of Color
		_Color("Color", Color) = (1.0, 1.0, 1.0, 1.0)
	}
	
	// We might have one SubShader for each type of plataform (PC, Xbox, etc, etc)
	// If we have only one SubShader, it will be used for everyone.
	SubShader {
	
		// First Pass of this shader, think like a Render pass.
		// We might have multiple passes of shader, each doing one job after another, blending everything
		// Like one to do the lightning, other to deferred, etc.
		
		Pass {
			// With CGPROGRAM, We tell Unity that we're using CG Language to program this pass
			// Everything before this, was written in ShaderLab, now we're doing it in CG.
			
			// pragmas are instrunctions, it tells to unity what to look where.
			// It must be used RIGHT AFTER CGPROGRAM, like above, or the Shader won't work.
			// You can't even use comments in between them!!!
				
			// We are telling that the Vertex should be handled by vert function, down below.
			// And Fragment should be handled by the frag function.
			
			CGPROGRAM
			#pragma vertex vert
            #pragma fragment frag
			
			// user defined variables
			
			// CG doesn't know what a "Color" is,
			// So we have to tell him that it is an 4 variable float (float, float, float, float)
			// We could use an fixed4 here (255,255,255,255), but let's stick to the line.
			// Uniform is not necessary, but, Shaders CG program can be used by another programs
			// And uniform is necesseray in CG to tell it that we're declaring a variable.
			uniform float4 _Color; 
			
			// base input/output structs
			
			// Input to Vertex function.
			struct vertexInput {
			
				// We can grab a whole another Semantics to be used in our Vertex function
				// Like vertex position, normals, tangents, textureCoordenate (UV), etc.
				
				// In this case, we grab the vertex position in the OBJECT space (not in the world space)
				float4 vertex : POSITION;
				
				// Some other examples:
    			// float4 tangent : TANGENT;// The tangent of the vertex
    			// float3 normal : NORMAL;// The normal of the vertex
    			// float4 texcoord : TEXCOORD0;// base texture uv coordinates of the vertex
    			// float4 texcoord1 : TEXCOORD1;// second texture uv2 coordinates of the vertex
    			// fixed4 color : COLOR; // vertex color
    			
    			// As long as you call one of the semantics that unity supports, 
    			// POSITION, TANGENT, NORMAL, TEXCOORD0, TEXCOORD1, COLOR it's ok.
				
			};
			
			// Output of the Vertex function, and input of the Fragment function.
			// Right now we don't need anything from the Vertex function, but the always required position.
			// We get the object position, convert it into a space that unity understand and return that.
			// So, we get the vertex position, convert to unity matrix and return it to pos.
			struct vertexOutput {
				float4 pos : SV_POSITION;
			};
			
			// vertex function
			vertexOutput vert(vertexInput v) {
				// Create the ouput.
				vertexOutput o;

				// MVP stands for Model View Projection Matrix
				// We are calculating the vertex position in the Unity view projection.]
				// Mul, multiply a matrix * vector, we get a vector "inside" that matrix.
				o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
				
				// Return output.
				return o;
			}
			
			// fragment function
			// float4 represents a COLOR.
			float4 frag(vertexOutput i) : COLOR
			{
				// Simply always return the color
				// So we have an flat, non effected color.
				return _Color;
			}
			
			// The ENDCG tells that we've ended.
			// So, go back to understand as ShaderLab
			ENDCG
		}
	}
	
	// If everyhing goes wrong, use Diffuse.
	// Avoid it when creating the Shader, 
	// You might not know when things are not working properly.
	Fallback "Diffuse"
}