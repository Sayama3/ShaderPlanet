// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "Custom/Planet"
{
	//The property are solely for the purpose of giving a user some controls one some set variables but don't initialise 
	//them. Only permit a controls when they do exist.
    Properties
    {	
    		
	    //The variable set here are what I personally think work the best with the shader
    	// With a camera at (0.0,0.0,-2.0) and a VerticalFOV of 30
		
		[Header(Sun Parameters)]
	    [MaterialToggle] _AutoRotation("Auto Rotation",Float) = 1
		_SunRotationSpeed("Sun Rotation",Range(0,1)) = 0.2
    	
		[Header(Earth Parameters)]
		_EarthRotationSpeed("Earth Rotation",Range(0,.5)) = .05
    	
		[Header(Cloud Parameters)]
		_CloudSpeed("Cloud Speed",Range(0,.5)) = .06
		_CloudTransparency("Cloud Transparency",Range(0.0,1.0)) = 0.55
    	
		[Header(Smoothing Parameters)]
		_SmoothY("Smooth Pôles (day/night cycle)",Range(0.0,1.0)) = 1 //Don't work really well so 1 disable it
    	
		[Header(Fresnel Parameters)]
		_FresnelThreshold("Fresnel Treeshold",Range(0,1)) = 0.610
		_FresnelPower("Fresnel Power",Int) = 2
		_FresnelColor("Color of Fresnel",Color) = (0,0.406,0.361,0.369)
		
		[Header(Textures)]
	    // The color for the texture are for a debug as it permit (without any set texture) to clearly see who do what
		_MainTex("Day Tex", 2D) = "white"
		_SecondaryTex("Night Tex", 2D) = "black"
		_CloudTex("Cloud Tex", 2D) = "grey"
    }
    SubShader
    {
    	//The render type we wish, here, we don't want to see through the planet. But maybe later 
        Tags { "RenderType" = "Opaque" }
        LOD 100

        Pass
        {
        	//Define what we do in the shader
        	//Here we calcul some vertex position so "vertex shader"
        	//And we calcul the color of athe vertex so "fragment shader"
        	//Even if we could do all in one of them only, it's better to split the shader this way.
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            //The variable and function provide are store one those files so we precise it to unity
            //(plus my IDE can get the function associate to those and provide them to me)
            #include <UnityCG.cginc>
		    #include <UnityShaderUtilities.cginc>
		    #include <AutoLight.cginc>

            //Defining PI this way because we need it a lot but don't strictly want it as a variable so it is convert during the compilation
            #define PI 3.141592654

	        //Initialisation of the variable we can custom above
			sampler2D _MainTex;
	        sampler2D _SecondaryTex;
	        sampler2D _CloudTex;
			float4 _MainTex_ST;
	        float4 _SecondaryTex_ST;
	        float4 _CloudTex_ST;
			float4 _FresnelColor;

	        float _FresnelThreshold;
	        int _FresnelPower;
			float _SizeNoise;
	        float _EarthRotationSpeed;
	        float _SunRotationSpeed;
			float _SmoothY;
	        float _CloudTransparency;
	        float _CloudSpeed;

            bool _AutoRotation;
            
            //Methods of to get the UV position (2D) from a point on a sphere (3D)
			float2 UV( float3 position )
            {
			    return float2(
		    		saturate(((atan2(position.z, position.x) / PI) + 1.0) / 2.0),
		    		(0.5-(asin(position.y)/PI)) );
		    }
            
            struct appdata
            {
				//The default data unity can provide to us that I might need
				//And that I will process on the vertex shader before the color shading
                float4 vertex : POSITION;
				float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
				float4 tangent : TANGENT;
            };

            struct v2f
            {
            	//The transform data that I will use on the pixel shading
                float4 vertex : SV_POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
				float4 tangent : TANGENT;
			    float3 localPos : LOCALPOS;
            };

            //The vertex shader with the return
            /*This part of the shader transform the informations contain by "appdata"
             *given by unity to be process and use later on the pixel shader*/
            v2f vert (appdata v)
            {
            	//Attributing of the different variables and processing to get the realPos of the variable
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex); //Remove some clipping we can get on the looping of the texture
                o.uv = TRANSFORM_TEX(v.uv, _MainTex); //Same here but for the texture
            	o.normal = UnityObjectToWorldNormal(v.normal); //The normal of the vertex
            	o.tangent = float4(UnityObjectToWorldDir(v.tangent),v.tangent.w); //I thought it could be useful but not for my type of shader
            	o.localPos = mul(unity_WorldToObject,o.vertex); //multiply of matrix (provide by unity) to get the position in the objectSpace
            	
                return o;
            }

            //the fragment shader with th color as return
            fixed4 frag (v2f IN) : COLOR
            {
            	//Obtain the center of the object with the matrix "unity_ObjectToWorld" provide by "UnityCG" and the 
            	float3 centerObj = mul(unity_ObjectToWorld, float4(0.0,0.0,0.0,1.0) );
            	
        		//Set the normal as local variable
        		float2 vertexUV = IN.uv;

            	
        		//Calcul of the real texture depending on the offset & scale given as parameters
        		float2 mainNormalST = TRANSFORM_TEX(vertexUV,_MainTex);
        		float2 secondaryNormalST = TRANSFORM_TEX(vertexUV,_SecondaryTex);
        		float2 cloudNormalST = TRANSFORM_TEX(vertexUV,_CloudTex);

        		
        		//Calculus of the sun position depending on if we take the the point light or use an autoRotation
            	//(depending on the some other variable such as "_SunRotationSpeed")
            	
            	//The sun/vertex position are currently in 2D because I don't experiment the rest we a third dimension
            	//who could add a level of complexity I currently can't handle
				float2 time = float2(-_Time.y,0);
            	float2 sunPosition;
				 if(!_AutoRotation)
				 {
             		sunPosition = normalize(_WorldSpaceLightPos0.xz);
				 }
             	else
            	{
        			float timeToPi = time.x * _SunRotationSpeed % (2 * PI);
        			sunPosition = normalize(float2(cos(timeToPi),sin(timeToPi)));
            	}
        		float2 vertexPositon = normalize(IN.vertex.xz);

            	
        		//This dot product permit to know wether or not the current vertex is facing the sun or not and at which degree
        		float dotProduct = dot(sunPosition,vertexPositon);
        		dotProduct = (dotProduct + 1.0) / 2.0; //Resetting the value between 0 & 1 because it facilitates the lerp that come next

            	//don't work really well, need a big adjust to set it to a custom direction (result of crossProduct of sunPosition and vertexPositon)
        		// And check if don't cancel some other functionnality by accident
        		//Smoothing the dotProduct of the pôle to not get a day and night at the samePosition but a unique value (night or day) everywhere
				if (abs(normalize(IN.localPos).y) > _SmoothY)
				{
					//A ternary operation to set the day in a pole and night in the other
					float2 lerpValue = sign(normalize(IN.vertex).y) > 0 ? float2(dotProduct,1) : float2(dotProduct,0);
					//The smoothing operation on the Y component only in the borders (dot product as min to get back to the initial day/night rotation of the earth)
					dotProduct  = lerp(lerpValue.x,lerpValue.y,(abs(normalize(IN.vertex).y) - _SmoothY ) * 1 / (1-_SmoothY));
				}

            	
        		//The earth supposedly in rotation is being offset by the time and speed that pass
        		//We calcul the day and night here because the blend is do next
        		float2 timeMainNormal = mainNormalST + (time * _EarthRotationSpeed) ;
				float2 timeSecondaryNormal = secondaryNormalST + (time * _EarthRotationSpeed) ;

            	
        		//Here we get the color of the vertex with the offset apply
            	//Same, we get the to textures first
        		float4 mainTexture = tex2Dlod(_MainTex, float4(timeMainNormal,0,0)); //Day texture
        		float4 secondaryTexture = tex2Dlod(_SecondaryTex, float4(timeSecondaryNormal,0,0)); //Night Texture

            	
				//Here, we lerp the colors to get a blend between them and knowing if it's day/night/crepuscular/aurora/...
        		float4 colorTexture = lerp(mainTexture,secondaryTexture,dotProduct.xxxx);

            	
            	//Calculing the color of the cloud depending on there rotationSpeed (same as previously)   	
				float2 timeNormalClouds = cloudNormalST + time * _CloudSpeed;
				float4 CloudTexture = tex2Dlod(_CloudTex, float4(timeNormalClouds,0,0));

            	
        		//Calculating Fresnel :
            	//First, we need the direction & distance of the camera to the object
            	//(because we suppose we look a it, else we don't really care what it's doing)
        		float3 directionCamera = _WorldSpaceCameraPos - centerObj;
            	/*here, as for the earth rotation, we calculate the dot product of the normal and the camera direction
            	 *But ! Here, we want to know if it's orthogonal (with a threshold) to apply the fresnel here
            	 *(it is suppose to be outside of the earth, but it look good so I keep it)*/
            	//TODO: Research for an outline shader and add it in another SubShader.
        		float dotFresnel = dot( normalize(directionCamera) , normalize(IN.normal) );
				if (abs(dotFresnel) <= _FresnelThreshold)
				{
					//Here, the main idea is to have an interpolation between the Fresnel Color and the earthColor we have calculate before
					//Therefore, to smooth the whole better, we do a power the dot dotFresnel
					//(which is already being re-evaluate between 0&1 instead of 0 & _FresnelThreshold)
					float lerpFresnelValue = pow(dotFresnel * 1/_FresnelThreshold,_FresnelPower);
					
        			colorTexture = lerp(_FresnelColor,colorTexture,lerpFresnelValue);
					//colorTexture =lerp( colorTexture*1/abs(dotFresnel) , colorTexture , lerpFresnelValue);
				}

            	
        		//Here we apply the color texture but add the cloudTexture (with it's associated Transparency)
        		return colorTexture  + CloudTexture *_CloudTransparency;
            }
            ENDCG
        }
    }
}