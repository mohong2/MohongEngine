package shaders;

import flixel.FlxSprite;
import flixel.math.FlxMath;
import flixel.system.FlxAssets.FlxShader;
import flixel.util.FlxColor;
import ClientPrefs;

/**
 * RGBPalette — Psych Engine 0.7.3/1.0.4 的 Note 三色着色器。
 *
 * 移植自 FNF-PsychEngine-EK-0.7.3 (多k 分支), 并按 SeiunEngine 需求做了
 * "灵活回退" 扩展:
 *  - 默认不接管精灵着色器 (本引擎继续走 colorSwap 的多k 轨道色);
 *  - 只有模组脚本真正修改 rgbShader.r/g/b/mult 时才克隆全局色板并挂载,
 *    保证 `rgbShader.mult = 0` 这类 0.7.3/1.0.4 脚本直接可用;
 *  - rgbShader.enabled = false 时回退到引擎默认着色器 (fallbackShader),
 *    而不是像原版那样直接置 null;
 *  - ClientPrefs.data.shaders 关闭时禁止挂载, 保持无着色器渲染。
 *
 * 全局色板按 (noteData + mania) 缓存, 同一轨道所有 Note 共享一份 uniform,
 * 避免每个 Note 各建一个 shader 的开销。
 */
class RGBPalette
{
	public var shader(default, null):RGBPaletteShader = new RGBPaletteShader();
	public var r(default, set):FlxColor;
	public var g(default, set):FlxColor;
	public var b(default, set):FlxColor;
	public var mult(default, set):Float;

	private function set_r(color:FlxColor):FlxColor
	{
		r = color;
		shader.r.value = [color.redFloat, color.greenFloat, color.blueFloat];
		return color;
	}

	private function set_g(color:FlxColor):FlxColor
	{
		g = color;
		shader.g.value = [color.redFloat, color.greenFloat, color.blueFloat];
		return color;
	}

	private function set_b(color:FlxColor):FlxColor
	{
		b = color;
		shader.b.value = [color.redFloat, color.greenFloat, color.blueFloat];
		return color;
	}

	private function set_mult(value:Float):Float
	{
		mult = FlxMath.bound(value, 0, 1);
		shader.mult.value = [mult];
		return mult;
	}

	public function new()
	{
		r = 0xFFFF0000;
		g = 0xFF00FF00;
		b = 0xFF0000FF;
		mult = 1.0;
	}
}

/**
 * 精灵持有的 RGB 色板引用: 读写转发到共享色板, 首次修改时克隆,
 * 避免一个模组脚本改色影响整条轨道 (与 0.7.3/1.0.4 语义一致)。
 */
class RGBShaderReference
{
	public var r(default, set):FlxColor;
	public var g(default, set):FlxColor;
	public var b(default, set):FlxColor;
	public var mult(default, set):Float;
	public var enabled(default, set):Bool = false;

	/** 共享的全局色板 (同一轨道所有 Note 共享)。 */
	public var parent:RGBPalette;

	private var _owner:FlxSprite;
	private var _original:RGBPalette;

	/** enabled=false 时回退到的着色器 (本引擎: colorSwap.shader; null = 无着色器)。 */
	public var fallbackShader:FlxShader = null;

	/**
	 * 中性感知回退: 优先用 ColorSwap 引用解析 —— 中性色时不挂任何着色器
	 * (万级 Note 合批关键), 非中性时才实例化其 GLSL 程序。
	 */
	public var fallbackColorSwap:ColorSwap = null;

	/** SONG.disableNoteRGB 时禁止挂载 RGB 着色器。 */
	public var forceDisabled:Bool = false;

	public function new(owner:FlxSprite, ref:RGBPalette)
	{
		parent = ref;
		_owner = owner;
		_original = ref;

		@:bypassAccessor
		{
			r = parent.r;
			g = parent.g;
			b = parent.b;
			mult = parent.mult;
		}
	}

	/** 复用对象时重新绑定到另一条轨道的共享色板 (池化 Note/换 k 值用)。 */
	public function rebind(ref:RGBPalette):Void
	{
		parent = ref;
		_original = ref;
		allowNew = true;
		@:bypassAccessor
		{
			r = parent.r;
			g = parent.g;
			b = parent.b;
			mult = parent.mult;
		}
		enabled = false;
	}

	private function set_r(value:FlxColor):FlxColor
	{
		if (allowNew && value != _original.r) cloneOriginal();
		return (r = parent.r = value);
	}

	private function set_g(value:FlxColor):FlxColor
	{
		if (allowNew && value != _original.g) cloneOriginal();
		return (g = parent.g = value);
	}

	private function set_b(value:FlxColor):FlxColor
	{
		if (allowNew && value != _original.b) cloneOriginal();
		return (b = parent.b = value);
	}

	private function set_mult(value:Float):Float
	{
		if (allowNew && value != _original.mult) cloneOriginal();
		return (mult = parent.mult = value);
	}

	private function set_enabled(value:Bool):Bool
	{
		enabled = value;
		if (value && !forceDisabled && ClientPrefs.data.shaders)
			_owner.shader = parent.shader;
		else if (fallbackColorSwap != null)
		{
			if (ClientPrefs.data.perfMode && fallbackColorSwap.isNeutral())
				_owner.shader = null;
			else
				_owner.shader = fallbackColorSwap.shader;
		}
		else
			_owner.shader = fallbackShader;
		return enabled;
	}

	public var allowNew:Bool = true;

	private function cloneOriginal():Void
	{
		if (!allowNew) return;
		allowNew = false;
		if (_original != parent) return;

		parent = new RGBPalette();
		parent.r = _original.r;
		parent.g = _original.g;
		parent.b = _original.b;
		parent.mult = _original.mult;
		// 通过 setter 挂载, 以便遵守 forceDisabled / shaders 开关的灵活回退
		enabled = true;
	}
}

class RGBPaletteShader extends FlxShader
{
	@:glFragmentHeader('
		#pragma header

		uniform vec3 r;
		uniform vec3 g;
		uniform vec3 b;
		uniform float mult;

		vec4 flixel_texture2DCustom(sampler2D bitmap, vec2 coord) {
			vec4 color = flixel_texture2D(bitmap, coord);
			if (!hasTransform || color.a == 0.0 || mult == 0.0) {
				return color;
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

	public function new()
	{
		super();
	}
}
