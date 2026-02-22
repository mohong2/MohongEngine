package;

 
 
import flixel.graphics.frames.FlxAtlasFrames;
 
import RGBPalette;
import flixel.system.FlxAssets.FlxShader;
import flixel.util.FlxStringUtil;
import sys.FileSystem;
import sys.io.File;
using StringTools;
typedef NoteSplashConfig = {
		anim:String,
		minFps:Int,
		maxFps:Int,
		offsets:Array<Array<Float>>
}

class NoteSplash extends FlxSprite
{
	public var rgbShader:PixelSplashShaderRef;
	private var idleAnim:String;
	private var _textureLoaded:String = null;
	private var _configLoaded:String = null;
	private var maxAnims:Int = 0;
	
	public static var defaultNoteSplash(default, never):String = 'noteSplashes';
	public static var configs:Map<String, NoteSplashConfig> = new Map<String, NoteSplashConfig>();
	


	public function new(x:Float = 0, y:Float = 0, ?note:Int = 0) {
		super(x, y);
		
		var skin:String = defaultNoteSplash;
		if(PlayState.SONG != null && PlayState.SONG.splashSkin != null && PlayState.SONG.splashSkin.length > 0) 
			skin = PlayState.SONG.splashSkin;
		
		skin += getSplashSkinPostfix();
		
		rgbShader = new PixelSplashShaderRef();
		shader = rgbShader.shader;
		precacheConfig(skin);
		_configLoaded = skin;
		
		setupNoteSplash(x, y, note);
		antialiasing = ClientPrefs.data.globalAntialiasing;
	}

	public function setupNoteSplash(x:Float = 0, y:Float = 0, note:Int = 0, texture:String = null, hueColor:Float = 0, satColor:Float = 0, brtColor:Float = 0) {
		setPosition(x - Note.swagWidth * 0.95, y - Note.swagWidth);
		alpha = ClientPrefs.data.splashAlpha;
		
		if(texture == null) {
			texture = defaultNoteSplash;
			if(PlayState.SONG != null && PlayState.SONG.splashSkin != null && PlayState.SONG.splashSkin.length > 0) 
				texture = PlayState.SONG.splashSkin;
		}
		texture += getSplashSkinPostfix();
		
		if(_textureLoaded != texture) {
			loadAnims(texture);
		}
		
		offset.set(10, 10);

		var animNum:Int = maxAnims > 0 ? FlxG.random.int(1, maxAnims) : 1;
		animation.play('note' + note + '-' + animNum, true);
		
		var minFps:Int = 22;
		var maxFps:Int = 26;
		var config:NoteSplashConfig = precacheConfig(_configLoaded);
		
		if(config != null) {
			var animID:Int = note + ((animNum - 1) * 4);
			if(animID < config.offsets.length) {
				var offs:Array<Float> = config.offsets[animID];
				offset.x += offs[0];
				offset.y += offs[1];
			}
			minFps = config.minFps;
			maxFps = config.maxFps;
		} else {
			offset.x += -58;
			offset.y += -55;
		}
		
		if(animation.curAnim != null)
			animation.curAnim.frameRate = FlxG.random.int(minFps, maxFps);
	}

	public static function getSplashSkinPostfix() {
		if(ClientPrefs.data.splashSkin == null) return "";
		
		var skin:String = '';
		if(ClientPrefs.data.splashSkin != null && ClientPrefs.data.splashSkin.length > 0)
			skin = '-' + ClientPrefs.data.splashSkin.trim().toLowerCase().replace(' ', '_');
		return skin;
	}
	
