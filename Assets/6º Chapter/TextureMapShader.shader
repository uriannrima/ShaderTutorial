Shader "ustom/Research/Texture Map" {
	Properties {
		_Color ("Color Tint", Color) = (1.0,1.0,1.0,1.0)
		_MainTex ("Diffuse Texture", 2D) = "white" {}
		_SpecColor ("Specular Color", Color) = (1.0,1.0,1.0,1.0)
		_Shininess ("Shininess", Float) = 10
		_RimColor ("Rim Color", Color) = (1.0,1.0,1.0,1.0)
		_RimPower ("Rim Power", Range(0.1, 10.0)) = 3.0
	}
	
	SubShader {
		Pass {
			Tags { "LightMode" = "ForwardBase" }
			
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			// Properties Variables
			uniform float4 _Color;
			uniform float4 _SpecColor;
			uniform float4 _RimColor;
			
			uniform float _Shininess;
			uniform float _RimPower;
			
			uniform sampler2D _MainTex;
			uniform float4 _MainTex_ST; // Scale and Offset
			
			// Unity defined variables
			uniform float4 _LightColor0;			
			
			// Structs
			struct vertexInput {
				float4 vertex : POSITION;
				float3 normal: NORMAL;
				float4 texcoord : TEXCOORD0;
			};
			
			struct vertexOutput{	
				float4 pos : SV_POSITION;
				float4 tex : TEXCOORD0;
				float4 worldPos : TEXCOORD1;
				float3 normalDir : TEXCOORD2;
			};
			
			// Vertex Function			
			vertexOutput vert(vertexInput v) {
				vertexOutput o;
				
				o.pos = mul(UNITY_MATRIX_MVP, v.vertex); // Vertex MVP position
				o.worldPos = mul(_Object2World, v.vertex); // Vertex world position
				o.normalDir = v.normal; // Vertex normal direction
				o.tex = v.texcoord; // Texture coordenate
				
				return o;
			}
			
			// Fragment Function
			float4 frag (vertexOutput i): COLOR {
				
				// Directions
				float3 normalDirection = i.normalDir;
				float3 viewDirection = normalize(_WorldSpaceCameraPos - i.worldPos.xyz);
				float3 lightDirection;
				float attenuation;
				
				// Check if directional or spot light
				if (_WorldSpaceLightPos0.w == 0.0)
				{
					attenuation = 1.0;
					lightDirection = normalize(_WorldSpaceLightPos0.xyz);
				} 
				else
				{
					float3 f2lVector = _WorldSpaceLightPos0.xyz - i.worldPos.xyz;
					float f2lDistance = length(f2lVector);
					attenuation = 1.0 / f2lDistance;
					lightDirection = normalize(f2lVector);
				}
				
				// Reflections
				
				float3 diffuseReflection = _LightColor0.rgb * attenuation * saturate(dot(normalDirection, lightDirection));
				float3 specularReflection = pow(saturate(dot(reflect(-lightDirection, normalDirection), viewDirection)), _Shininess) * _SpecColor.rgb * diffuseReflection;
				
				// Rim Lightning
				
				float rim = 1 - dot(viewDirection, normalDirection);
				float3 rimLightning = _RimColor.rgb * pow(rim, _RimPower) * diffuseReflection;
				
				// Final Light
				float3 lightFinal = diffuseReflection + specularReflection + rimLightning;
				
				// Texture Mapping
				// Tex2D gets data out of the texture at float2 coordinate (since its an 2D): i.tex.xy // Texture coordenate
				// Our _MainTex_ST holds Scaling and Offset (or Tiling and Offset)
				// So we scale it and offset it.
				// float4 tex is a RGBA data from texture, so we can use it like an color (xyz, rgb,etc)
				float4 tex = tex2D(_MainTex, i.tex.xy * _MainTex_ST.xy + _MainTex_ST.zw);
				
				// Now we blend everything together.
				// Lightning, texture and tint color
				return float4(lightFinal * tex.rgb * _Color.rgb, 1.0);
			}
			
			ENDCG
		}
		Pass {
			Tags { "LightMode" = "ForwardAdd" }
			Blend One One
			
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			// Properties Variables
			uniform float4 _Color;
			uniform float4 _SpecColor;
			uniform float4 _RimColor;
			
			uniform float _Shininess;
			uniform float _RimPower;
			
			uniform sampler2D _MainTex;
			uniform float4 _MainTex_ST; // Scale and Offset
			
			// Unity defined variables
			uniform float4 _LightColor0;			
			
			// Structs
			struct vertexInput {
				float4 vertex : POSITION;
				float3 normal: NORMAL;
				float4 texcoord : TEXCOORD0;
			};
			
			struct vertexOutput{	
				float4 pos : SV_POSITION;
				float4 tex : TEXCOORD0;
				float4 worldPos : TEXCOORD1;
				float3 normalDir : TEXCOORD2;
			};
			
			// Vertex Function			
			vertexOutput vert(vertexInput v) {
				vertexOutput o;
				
				o.pos = mul(UNITY_MATRIX_MVP, v.vertex); // Vertex MVP position
				o.worldPos = mul(_Object2World, v.vertex); // Vertex world position
				o.normalDir = v.normal; // Vertex normal direction
				o.tex = v.texcoord; // Texture coordenate
				
				return o;
			}
			
			// Fragment Function
			float4 frag (vertexOutput i): COLOR {
				
				// Directions
				float3 normalDirection = i.normalDir;
				float3 viewDirection = normalize(_WorldSpaceCameraPos - i.worldPos.xyz);
				float3 lightDirection;
				float attenuation;
				
				// Check if directional or spot light
				if (_WorldSpaceLightPos0.w == 0.0)
				{
					attenuation = 1.0;
					lightDirection = normalize(_WorldSpaceLightPos0.xyz);
				} 
				else
				{
					float3 f2lVector = _WorldSpaceLightPos0.xyz - i.worldPos.xyz;
					float f2lDistance = length(f2lVector);
					attenuation = 1.0 / f2lDistance;
					lightDirection = normalize(f2lVector);
				}
				
				// Reflections
				
				float3 diffuseReflection = _LightColor0.rgb * attenuation * saturate(dot(normalDirection, lightDirection));
				float3 specularReflection = pow(saturate(dot(reflect(-lightDirection, normalDirection), viewDirection)), _Shininess) * _SpecColor.rgb * diffuseReflection;
				
				// Rim Lightning
				
				float rim = 1 - dot(viewDirection, normalDirection);
				float3 rimLightning = _RimColor.rgb * pow(rim, _RimPower) * diffuseReflection;
				
				// Final Light
				float3 lightFinal = diffuseReflection + specularReflection + rimLightning;
				
				// Texture Mapping
				// Tex2D gets data out of the texture at float2 coordinate (since its an 2D): i.tex.xy // Texture coordenate
				// Our _MainTex_ST holds Scaling and Offset (or Tiling and Offset)
				// So we scale it and offset it.
				// float4 tex is a RGBA data from texture, so we can use it like an color (xyz, rgb,etc)
				float4 tex = tex2D(_MainTex, i.tex.xy * _MainTex_ST.xy + _MainTex_ST.zw);
				
				// Now we blend everything together.
				// Lightning, texture and tint color
				return float4(lightFinal * _Color.rgb, 1.0);
			}
			
			ENDCG
		}
	}
	//Fallback "Specular"
}