package psychlua;

import backend.MusicBeatState;
import backend.MusicBeatSubstate;
import StageData;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.group.FlxSpriteGroup;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxEase.EaseFunction;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;
import openfl.display.BlendMode;
import animateatlas.AtlasFrameMaker;
import script.lua.FunkinLua;
import states.PlayState;
import substates.GameOverSubstate;
#if LUA_ALLOWED
import llua.Lua;
#end

import Type.ValueType;

using StringTools;

/**
 * LuaUtils - 向上兼容 104 版本的 psychlua.LuaUtils
 * 将 104 的 API 映射到当前 0.6.3 引擎的实现上
 */
class LuaUtils
{
	// ==================== 常量 ====================

	// 使用当前引擎的值（整数），与 FunkinLua 保持一致
	public static var Function_Stop:Dynamic = 1;
	public static var Function_Continue:Dynamic = 0;
	public static var Function_StopLua:Dynamic = 2;
	public static var Function_StopHScript:Dynamic = 3;
	public static var Function_StopAll:Dynamic = 4;

	// ==================== Tween 工具 ====================

	/**
	 * 从动态对象解析 LuaTweenOptions
	 */
	public static function getLuaTween(options:Dynamic):Dynamic
	{
		return (options != null) ? {
			type: getTweenTypeByString(options.type),
			startDelay: options.startDelay,
			onUpdate: options.onUpdate,
			onStart: options.onStart,
			onComplete: options.onComplete,
			loopDelay: options.loopDelay,
			ease: getTweenEaseByString(options.ease)
		} : null;
	}

	// ==================== 变量操作 (委托给 FunkinLua) ====================

	public static function setVarInArray(instance:Dynamic, variable:String, value:Dynamic, allowMaps:Bool = false):Any
	{
		return FunkinLua.setVarInArray(instance, variable, value, allowMaps);
	}

	public static function getVarInArray(instance:Dynamic, variable:String, allowMaps:Bool = false):Any
	{
		return FunkinLua.getVarInArray(instance, variable, allowMaps);
	}

	public static function getModSetting(saveTag:String, ?modName:String = null):Dynamic
	{
		return FunkinLua.getModSetting(saveTag, modName);
	}

	public static function isMap(variable:Dynamic):Bool
	{
		return FunkinLua.isMap(variable);
	}

	public static function isOfTypes(value:Any, types:Array<Dynamic>):Bool
	{
		return FunkinLua.isOfTypes(value, types);
	}

	public static function isLuaSupported(value:Any):Bool
	{
		return (value == null || isOfTypes(value, [Bool, Int, Float, String, Array]) || Type.typeof(value) == ValueType.TObject);
	}

	// ==================== 对象/属性操作 ====================

	/**
	 * 修改组/数组里的属性 (复现 104 逻辑)
	 */
	public static function setGroupStuff(leArray:Dynamic, variable:String, value:Dynamic, ?allowMaps:Bool = false):Dynamic
	{
		var split:Array<String> = variable.split('.');
		if (split.length > 1)
		{
			var obj:Dynamic = Reflect.getProperty(leArray, split[0]);
			for (i in 1...split.length - 1)
				obj = Reflect.getProperty(obj, split[i]);
			leArray = obj;
			variable = split[split.length - 1];
		}
		if (allowMaps && isMap(leArray))
			leArray.set(variable, value);
		else
			Reflect.setProperty(leArray, variable, value);
		return value;
	}

	/**
	 * 读取组/数组里的属性 (复现 104 逻辑)
	 */
	public static function getGroupStuff(leArray:Dynamic, variable:String, ?allowMaps:Bool = false):Dynamic
	{
		var split:Array<String> = variable.split('.');
		if (split.length > 1)
		{
			var obj:Dynamic = Reflect.getProperty(leArray, split[0]);
			for (i in 1...split.length - 1)
				obj = Reflect.getProperty(obj, split[i]);
			leArray = obj;
			variable = split[split.length - 1];
		}
		if (allowMaps && isMap(leArray))
			return leArray.get(variable);
		return Reflect.getProperty(leArray, variable);
	}

	/**
	 * getPropertyLoop (不带 checkForTextsToo 参数, 匹配 104)
	 */
	public static function getPropertyLoop(split:Array<String>, ?getProperty:Bool = true, ?allowMaps:Bool = false):Dynamic
	{
		return FunkinLua.getPropertyLoop(split, true, getProperty, allowMaps);
	}

	/**
	 * getObjectDirectly (匹配 104 签名)
	 */
	public static function getObjectDirectly(objectName:String, ?allowMaps:Bool = false):Dynamic
	{
		return FunkinLua.getObjectDirectly(objectName, true);
	}

	// ==================== 实例工具 ====================

	public static function getTargetInstance():Dynamic
	{
		return FunkinLua.getTargetInstance();
	}