	function loadAnims(skin:String, ?animName:String = null):NoteSplashConfig {
		maxAnims = 0;
		frames = Paths.getSparrowAtlas(skin);
		var config:NoteSplashConfig = precacheConfig(skin);
		_configLoaded = skin;
		
		if(frames == null) {
			skin = defaultNoteSplash + getSplashSkinPostfix();
			frames = Paths.getSparrowAtlas(skin);
			config = precacheConfig(skin);
		}
		
		if(animName == null && config != null)
			animName = config.anim;
		if(animName == null) animName = 'note splash';
		
		var animAdded = true;
		while(animAdded) {
			var animID:Int = maxAnims + 1;
			animAdded = false;
			
			for (i in 0...4) { // 4个方向
				var animNameFull = '$animName ${getColorString(i)} $animID';
				if (frames.getByName(animNameFull) != null) {
					animation.addByPrefix('note$i-$animID', animNameFull, 24, false);
					animAdded = true;
				}
			}
			
			if(animAdded) maxAnims++;
		}
		
		return config;
	}
	
	function getColorString(dir:Int):String {
		return switch(dir) {
			case 0: "purple";
			case 1: "blue";
			case 2: "green";
			case 3: "red";
			default: "unknown";
		}
	}
	
	public static function precacheConfig(skin:String):NoteSplashConfig {
		if(configs.exists(skin)) return configs.get(skin);
		
		var path:String = Paths.getPath('images/$skin.txt', TEXT);
		if(!FileSystem.exists(path)) return null;
		
		var configFile:Array<String> = File.getContent(path).split('\n');
		if(configFile.length < 1) return null;
		
		var framerates:Array<String> = configFile[1].split(' ');
		var offs:Array<Array<Float>> = [];
		for (i in 2...configFile.length) {
			var animOffs:Array<String> = configFile[i].split(' ');
			if(animOffs.length >= 2) {
				offs.push([Std.parseFloat(animOffs[0]), Std.parseFloat(animOffs[1])]);
			}
		}

		var config:NoteSplashConfig = {
			anim: configFile[0],
			minFps: Std.parseInt(framerates[0]),
			maxFps: Std.parseInt(framerates[1]),
			offsets: offs
		};
		configs.set(skin, config);
		return config;
	}
	
	var aliveTime:Float = 0;
	override function update(elapsed:Float) {
		aliveTime += elapsed;
		if((animation.curAnim != null && animation.curAnim.finished) || aliveTime >= 0.5) 
			kill();
		
		super.update(elapsed);
	}
}

class PixelSplashShaderRef {
	public var shader:PixelSplashShader = new PixelSplashShader();
	
	public function copyValues(tempShader:RGBPalette) {
		if(tempShader != null) {
			shader.r.value = tempShader.shader.r.value.copy();
			shader.g.value = tempShader.shader.g.value.copy();
			shader.b.value = tempShader.shader.b.value.copy();
			shader.mult.value[0] = tempShader.shader.mult.value[0];
		} else {
			shader.mult.value[0] = 0.0;
		}
	}

	public function new() {
		shader.r.value = [0, 0, 0];
		shader.g.value = [0, 0, 0];
		shader.b.value = [0, 0, 0];
		shader.mult.value = [1];
	}
}

class PixelSplashShader extends FlxShader {
	@:glFragmentHeader('
		#pragma header
		uniform vec3 r;
		uniform vec3 g;
		uniform vec3 b;
		uniform float mult;

		vec4 flixel_texture2DCustom(sampler2D bitmap, vec2 coord) {
			vec4 color = flixel_texture2D(bitmap, coord);
			if (!hasTransform) {
				return color;
			}

			if(color.a == 0.0 || mult == 0.0) {
				return color * openfl_Alphav;
			}

			vec4 newColor = color;
			newColor.rgb = min(color.r * r + color.g * g + color.b * b, vec3(1.0));
			newColor.a = color.a;
			
			color = mix(color, newColor, mult);
			
			if(color.a > 0.0) {
				return vec4(color.rgb, color.a);
			}
			return vec4(0.0, 0.0, 0.0, 0.0);
		}')

	@:glFragmentSource('
		#pragma header
		void main() {
			gl_FragColor = flixel_texture2DCustom(bitmap, openfl_TextureCoordv);
		}')

	public function new() {
		super();
	}
}