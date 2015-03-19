Shader "ustom/Research/Optimized" {
	Properties {
		_Color ("Color Tint", Color) = (1.0,1.0,1.0,1.0)
		_MainTex ("Diffuse Texture, Gloss (A)", 2D) = "white" {}
		_BumpMap ("Normal Texture", 2D) = "bump" {}
		_EmitMap ("Emission Texture", 2D) = "black" {}
		_EmitColor ("Emission Color Tint", Color) = (1.0,1.0,1.0,1.0)
		_BumpDepth ("Bump Depth", Range(0, 1)) = 1
		_SpecColor ("Specular Color", Color) = (1.0,1.0,1.0,1.0)
		_Shininess ("Shininess", Float) = 10
		_RimColor ("Rim Color", Color) = (1.0,1.0,1.0,1.0)
		_RimPower ("Rim Power", Range(0.1, 10.0)) = 3.0
		_EmitStrength("Emission Strength", Range(0, 2.0)) = 0
	}
	
	SubShader {
		Pass {
			Tags { "LightMode" = "ForwardBase" }
			
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			// Float - Should be used when dealing with position, since it really needs to be precise sometimes
			// Fixed - We use when we are dealing with values that goes from -2 to 2, so most of directions works as Fixed values, since goes from 0 to 1.
			// Half - When we need more precision (more values) than Fixed, but below Float, we just use Half. Think as, beyond -2 and 2, but less than a Float.
			
			// Properties Variables
			// Since color goes from 0 to 1 (as float), we only need an Fixed4 for it.
			// Will give us enough precision of the color and won't take much space.
			uniform fixed4 _Color;
			uniform fixed4 _SpecColor;
			uniform fixed4 _RimColor;
			uniform fixed4 _EmitColor;
			
			uniform half _Shininess;
			uniform half _RimPower;
			uniform fixed _BumpDepth;
			uniform fixed _EmitStrength;
			
			uniform sampler2D _MainTex;
			// As Scale and Offset won't goes above unrealistic numbers, 
			// We can use Half for it... Fixed would be REALLY small. And Float REALLY big.
			uniform half4 _MainTex_ST; 
			
			uniform sampler2D _BumpMap;
			uniform half4 _BumpMap_ST; // Scale and Offset
			
			uniform sampler2D _EmitMap;
			uniform half4 _EmitMap_ST; // Scale and Offset
			
			// Unity defined variables
			// Light color needs to be half4, because sometimes, it goes beyond -2 and 2... So just to make sure.
			uniform half4 _LightColor0;			
			
			// Structs
			struct vertexInput {
				half4 vertex : POSITION;
				half4 normal: NORMAL;
				half4 tangent: TANGENT;
				half4 texcoord : TEXCOORD0;
			};
			
			struct vertexOutput{	
				half4 pos : SV_POSITION;
				half4 tex : TEXCOORD0;
				fixed4 lightDirection : TEXCOORD1; // Why lightDirection is a fixed4? Since we need to pass light attenuation to frag function, why not use its 4th component?
				fixed3 viewDirection : TEXCOORD2;
				fixed3 normalWorld : TEXCOORD3;
				fixed3 tangentWorld : TEXCOORD4;
				fixed3 binormalWorld : TEXCOORD5;
			};
			
			// Vertex Function			
			vertexOutput vert(vertexInput v) {
				vertexOutput o;
				
				o.normalWorld = v.normal; // Normal direction
				o.tangentWorld = v.tangent; // Tangent direction
				o.binormalWorld = normalize(cross(o.normalWorld, o.tangentWorld) * v.tangent.w); // Binormal direction
				
				o.pos = mul(UNITY_MATRIX_MVP, v.vertex); // Vertex MVP position
				half4 worldPos = mul(_Object2World, v.vertex); // Vertex world position
				o.tex = v.texcoord; // Texture coordenate				
				
				// Since our light and view direction won't change for each fragment,
				// We'll calculate it on the vert function, and pass it to the frag function.
				
				// Directions
				o.viewDirection = normalize(_WorldSpaceCameraPos - worldPos.xyz);
				
				half3 f2lVector = _WorldSpaceLightPos0.xyz - worldPos.xyz;
				
				//float f2lDistance = length(f2lVector); // Removing temporary variable
				
				// Lerp goes from A, to B, using Blend as factor (from 0 to 1).
				// So, If it is 0, it goes to A, if it is 1, it goes to B
				// As _WorldSpaceLightPos0 is always 0 or 1, it must be one or another always.
				
				//float attenuation = lerp(1.0, 1.0 / f2lDistance, _WorldSpaceLightPos0.w);
				
				// The same for light direction
				// If _WorldSpaceLightPos.x is 0, it uses A, if it is 1, it uses B...
				// Since, both need to be normalized, we can do it outside
				
				//lightDirection = lerp(normalize(_WorldSpaceLightPos0.xyz), normalize(f2lVector), _WorldSpaceLightPos0.w);
				//lightDirection = normalize(lerp(_WorldSpaceLightPos0.xyz, f2lVector, _WorldSpaceLightPos0.w); // Removing temporary variable
				
				// Our light direction will be stored at xyz components
				// And attenuation on w component.				
				o.lightDirection = fixed4(
					normalize(lerp(_WorldSpaceLightPos0.xyz, f2lVector, _WorldSpaceLightPos0.w)), // Light Direction
					lerp(1.0, 1.0 / length(f2lVector), _WorldSpaceLightPos0.w) // Attenuation
				);
				
				// Writing like above, is bad for readability, but, we must remove all temporaray variables.
				
				return o;
			}
			
			// Fragment Function
			fixed4 frag (vertexOutput i): COLOR {		
					
				// Texture Mapping
				// Tex2D gets data out of the texture at float2 coordinate (since its an 2D): i.tex.xy // Texture coordenate
				// Our _MainTex_ST holds Scaling and Offset (or Tiling and Offset)
				// So we scale it and offset it.
				// float4 tex is a RGBA data from texture, so we can use it like an color (xyz, rgb,etc)
				fixed4 tex = tex2D(_MainTex, i.tex.xy * _MainTex_ST.xy + _MainTex_ST.zw);
				fixed4 texN = tex2D(_BumpMap, i.tex.xy * _BumpMap_ST.xy + _BumpMap_ST.zw);
				fixed4 texE = tex2D(_EmitMap, i.tex.xy * _EmitMap_ST.xy + _EmitMap_ST.zw);
				
				// unpackNormal function
				// Unity has an UnpackNormal function built-in CgInclude, but here, we'll do it manually, to understand how it works
				
				// localCoords.z is the bump "depthness".
				// This value, is REALLY near to 1, but not 1... You could use only 1 if you wanted.
				// Or, for some fanciness, we could toogle it, as we want, using a property.
				// Try out values to see how it affects.
				fixed3 localCoords = float3(2 * texN.ag - float2(1.0, 1.0), _BumpDepth); // Now, texN.ag goes from -1 to 1... instead of 0 to 1.
				
				// Normal transpose matrix
				fixed3x3 local2WorldTranspose = fixed3x3(
					i.tangentWorld,
					i.binormalWorld,
					i.normalWorld
				);
				
				// Calculate normal direction
				fixed3 normalDirection = normalize(mul(localCoords, local2WorldTranspose));
				
				// Reflections
				
				float3 diffuseReflection = _LightColor0.rgb * i.lightDirection.w * saturate(dot(normalDirection, i.lightDirection.xyz));
				float3 specularReflection = pow(saturate(dot(reflect(-i.lightDirection.xyz, normalDirection), i.viewDirection)), _Shininess) * _SpecColor.rgb * diffuseReflection;
				
				// Rim Lightning
				
				fixed rim = 1 - dot(i.viewDirection, normalDirection);
				fixed3 rimLightning = _RimColor.rgb * pow(rim, _RimPower) * diffuseReflection;
				
				// Final Light
				fixed3 lightFinal = diffuseReflection + (specularReflection * tex.a) + rimLightning + (_EmitColor * texE.rgb * _EmitStrength);
				
				// Now we blend everything together.
				// Lightning, texture and tint color
				return fixed4(lightFinal * tex.rgb * _Color.rgb, 1.0);
			}
			ENDCG
		}
		Pass {
			Tags { "LightMode" = "ForwardAdd" }
			Blend One One
			
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			// Float - Should be used when dealing with position, since it really needs to be precise sometimes
			// Fixed - We use when we are dealing with values that goes from -2 to 2, so most of directions works as Fixed values, since goes from 0 to 1.
			// Half - When we need more precision (more values) than Fixed, but below Float, we just use Half. Think as, beyond -2 and 2, but less than a Float.
			
			// Properties Variables
			// Since color goes from 0 to 1 (as float), we only need an Fixed4 for it.
			// Will give us enough precision of the color and won't take much space.
			uniform fixed4 _Color;
			uniform fixed4 _SpecColor;
			uniform fixed4 _RimColor;
			
			uniform half _Shininess;
			uniform half _RimPower;
			uniform fixed _BumpDepth;
			
			uniform sampler2D _MainTex;
			// As Scale and Offset won't goes above unrealistic numbers, 
			// We can use Half for it... Fixed would be REALLY small. And Float REALLY big.
			uniform half4 _MainTex_ST; 
			
			uniform sampler2D _BumpMap;
			uniform half4 _BumpMap_ST; // Scale and Offset
			
			// Unity defined variables
			// Light color needs to be half4, because sometimes, it goes beyond -2 and 2... So just to make sure.
			uniform half4 _LightColor0;			
			
			// Structs
			struct vertexInput {
				half4 vertex : POSITION;
				half4 normal: NORMAL;
				half4 tangent: TANGENT;
				half4 texcoord : TEXCOORD0;
			};
			
			struct vertexOutput{	
				half4 pos : SV_POSITION;
				half4 tex : TEXCOORD0;
				fixed4 lightDirection : TEXCOORD1; // Why lightDirection is a fixed4? Since we need to pass light attenuation to frag function, why not use its 4th component?
				fixed3 viewDirection : TEXCOORD2;
				fixed3 normalWorld : TEXCOORD3;
				fixed3 tangentWorld : TEXCOORD4;
				fixed3 binormalWorld : TEXCOORD5;
			};
			
			// Vertex Function			
			vertexOutput vert(vertexInput v) {
				vertexOutput o;
				
				o.normalWorld = v.normal; // Normal direction
				o.tangentWorld = v.tangent; // Tangent direction
				o.binormalWorld = normalize(cross(o.normalWorld, o.tangentWorld) * v.tangent.w); // Binormal direction
				
				o.pos = mul(UNITY_MATRIX_MVP, v.vertex); // Vertex MVP position
				half4 worldPos = mul(_Object2World, v.vertex); // Vertex world position
				o.tex = v.texcoord; // Texture coordenate				
				
				// Since our light and view direction won't change for each fragment,
				// We'll calculate it on the vert function, and pass it to the frag function.
				
				// Directions
				o.viewDirection = normalize(_WorldSpaceCameraPos - worldPos.xyz);
				
				half3 f2lVector = _WorldSpaceLightPos0.xyz - worldPos.xyz;
				
				//float f2lDistance = length(f2lVector); // Removing temporary variable
				
				// Lerp goes from A, to B, using Blend as factor (from 0 to 1).
				// So, If it is 0, it goes to A, if it is 1, it goes to B
				// As _WorldSpaceLightPos0 is always 0 or 1, it must be one or another always.
				
				//float attenuation = lerp(1.0, 1.0 / f2lDistance, _WorldSpaceLightPos0.w);
				
				// The same for light direction
				// If _WorldSpaceLightPos.x is 0, it uses A, if it is 1, it uses B...
				// Since, both need to be normalized, we can do it outside
				
				//lightDirection = lerp(normalize(_WorldSpaceLightPos0.xyz), normalize(f2lVector), _WorldSpaceLightPos0.w);
				//lightDirection = normalize(lerp(_WorldSpaceLightPos0.xyz, f2lVector, _WorldSpaceLightPos0.w); // Removing temporary variable
				
				// Our light direction will be stored at xyz components
				// And attenuation on w component.				
				o.lightDirection = fixed4(
					normalize(lerp(_WorldSpaceLightPos0.xyz, f2lVector, _WorldSpaceLightPos0.w)), // Light Direction
					lerp(1.0, 1.0 / length(f2lVector), _WorldSpaceLightPos0.w) // Attenuation
				);
				
				// Writing like above, is bad for readability, but, we must remove all temporaray variables.
				
				return o;
			}
			
			// Fragment Function
			fixed4 frag (vertexOutput i): COLOR {		
					
				// Texture Mapping
				// Tex2D gets data out of the texture at float2 coordinate (since its an 2D): i.tex.xy // Texture coordenate
				// Our _MainTex_ST holds Scaling and Offset (or Tiling and Offset)
				// So we scale it and offset it.
				// float4 tex is a RGBA data from texture, so we can use it like an color (xyz, rgb,etc)
				fixed4 tex = tex2D(_MainTex, i.tex.xy * _MainTex_ST.xy + _MainTex_ST.zw);
				fixed4 texN = tex2D(_BumpMap, i.tex.xy * _BumpMap_ST.xy + _BumpMap_ST.zw);
				
				// unpackNormal function
				// Unity has an UnpackNormal function built-in CgInclude, but here, we'll do it manually, to understand how it works
				
				// localCoords.z is the bump "depthness".
				// This value, is REALLY near to 1, but not 1... You could use only 1 if you wanted.
				// Or, for some fanciness, we could toogle it, as we want, using a property.
				// Try out values to see how it affects.
				fixed3 localCoords = float3(2 * texN.ag - float2(1.0, 1.0), _BumpDepth); // Now, texN.ag goes from -1 to 1... instead of 0 to 1.
				
				// Normal transpose matrix
				fixed3x3 local2WorldTranspose = fixed3x3(
					i.tangentWorld,
					i.binormalWorld,
					i.normalWorld
				);
				
				// Calculate normal direction
				fixed3 normalDirection = normalize(mul(localCoords, local2WorldTranspose));
				
				// Reflections
				
				float3 diffuseReflection = _LightColor0.rgb * i.lightDirection.w * saturate(dot(normalDirection, i.lightDirection.xyz));
				float3 specularReflection = pow(saturate(dot(reflect(-i.lightDirection.xyz, normalDirection), i.viewDirection)), _Shininess) * _SpecColor.rgb * diffuseReflection;
				
				// Rim Lightning
				
				fixed rim = 1 - dot(i.viewDirection, normalDirection);
				fixed3 rimLightning = _RimColor.rgb * pow(rim, _RimPower) * diffuseReflection;
				
				// Final Light
				fixed3 lightFinal = diffuseReflection + (specularReflection * tex.a) + rimLightning;
				
				// Now we blend everything together.
				// Lightning, texture and tint color
				return fixed4(lightFinal, 1.0);
			}
			ENDCG
		}
	}
	//Fallback "Specular"
}
