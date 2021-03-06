package de.nulldesign.nd2dx.renderers 
{
	import de.nulldesign.nd2dx.display.Camera2D;
	import de.nulldesign.nd2dx.display.Node2D;
	import de.nulldesign.nd2dx.resource.shader.Shader2D;
	import de.nulldesign.nd2dx.resource.shader.ShaderProgram2D;
	import de.nulldesign.nd2dx.utils.Statistics;
	import de.nulldesign.nd2dx.utils.Vertex3D;
	import de.nulldesign.nd2dx.resource.texture.Texture2D;
	import flash.display3D.Context3D;
	import flash.display3D.Context3DBlendFactor;
	import flash.display3D.Context3DProgramType;
	import flash.display3D.Context3DVertexBufferFormat;
	import flash.display3D.IndexBuffer3D;
	import flash.display3D.VertexBuffer3D;
	import flash.geom.Rectangle;
	import flash.system.ApplicationDomain;
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	import avm2.intrinsics.memory.*;
	
	/**
	 * ...
	 * @author Thomas John
	 */
	public class TexturedMeshCloudRenderer extends RendererBase
	{
		public static const VERTEX_SHADER:String =
			"alias va0, position;" +
			"alias va1, uv;" +
			"alias va2, color;" +
			
			"alias vc0, viewProjection;" +
			
			"temp0 = position;" +
			"output = mul4x4(temp0, viewProjection);" +
			
			"temp0 = uv;" +
			
			"temp1 = color;" +
			
			"#if PREMULTIPLIED_ALPHA;" +
			"	temp1.x = temp1.x * temp1.w;" +
			"	temp1.y = temp1.y * temp1.w;" +
			"	temp1.z = temp1.z * temp1.w;" +
			"#endif;" +
			
			// pass to fragment shader
			"v0 = temp0;" +
			"v1 = temp1;";
			
		public static const FRAGMENT_SHADER:String =
			"alias v0, texCoord;" +
			"alias v1, color;" +
			"temp0 = sample(texCoord, texture0);" +
			"temp0 *= color;" +
			"output = temp0;";
			
		private static var DEG2RAD:Number = Math.PI / 180;
		
		private var maxVertices:uint;
		private const numFloatsPerVertex:uint = 8;
		
		public var totalVertices:uint = 0;
		public var totalTriangles:uint = 0;
		public var totalMeshes:uint = 0;
		
		private var vIndexBuffer:Vector.<uint>;
		private var baVertexBuffer:ByteArray;
		private var vVertexBuffer:Vector.<Number>;
		
		private var indexBuffer:IndexBuffer3D;
		private var vertexBuffer:VertexBuffer3D;
		
		private var vertexBufferIndex:uint = 0;
		private var indexBufferIndex:uint = 0;
		
		private var blendModeSrc:String = Context3DBlendFactor.ONE;
		private var blendModeDst:String = Context3DBlendFactor.ONE_MINUS_SOURCE_ALPHA;
		
		private var parent:Node2D;
		private var texture:Texture2D;
		private var mainTexture:Texture2D;
		private var shader:Shader2D;
		private var shaderProgram:ShaderProgram2D;
		
		private var rotBase:Number;
		private var rot:Number;
		private var rotz:Number;
		private var crz:Number = 1.0;
		private var srz:Number = 0.0;
		private var sx:Number;
		private var sy:Number;
		
		private var pivotX:Number;
		private var pivotY:Number;
		private var offsetX:Number;
		private var offsetY:Number;
		private var frameOffsetXScaled:Number;
		private var frameOffsetYScaled:Number;
		
		private var uvRect:Rectangle;
		private var uvOffsetX:Number = 0.0;
		private var uvOffsetY:Number = 0.0;
		private var uvScaleX:Number = 1.0;
		private var uvScaleY:Number = 1.0;
		
		private var uv1x:Number = 0;
		private var uv1y:Number = 0;
		private var uv2x:Number = 0;
		private var uv2y:Number = 1;
		private var uv3x:Number = 1;
		private var uv3y:Number = 0;
		private var uv4x:Number = 1;
		private var uv4y:Number = 1;
		
		private var v1x:Number = -0.5;;
		private var v1y:Number = -0.5;
		private var v2x:Number = 0.5;
		private var v2y:Number = -0.5;
		private var v3x:Number = -0.5;
		private var v3y:Number = 0.5;
		private var v4x:Number = 0.5;
		private var v4y:Number = 0.5;
		
		private var v1x_prep:Number;
		private var v1y_prep:Number;
		private var v2x_prep:Number;
		private var v2y_prep:Number;
		private var v3x_prep:Number;
		private var v3y_prep:Number;
		private var v4x_prep:Number;
		private var v4y_prep:Number;
		
		private var v1x_tmp:Number;
		private var v1y_tmp:Number;
		private var v2x_tmp:Number;
		private var v2y_tmp:Number;
		private var v3x_tmp:Number;
		private var v3y_tmp:Number;
		private var v4x_tmp:Number;
		private var v4y_tmp:Number;
		
		private var parentWorldModelMatrixVector:Vector.<Number>;
		private var parentWorldModelMatrix_00:Number = 1.0;
		private var parentWorldModelMatrix_01:Number = 1.0;
		private var parentWorldModelMatrix_10:Number = 1.0;
		private var parentWorldModelMatrix_11:Number = 1.0;
		private var parentWorldModelMatrix_30:Number = 0.0;
		private var parentWorldModelMatrix_31:Number = 0.0;
		
		public function TexturedMeshCloudRenderer() 
		{
			
		}
		
		override public function init(context:Context3D, camera:Camera2D):void 
		{
			if ( isInited ) return;
			
			super.init(context, camera);
			
			maxVertices = 20000;
			vIndexBuffer = new Vector.<uint>((maxVertices - 2) * 3, true);
			
			baVertexBuffer = new ByteArray();
			baVertexBuffer.length = maxVertices * numFloatsPerVertex * 4;
			baVertexBuffer.endian = Endian.LITTLE_ENDIAN;
			
			ApplicationDomain.currentDomain.domainMemory = baVertexBuffer;
			
			createBuffersAndShaders();
		}
		
		override public function activate():void 
		{
			if ( !isInited ) return;
			
			ApplicationDomain.currentDomain.domainMemory = baVertexBuffer;
		}
		
		override public function handleDeviceLoss(context:Context3D):void 
		{
			super.handleDeviceLoss(context);
			
			vertexBuffer = null;
			indexBuffer = null;
			shader = null;
			shaderProgram = null;
			
			createBuffersAndShaders();
		}
		
		public function createBuffersAndShaders():void
		{
			if ( !vertexBuffer ) vertexBuffer = context.createVertexBuffer(maxVertices, numFloatsPerVertex);
			if ( !indexBuffer ) indexBuffer = context.createIndexBuffer(vIndexBuffer.length);
			if ( !shader ) shader = resourceManager.getResourceById("shader_TexturedMeshCloudRenderer") as Shader2D;
		}
		
		override public function prepare():void 
		{
			super.prepare();
			
			vertexBufferIndex = 0;
			indexBufferIndex = 0;
			totalVertices = 0;
			totalTriangles = 0;
			totalMeshes = 0;
			baVertexBuffer.position = 0;
			scissorRect = null;
			if ( vScissorRects.length ) vScissorRects.splice(0, vScissorRects.length);
			
			texture = null;
			mainTexture = null;
			parent = null;
			
			parentWorldModelMatrix_00 = 1.0;
			parentWorldModelMatrix_01 = 1.0;
			parentWorldModelMatrix_10 = 1.0;
			parentWorldModelMatrix_11 = 1.0;
			parentWorldModelMatrix_30 = 0.0;
			parentWorldModelMatrix_31 = 0.0;
		}
		
		public function updateNewParentData(node:Node2D):void
		{
			node.checkAndUpdateMatrixIfNeeded();
			
			parentWorldModelMatrixVector = node.worldModelMatrix.rawData;
			
			parentWorldModelMatrix_00 = parentWorldModelMatrixVector[0];
			parentWorldModelMatrix_01 = parentWorldModelMatrixVector[1];
			parentWorldModelMatrix_10 = parentWorldModelMatrixVector[4];
			parentWorldModelMatrix_11 = parentWorldModelMatrixVector[5];
			parentWorldModelMatrix_30 = parentWorldModelMatrixVector[12];
			parentWorldModelMatrix_31 = parentWorldModelMatrixVector[13];
		}
		
		override public function drawTexturedMesh(texture:Texture2D, useTextureSize:Boolean, vertices:Vector.<Vertex3D>, indices:Vector.<uint>, parent:Node2D, node:Node2D = null, x:Number = 0.0, y:Number = 0.0, z:Number = 0.0, scaleX:Number = 1.0, scaleY:Number = 1.0, scaleZ:Number = 1.0, rotationZ:Number = 0.0, rotationY:Number = 0.0, rotationX:Number = 0.0, r:Number = 1.0, g:Number = 1.0, b:Number = 1.0, a:Number = 1.0, uvOffsetX:Number = 0.0, uvOffsetY:Number = 0.0, uvScaleX:Number = 1.0, uvScaleY:Number = 1.0, blendModeSrc:String = Context3DBlendFactor.ONE, blendModeDst:String = Context3DBlendFactor.ONE_MINUS_SOURCE_ALPHA, pivotX:Number = 0.0, pivotY:Number = 0.0):void 
		{
			if ( this.parent != parent )
			{
				updateNewParentData(parent);
				this.parent = parent;
			}
			
			if ( this.texture != texture )
			{
				if ( mainTexture != texture.mainParent )
				{
					draw();
					mainTexture = texture.mainParent;
				}
				
				this.texture = texture;
				uvRect = texture.uvRect;
			}
			
			if ( this.blendModeSrc != blendModeSrc || this.blendModeDst != blendModeDst )
			{
				draw();
				this.blendModeSrc = blendModeSrc;
				this.blendModeDst = blendModeDst;
			}
			
			if ( totalVertices + vertices.length > maxVertices ) draw();
			
			// set triangle indices
			var i:int = 0;
			var n:int = indices.length;
			
			for (; i < n; i++) 
			{
				vIndexBuffer[indexBufferIndex + i] = indices[i] + totalVertices;
			}
			
			indexBufferIndex += n;
			totalTriangles += n / 3;
			
			// set vertices data
			
			// position
			if ( useTextureSize )
			{
				sx = scaleX * texture.bitmapWidth;
				sy = scaleY * texture.bitmapHeight;
			}
			else
			{
				sx = scaleX;
				sy = scaleY;
			}
			
			// rotation Z
			if ( rotationZ ) 
			{
				// now using faster cos/sin from: http://lab.polygonal.de/?p=205
				rotationZ %= 360.0;
				
				rotBase = rotationZ * DEG2RAD;
				
				if (rotBase < -3.14159265)
				{
					rotBase += 6.28318531;
				}
				else if (rotBase > 3.14159265)
				{
					rotBase -= 6.28318531;
				}
				
				// HIGH PRECISION
				// sin
				rot = (rotBase < 0.0) ? (1.27323954 * rotBase + .405284735 * rotBase * rotBase) : (1.27323954 * rotBase - 0.405284735 * rotBase * rotBase);
				srz = (rot < 0.0) ? (0.225 * (rot * -rot - rot) + rot) : (0.225 * (rot * rot - rot) + rot);
				
				// cos
				rotBase += 1.57079632;
				
				if (rotBase > 3.14159265)
				{
					rotBase -= 6.28318531;
				}
				
				rot = (rotBase < 0.0) ? (1.27323954 * rotBase + .405284735 * rotBase * rotBase) : (1.27323954 * rotBase - 0.405284735 * rotBase * rotBase);
				crz = (rot < 0.0) ? (0.225 * (rot * -rot - rot) + rot) : (0.225 * (rot * rot - rot) + rot);
			}
			else
			{
				crz = 1.0;
				srz = 0.0;
			}
			
			frameOffsetXScaled = texture.frameOffsetX * scaleX;
			frameOffsetYScaled = texture.frameOffsetY * scaleY;
			
			offsetX = x + (frameOffsetXScaled * crz - frameOffsetYScaled * srz);
			offsetY = y + (frameOffsetXScaled * srz + frameOffsetYScaled * crz);
			
			i = 0;
			n = vertices.length;
			var vertex:Vertex3D;
			
			for (; i < n; i++) 
			{
				vertex = vertices[i];
				
				v1x_prep = (vertex.x * sx - pivotX) * crz - (vertex.y * sy - pivotY) * srz + offsetX;
				v1y_prep = (vertex.x * sx - pivotX) * srz + (vertex.y * sy - pivotY) * crz + offsetY;
				
				// uv
				uv1x = uvRect.x + (uvRect.width * vertex.u);
				uv1y = uvRect.y + (uvRect.height * vertex.v);
				
				// set data to bytearray
				sf32(parentWorldModelMatrix_00 * v1x_prep + parentWorldModelMatrix_10 * v1y_prep + parentWorldModelMatrix_30, int(vertexBufferIndex));
				sf32(parentWorldModelMatrix_01 * v1x_prep + parentWorldModelMatrix_11 * v1y_prep + parentWorldModelMatrix_31, int(vertexBufferIndex + 4));
				
				sf32(uv1x * uvScaleX + uvOffsetX, int(vertexBufferIndex + 8));
				sf32(uv1y * uvScaleY + uvOffsetY, int(vertexBufferIndex + 12));
				
				sf32(r, int(vertexBufferIndex + 16));
				sf32(g, int(vertexBufferIndex + 20));
				sf32(b, int(vertexBufferIndex + 24));
				sf32(a, int(vertexBufferIndex + 28));
				
				// increment id
				vertexBufferIndex += 32;
				totalVertices ++;
			}
			
			totalMeshes ++;
		}
		
		override public function drawTexturedQuad(texture:Texture2D, useTextureSize:Boolean, parent:Node2D, node:Node2D = null, x:Number = 0.0, y:Number = 0.0, z:Number = 0.0, scaleX:Number = 1.0, scaleY:Number = 1.0, scaleZ:Number = 1.0, rotationZ:Number = 0.0, rotationY:Number = 0.0, rotationX:Number = 0.0, r:Number = 1.0, g:Number = 1.0, b:Number = 1.0, a:Number = 1.0, uvOffsetX:Number = 0.0, uvOffsetY:Number = 0.0, uvScaleX:Number = 1.0, uvScaleY:Number = 1.0, blendModeSrc:String = Context3DBlendFactor.ONE, blendModeDst:String = Context3DBlendFactor.ONE_MINUS_SOURCE_ALPHA, pivotX:Number = 0.0, pivotY:Number = 0.0):void 
		{
			if ( this.parent != parent )
			{
				updateNewParentData(parent);
				this.parent = parent;
			}
			
			if ( this.texture != texture )
			{
				if ( mainTexture != texture.mainParent )
				{
					draw();
					mainTexture = texture.mainParent;
				}
				
				this.texture = texture;
				uvRect = texture.uvRect;
			}
			
			if ( this.blendModeSrc != blendModeSrc || this.blendModeDst != blendModeDst )
			{
				draw();
				this.blendModeSrc = blendModeSrc;
				this.blendModeDst = blendModeDst;
			}
			
			if ( totalVertices + 4 > maxVertices ) draw();
			
			// triangle indices
			vIndexBuffer[indexBufferIndex++] = totalVertices + 0;
			vIndexBuffer[indexBufferIndex++] = totalVertices + 1;
			vIndexBuffer[indexBufferIndex++] = totalVertices + 3;
			vIndexBuffer[indexBufferIndex++] = totalVertices + 0;
			vIndexBuffer[indexBufferIndex++] = totalVertices + 3;
			vIndexBuffer[indexBufferIndex++] = totalVertices + 2;
			
			totalTriangles += 2;
			
			// vertices data
			
			// size
			if ( useTextureSize )
			{
				sx = scaleX * texture.bitmapWidth;
				sy = scaleY * texture.bitmapHeight;
			}
			else
			{
				sx = scaleX;
				sy = scaleY;
			}
			
			// rotation Z
			if ( rotationZ ) 
			{
				// now using faster cos/sin from: http://lab.polygonal.de/?p=205
				rotationZ %= 360.0;
				
				rotBase = rotationZ * DEG2RAD;
				
				if (rotBase < -3.14159265)
				{
					rotBase += 6.28318531;
				}
				else if (rotBase > 3.14159265)
				{
					rotBase -= 6.28318531;
				}
				
				// HIGH PRECISION
				// sin
				rot = (rotBase < 0.0) ? (1.27323954 * rotBase + .405284735 * rotBase * rotBase) : (1.27323954 * rotBase - 0.405284735 * rotBase * rotBase);
				srz = (rot < 0.0) ? (0.225 * (rot * -rot - rot) + rot) : (0.225 * (rot * rot - rot) + rot);
				
				// cos
				rotBase += 1.57079632;
				
				if (rotBase > 3.14159265)
				{
					rotBase -= 6.28318531;
				}
				
				rot = (rotBase < 0.0) ? (1.27323954 * rotBase + .405284735 * rotBase * rotBase) : (1.27323954 * rotBase - 0.405284735 * rotBase * rotBase);
				crz = (rot < 0.0) ? (0.225 * (rot * -rot - rot) + rot) : (0.225 * (rot * rot - rot) + rot);
			}
			else
			{
				crz = 1.0;
				srz = 0.0;
			}
			
			frameOffsetXScaled = texture.frameOffsetX * scaleX;
			frameOffsetYScaled = texture.frameOffsetY * scaleY;
			
			offsetX = x + (frameOffsetXScaled * crz - frameOffsetYScaled * srz);
			offsetY = y + (frameOffsetXScaled * srz + frameOffsetYScaled * crz);
			
			// ROTATION Z
			
			// v1
			v1x_tmp = v1x_prep = (v1x * sx - pivotX) * crz - (v1y * sy - pivotY) * srz + offsetX;
			v1y_tmp = v1y_prep = (v1x * sx - pivotX) * srz + (v1y * sy - pivotY) * crz + offsetY;
			
			//v2
			v2x_tmp = v2x_prep = (v2x * sx - pivotX) * crz - (v2y * sy - pivotY) * srz + offsetX;
			v2y_tmp = v2y_prep = (v2x * sx - pivotX) * srz + (v2y * sy - pivotY) * crz + offsetY;
			
			//v3
			v3x_tmp = v3x_prep = (v3x * sx - pivotX) * crz - (v3y * sy - pivotY) * srz + offsetX;
			v3y_tmp = v3y_prep = (v3x * sx - pivotX) * srz + (v3y * sy - pivotY) * crz + offsetY;
			
			//v4
			v4x_tmp = v4x_prep = (v4x * sx - pivotX) * crz - (v4y * sy - pivotY) * srz + offsetX;
			v4y_tmp = v4y_prep = (v4x * sx - pivotX) * srz + (v4y * sy - pivotY) * crz + offsetY;
			
			// UVs
			
			uv1x = uvRect.x;
			uv1y = uvRect.y;
			
			uv2x = uvRect.x + uvRect.width;
			uv2y = uvRect.y;
			
			uv3x = uvRect.x;
			uv3y = uvRect.y + uvRect.height;
			
			uv4x = uvRect.x + uvRect.width;
			uv4y = uvRect.y + uvRect.height;
			
			// v1
			sf32(parentWorldModelMatrix_00 * v1x_prep + parentWorldModelMatrix_10 * v1y_prep + parentWorldModelMatrix_30, int(vertexBufferIndex));
			sf32(parentWorldModelMatrix_01 * v1x_prep + parentWorldModelMatrix_11 * v1y_prep + parentWorldModelMatrix_31, int(vertexBufferIndex + 4));
			
			sf32(uv1x * uvScaleX + uvOffsetX, int(vertexBufferIndex + 8));
			sf32(uv1y * uvScaleY + uvOffsetY, int(vertexBufferIndex + 12));
			
			sf32(r, int(vertexBufferIndex + 16));
			sf32(g, int(vertexBufferIndex + 20));
			sf32(b, int(vertexBufferIndex + 24));
			sf32(a, int(vertexBufferIndex + 28));
			
			// v2
			
			sf32(parentWorldModelMatrix_00 * v2x_prep + parentWorldModelMatrix_10 * v2y_prep + parentWorldModelMatrix_30, int(vertexBufferIndex + 32));
			sf32(parentWorldModelMatrix_01 * v2x_prep + parentWorldModelMatrix_11 * v2y_prep + parentWorldModelMatrix_31, int(vertexBufferIndex + 36));
			
			sf32(uv2x * uvScaleX + uvOffsetX, int(vertexBufferIndex + 40));
			sf32(uv2y * uvScaleY + uvOffsetY, int(vertexBufferIndex + 44));
			
			sf32(r, int(vertexBufferIndex + 48));
			sf32(g, int(vertexBufferIndex + 52));
			sf32(b, int(vertexBufferIndex + 56));
			sf32(a, int(vertexBufferIndex + 60));
			
			// v3
			
			sf32(parentWorldModelMatrix_00 * v3x_prep + parentWorldModelMatrix_10 * v3y_prep + parentWorldModelMatrix_30, int(vertexBufferIndex + 64));
			sf32(parentWorldModelMatrix_01 * v3x_prep + parentWorldModelMatrix_11 * v3y_prep + parentWorldModelMatrix_31, int(vertexBufferIndex + 68));
			
			sf32(uv3x * uvScaleX + uvOffsetX, int(vertexBufferIndex + 72));
			sf32(uv3y * uvScaleY + uvOffsetY, int(vertexBufferIndex + 76));
			
			sf32(r, int(vertexBufferIndex + 80));
			sf32(g, int(vertexBufferIndex + 84));
			sf32(b, int(vertexBufferIndex + 88));
			sf32(a, int(vertexBufferIndex + 92));
			
			// v4
			
			sf32(parentWorldModelMatrix_00 * v4x_prep + parentWorldModelMatrix_10 * v4y_prep + parentWorldModelMatrix_30, int(vertexBufferIndex + 96));
			sf32(parentWorldModelMatrix_01 * v4x_prep + parentWorldModelMatrix_11 * v4y_prep + parentWorldModelMatrix_31, int(vertexBufferIndex + 100));
			
			sf32(uv4x * uvScaleX + uvOffsetX, int(vertexBufferIndex + 104));
			sf32(uv4y * uvScaleY + uvOffsetY, int(vertexBufferIndex + 108));
			
			sf32(r, int(vertexBufferIndex + 112));
			sf32(g, int(vertexBufferIndex + 116));
			sf32(b, int(vertexBufferIndex + 120));
			sf32(a, int(vertexBufferIndex + 124));
			
			vertexBufferIndex += 128;
			totalVertices += 4;
			
			totalMeshes ++;
		}
		
		override public function draw():void 
		{
			if ( totalVertices < 1 ) return;
			
			// upload vertexBuffer
			vertexBuffer.uploadFromByteArray(baVertexBuffer, 0, 0, maxVertices);
			
			// upload indexBuffer
			indexBuffer.uploadFromVector(vIndexBuffer, 0, vIndexBuffer.length);
			
			// blend factors
			context.setBlendFactors(blendModeSrc, blendModeDst);
			
			// shader
			if ( !shaderProgram ) shaderProgram = shader.getShaderProgram(context, texture);
			context.setProgram(shaderProgram.program);
			
			// texture
			context.setTextureAt(0, texture.getTexture(context));
			
			// vertices data
			context.setVertexBufferAt(0, vertexBuffer, 0, Context3DVertexBufferFormat.FLOAT_2); // position
			context.setVertexBufferAt(1, vertexBuffer, 2, Context3DVertexBufferFormat.FLOAT_2); // uv
			context.setVertexBufferAt(2, vertexBuffer, 4, Context3DVertexBufferFormat.FLOAT_4); // color
			
			context.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX, 0, viewProjectionMatrix, true);
			
			if ( scissorRect ) context.setScissorRectangle(scissorRect);
			
			// draw
			context.drawTriangles(indexBuffer, 0, totalTriangles);
			
			// reset
			context.setTextureAt(0, null);
			context.setVertexBufferAt(0, null);
			context.setVertexBufferAt(1, null);
			context.setVertexBufferAt(2, null);
			context.setScissorRectangle(null);
			
			Statistics.triangles += totalTriangles;
			Statistics.sprites += totalMeshes;
			Statistics.drawCalls++;
			
			vertexBufferIndex = 0;
			indexBufferIndex = 0;
			totalVertices = 0;
			totalTriangles = 0;
			totalMeshes = 0;
			baVertexBuffer.position = 0;
		}
	}

}