	public static function getLowestCharacterGroup():FlxSpriteGroup
	{
		if (PlayState.instance == null) return null;

		var stageData:StageFile = StageData.getStageFile(PlayState.SONG.stage);
		var group:FlxSpriteGroup = (stageData.hide_girlfriend ? PlayState.instance.boyfriendGroup : PlayState.instance.gfGroup);
		var pos:Int = PlayState.instance.members.indexOf(group);

		var newPos:Int = PlayState.instance.members.indexOf(PlayState.instance.boyfriendGroup);
		if (newPos < pos)
		{
			group = PlayState.instance.boyfriendGroup;
			pos = newPos;
		}

		newPos = PlayState.instance.members.indexOf(PlayState.instance.dadGroup);
		if (newPos < pos)
		{
			group = PlayState.instance.dadGroup;
			pos = newPos;
		}
		return group;
	}

	// ==================== 动画 / 纹理 ====================

	public static function addAnimByIndices(obj:String, name:String, prefix:String, indices:Any = null, framerate:Int = 24, loop:Bool = false):Bool
	{
		var target:FlxSprite = cast getObjectDirectly(obj);
		if (target != null && target.animation != null)
		{
			if (indices == null)
				indices = [0];
			else if (Std.isOfType(indices, String))
			{
				var strIndices:Array<String> = cast(indices, String).trim().split(',');
				var myIndices:Array<Int> = [];
				for (i in 0...strIndices.length)
					myIndices.push(Std.parseInt(strIndices[i]));
				indices = myIndices;
			}

			var finalIndices:Array<Int> = cast indices;
			if (prefix != null)
				target.animation.addByIndices(name, prefix, finalIndices, '', framerate, loop);
			else
				target.animation.add(name, finalIndices, framerate, loop);

			if (target.animation.curAnim == null)
			{
				var dyn:Dynamic = cast target;
				if (dyn.playAnim != null)
					dyn.playAnim(name, true);
				else
					dyn.animation.play(name, true);
			}
			return true;
		}
		return false;
	}

	public static function loadFrames(spr:FlxSprite, image:String, spriteType:String):Void
	{
		switch (spriteType.toLowerCase().trim())
		{
			case "texture" | "textureatlas" | "tex":
				spr.frames = AtlasFrameMaker.construct(image);
			case "texture_noaa" | "textureatlas_noaa" | "tex_noaa":
				spr.frames = AtlasFrameMaker.construct(image, null, true);
			case "packer" | "packeratlas" | "pac":
				spr.frames = Paths.getPackerAtlas(image);
			default:
				spr.frames = Paths.getSparrowAtlas(image);
		}
	}

	// ==================== 生命周期管理 ====================

	public static function destroyObject(tag:String):Void
	{
		var variables = getStateVars();
		if (variables == null) return;

		var obj:FlxSprite = variables.get(tag);
		if (obj == null || obj.destroy == null) return;

		getTargetInstance().remove(obj, true);
		obj.destroy();
		variables.remove(tag);
	}

	public static function cancelTween(tag:String):Void
	{
		if (!tag.startsWith('tween_'))
			tag = 'tween_' + formatVariable(tag);

		var variables = getStateVars();
		if (variables == null) return;

		var twn:FlxTween = variables.get(tag);
		if (twn != null)
		{
			twn.cancel();
			twn.destroy();
			variables.remove(tag);
		}
	}

	public static function cancelTimer(tag:String):Void
	{
		if (!tag.startsWith('timer_'))
			tag = 'timer_' + formatVariable(tag);

		var variables = getStateVars();
		if (variables == null) return;

		var tmr:FlxTimer = variables.get(tag);
		if (tmr != null)
		{
			tmr.cancel();
			tmr.destroy();
			variables.remove(tag);
		}
	}

	public static function formatVariable(tag:String):String
	{
		return tag.trim().replace(' ', '_').replace('.', '');
	}

	public static function tweenPrepare(tag:String, vars:String):Dynamic
	{
		if (tag != null) cancelTween(tag);

		var variables:Array<String> = vars.split('.');
		var sexyProp:Dynamic = getObjectDirectly(variables[0]);
		if (variables.length > 1)
			sexyProp = getVarInArray(getPropertyLoop(variables), variables[variables.length - 1]);
		return sexyProp;
	}

	// ==================== 平台 / 构建信息 ====================

	public static function getBuildTarget():String
	{
		#if windows
		return 'windows';
		#elseif linux
		return 'linux';
		#elseif mac
		return 'mac';
		#elseif html5
		return 'browser';
		#elseif android
		return 'android';
		#else
		return 'unknown';
		#end
	}

	// ==================== 字符串 -> 枚举 映射 ====================

	public static function getTweenTypeByString(?type:String = ''):Dynamic
	{
		switch (type.toLowerCase().trim())
		{
			case 'backward':   return 16;
			case 'looping', 'loop': return 2;
			case 'persist':    return 1;
			case 'pingpong':   return 4;
		}
		return 8;
	}

	public static function getTweenEaseByString(?ease:String = ''):EaseFunction
	{
		switch (ease.toLowerCase().trim())
		{
			case 'backin':           return FlxEase.backIn;
			case 'backinout':        return FlxEase.backInOut;
			case 'backout':          return FlxEase.backOut;
			case 'bouncein':         return FlxEase.bounceIn;
			case 'bounceinout':      return FlxEase.bounceInOut;
			case 'bounceout':        return FlxEase.bounceOut;
			case 'circin':           return FlxEase.circIn;
			case 'circinout':        return FlxEase.circInOut;
			case 'circout':          return FlxEase.circOut;
			case 'cubein':           return FlxEase.cubeIn;
			case 'cubeinout':        return FlxEase.cubeInOut;
			case 'cubeout':          return FlxEase.cubeOut;
			case 'elasticin':        return FlxEase.elasticIn;
			case 'elasticinout':     return FlxEase.elasticInOut;
			case 'elasticout':       return FlxEase.elasticOut;
			case 'expoin':           return FlxEase.expoIn;
			case 'expoinout':        return FlxEase.expoInOut;
			case 'expoout':          return FlxEase.expoOut;
			case 'quadin':           return FlxEase.quadIn;
			case 'quadinout':        return FlxEase.quadInOut;
			case 'quadout':          return FlxEase.quadOut;
			case 'quartin':          return FlxEase.quartIn;
			case 'quartinout':       return FlxEase.quartInOut;
			case 'quartout':         return FlxEase.quartOut;
			case 'quintin':          return FlxEase.quintIn;
			case 'quintinout':       return FlxEase.quintInOut;
			case 'quintout':         return FlxEase.quintOut;
			case 'sinein':           return FlxEase.sineIn;
			case 'sineinout':        return FlxEase.sineInOut;
			case 'sineout':          return FlxEase.sineOut;
			case 'smoothstepin':     return FlxEase.smoothStepIn;
			case 'smoothstepinout':  return FlxEase.smoothStepInOut;
			case 'smoothstepout':    return FlxEase.smoothStepOut;
			case 'smootherstepin':   return FlxEase.smootherStepIn;
			case 'smootherstepinout':return FlxEase.smootherStepInOut;
			case 'smootherstepout':  return FlxEase.smootherStepOut;
		}
		return FlxEase.linear;
	}

	public static function blendModeFromString(blend:String):BlendMode
	{
		switch (blend.toLowerCase().trim())
		{
			case 'add':        return ADD;
			case 'alpha':      return ALPHA;
			case 'darken':     return DARKEN;
			case 'difference': return DIFFERENCE;
			case 'erase':      return ERASE;
			case 'hardlight':  return HARDLIGHT;
			case 'invert':     return INVERT;
			case 'layer':      return LAYER;
			case 'lighten':    return LIGHTEN;
			case 'multiply':   return MULTIPLY;
			case 'overlay':    return OVERLAY;
			case 'screen':     return SCREEN;
			case 'shader':     return SHADER;
			case 'subtract':   return SUBTRACT;
		}
		return NORMAL;
	}

	#if LUA_ALLOWED
	public static function typeToString(type:Int):String
	{
		switch (type)
		{
			case Lua.LUA_TBOOLEAN: return "boolean";
			case Lua.LUA_TNUMBER:  return "number";
			case Lua.LUA_TSTRING:  return "string";
			case Lua.LUA_TTABLE:   return "table";
			case Lua.LUA_TFUNCTION:return "function";
		}
		if (type <= Lua.LUA_TNIL) return "nil";
		return "unknown";
	}
	#end

	public static function cameraFromString(cam:String):FlxCamera
	{
		if (PlayState.instance != null)
		{
			switch (cam.toLowerCase())
			{
				case 'camgame' | 'game': return PlayState.instance.camGame;
				case 'camhud'  | 'hud':  return PlayState.instance.camHUD;
				case 'camother' | 'other': return PlayState.instance.camOther;
			}
		}
		var variables = getStateVars();
		if (variables != null)
		{
			var camera:FlxCamera = variables.get(cam);
			if (camera != null && Std.isOfType(camera, FlxCamera))
				return camera;
		}
		if (PlayState.instance != null) return PlayState.instance.camGame;
		return FlxG.camera;
	}

	// ==================== 内部辅助 ====================

	static function getStateVars():Map<String, Dynamic>
	{
		if (PlayState.instance != null)
			return PlayState.instance.variables;
		var state = FlxG.state;
		if (Std.isOfType(state, MusicBeatState))
			return cast(state, MusicBeatState).variables;
		if (Std.isOfType(state, MusicBeatSubstate))
			return cast(state, MusicBeatSubstate).variables;
		return null;
	}
}
