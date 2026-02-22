package android.flixel;

 
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxTileFrames;
 
 
import flixel.util.FlxDestroyUtil;
import android.flixel.FlxButton;
import openfl.display.BitmapData;
import openfl.utils.Assets;

enum FlxDPadMode
{
	UP_DOWN;
	LEFT_RIGHT;
	LEFT_FULL;
	RIGHT_FULL;
	BOTH_FULL;
	DIALOGUE_PORTRAIT_EDITOR;
	MENU_CHARACTER_EDITOR;
	NONE;
}

enum FlxActionMode
{
	A;
	B;
	P;
	A_B;
	A_B_C;
	A_B_E;
	A_B_X_Y;
	A_B_C_X_Y;
	A_B_C_X_Y_Z;
	A_B_C_D_V_X_Y_Z;
	CHART_EDITOR;
	CHARACTER_EDITOR;
	DIALOGUE_PORTRAIT_EDITOR;
	MENU_CHARACTER_EDITOR;
	NONE;
}

/**
 * A gamepad.
 * It's easy to customize the layout.
 *
 * @author Ka Wing Chin
 * @author Mihai Alexandru (M.A. Jigsaw)
 */
class FlxVirtualPad extends FlxTypedSpriteGroup<FlxButton>
{
	public var buttonLeft:FlxButton = new FlxButton(0, 0);
	public var buttonUp:FlxButton = new FlxButton(0, 0);
	public var buttonRight:FlxButton = new FlxButton(0, 0);
	public var buttonDown:FlxButton = new FlxButton(0, 0);

	public var buttonLeft2:FlxButton = new FlxButton(0, 0);
	public var buttonUp2:FlxButton = new FlxButton(0, 0);
	public var buttonRight2:FlxButton = new FlxButton(0, 0);
	public var buttonDown2:FlxButton = new FlxButton(0, 0);

	public var buttonA:FlxButton = new FlxButton(0, 0);
	public var buttonB:FlxButton = new FlxButton(0, 0);
	public var buttonP:FlxButton = new FlxButton(0, 0);
	public var buttonC:FlxButton = new FlxButton(0, 0);
	public var buttonD:FlxButton = new FlxButton(0, 0);
	public var buttonE:FlxButton = new FlxButton(0, 0);
	public var buttonF:FlxButton = new FlxButton(0, 0);
	public var buttonG:FlxButton = new FlxButton(0, 0);
	public var buttonV:FlxButton = new FlxButton(0, 0);
	public var buttonX:FlxButton = new FlxButton(0, 0);
	public var buttonY:FlxButton = new FlxButton(0, 0);
	public var buttonZ:FlxButton = new FlxButton(0, 0);

	public var buttonEx:FlxButton = new FlxButton(0, 0);

	/**
	 * Create a gamepad.
	 *
	 * @param   DPadMode     The D-Pad mode. `LEFT_FULL` for example.
	 * @param   ActionMode   The action buttons mode. `A_B_C` for example.
	 */
	public function new(DPad:FlxDPadMode, Action:FlxActionMode, ?Extra:Bool = false):Void
	{
		super();

		switch (DPad)
		{
			case UP_DOWN:
				add(buttonUp = createButton(0, FlxG.height - 258, 'up', 0x00FF00));
				add(buttonDown = createButton(0, FlxG.height - 131, 'down', 0x00FFFF));
			case LEFT_RIGHT:
				add(buttonLeft = createButton(0, FlxG.height - 131, 'left', 0xFF00FF));
				add(buttonRight = createButton(127, FlxG.height - 131, 'right', 0xFF0000));
			case LEFT_FULL:
				add(buttonUp = createButton(105, FlxG.height - 356, 'up', 0x00FF00));
				add(buttonLeft = createButton(0, FlxG.height - 246, 'left', 0xFF00FF));
				add(buttonRight = createButton(207, FlxG.height - 246, 'right', 0xFF0000));
				add(buttonDown = createButton(105, FlxG.height - 131, 'down', 0x00FFFF));
			case RIGHT_FULL:
				add(buttonUp = createButton(FlxG.width - 258, FlxG.height - 404, 'up', 0x00FF00));
				add(buttonLeft = createButton(FlxG.width - 384, FlxG.height - 305, 'left', 0xFF00FF));
				add(buttonRight = createButton(FlxG.width - 132, FlxG.height - 305, 'right', 0xFF0000));
				add(buttonDown = createButton(FlxG.width - 258, FlxG.height - 197, 'down', 0x00FFFF));
			case BOTH_FULL:
				add(buttonUp = createButton(105, FlxG.height - 356, 'up', 0x00FF00));
				add(buttonLeft = createButton(0, FlxG.height - 246, 'left', 0xFF00FF));
				add(buttonRight = createButton(207, FlxG.height - 246, 'right', 0xFF0000));
				add(buttonDown = createButton(105, FlxG.height - 131, 'down', 0x00FFFF));
				add(buttonUp2 = createButton(FlxG.width - 258, FlxG.height - 404, 'up', 0x00FF00));
				add(buttonLeft2 = createButton(FlxG.width - 384, FlxG.height - 305, 'left', 0xFF00FF));
				add(buttonRight2 = createButton(FlxG.width - 132, FlxG.height - 305, 'right', 0xFF0000));
				add(buttonDown2 = createButton(FlxG.width - 258, FlxG.height - 197, 'down', 0xA100FFFF));
			case DIALOGUE_PORTRAIT_EDITOR:
				add(buttonUp = createButton(105, FlxG.height - 356, 'up', 0x00FF00));
				add(buttonLeft = createButton(0, FlxG.height - 246, 'left', 0xFF00FF));
				add(buttonRight = createButton(207, FlxG.height - 246, 'right', 0xFF0000));
				add(buttonDown = createButton(105, FlxG.height - 131, 'down', 0x00FFFF));
				add(buttonUp2 = createButton(105, 0, 'up', 0xFF12FA05));
				add(buttonLeft2 = createButton(0, 102, 'left', 0xFFC24B99));
				add(buttonRight2 = createButton(207, 102, 'right', 0xFFF9393F));
				add(buttonDown2 = createButton(105, 210, 'down', 0xFF00FFFF));
			case MENU_CHARACTER_EDITOR:
				add(buttonUp = createButton(105, 0, 'up', 0x00FF00));
				add(buttonLeft = createButton(0, 102, 'left', 0xFF00FF));
				add(buttonRight = createButton(207, 102, 'right', 0xFF0000));
				add(buttonDown = createButton(105, 210, 'down', 0x00FFFF));
			case NONE: // do nothing
		}

		switch (Action)
		{
			case A:
				add(buttonA = createButton(FlxG.width - 132, FlxG.height - 131, 'a', 0xFF0000));
			case B:
				add(buttonB = createButton(FlxG.width - 132, FlxG.height - 131, 'b', 0xFFCB00));
			case P:
				add(buttonP = createButton(FlxG.width - 132, 0, 'p', 0xFFCB00));
			case A_B:
				add(buttonB = createButton(FlxG.width - 262, FlxG.height - 131, 'b', 0xFFCB00));
				add(buttonA = createButton(FlxG.width - 132, FlxG.height - 131, 'a', 0xFF0000));
			case A_B_C:
				add(buttonC = createButton(FlxG.width - 392, FlxG.height - 131, 'c', 0x44FF00));
				add(buttonB = createButton(FlxG.width - 262, FlxG.height - 131, 'b', 0xFFCB00));
				add(buttonA = createButton(FlxG.width - 132, FlxG.height - 131, 'a', 0xFF0000));
			case A_B_E:
				add(buttonE = createButton(FlxG.width - 392, FlxG.height - 131, 'e', 0xFF7D00));
				add(buttonB = createButton(FlxG.width - 262, FlxG.height - 131, 'b', 0xFFCB00));
				add(buttonA = createButton(FlxG.width - 132, FlxG.height - 131, 'a', 0xFF0000));
			case A_B_X_Y:
				add(buttonX = createButton(FlxG.width - 522, FlxG.height - 131, 'x', 0x99062D));
				add(buttonB = createButton(FlxG.width - 262, FlxG.height - 131, 'b', 0xFFCB00));
				add(buttonY = createButton(FlxG.width - 392, FlxG.height - 131, 'y', 0x4A35B9));
				add(buttonA = createButton(FlxG.width - 132, FlxG.height - 131, 'a', 0xFF0000));
			case A_B_C_X_Y:
				add(buttonC = createButton(FlxG.width - 392, FlxG.height - 131, 'c', 0x44FF00));
				add(buttonX = createButton(FlxG.width - 262, FlxG.height - 251, 'x', 0x99062D));
				add(buttonB = createButton(FlxG.width - 262, FlxG.height - 131, 'b', 0xFFCB00));
				add(buttonY = createButton(FlxG.width - 132, FlxG.height - 251, 'y', 0x4A35B9));
				add(buttonA = createButton(FlxG.width - 132, FlxG.height - 131, 'a', 0xFF0000));
			case A_B_C_X_Y_Z:
				add(buttonX = createButton(FlxG.width - 392, FlxG.height - 251, 'x', 0x99062D));
				add(buttonC = createButton(FlxG.width - 392, FlxG.height - 131, 'c', 0x44FF00));
				add(buttonY = createButton(FlxG.width - 262, FlxG.height - 251, 'y', 0x4A35B9));
				add(buttonB = createButton(FlxG.width - 262, FlxG.height - 131, 'b', 0xFFCB00));
				add(buttonZ = createButton(FlxG.width - 132, FlxG.height - 251, 'z', 0xCCB98E));
				add(buttonA = createButton(FlxG.width - 132, FlxG.height - 131, 'a', 0xFF0000));
			case A_B_C_D_V_X_Y_Z:
				add(buttonV = createButton(FlxG.width - 522, FlxG.height - 251, 'v', 0x49A9B2));
				add(buttonD = createButton(FlxG.width - 522, FlxG.height - 131, 'd', 0x0078FF));
				add(buttonX = createButton(FlxG.width - 392, FlxG.height - 251, 'x', 0x99062D));
				add(buttonC = createButton(FlxG.width - 392, FlxG.height - 131, 'c', 0x44FF00));
				add(buttonY = createButton(FlxG.width - 262, FlxG.height - 251, 'y', 0x4A35B9));
				add(buttonB = createButton(FlxG.width - 262, FlxG.height - 131, 'b', 0xFFCB00));
				add(buttonZ = createButton(FlxG.width - 132, FlxG.height - 251, 'z', 0xCCB98E));
				add(buttonA = createButton(FlxG.width - 132, FlxG.height - 131, 'a', 0xFF0000));
			case CHART_EDITOR:
				add(buttonUp2 = createButton(FlxG.width - 652, FlxG.height - 251, 'up', 0x00FF00));
				add(buttonDown2 = createButton(FlxG.width - 652, FlxG.height - 131, 'down', 0x00FFFF));
				add(buttonF = createButton(FlxG.width - 132, FlxG.height - 371, 'f', 0xB1FC00));
				add(buttonG = createButton(FlxG.width - 262, FlxG.height - 371, 'g', 0x3D3722));
				add(buttonV = createButton(FlxG.width - 522, FlxG.height - 251, 'v', 0x49A9B2));
				add(buttonD = createButton(FlxG.width - 522, FlxG.height - 131, 'd', 0x0078FF));
				add(buttonX = createButton(FlxG.width - 392, FlxG.height - 251, 'x', 0x99062D));
				add(buttonC = createButton(FlxG.width - 392, FlxG.height - 131, 'c', 0x44FF00));
				add(buttonY = createButton(FlxG.width - 262, FlxG.height - 251, 'y', 0x4A35B9));
				add(buttonB = createButton(FlxG.width - 262, FlxG.height - 131, 'b', 0xFFCB00));
				add(buttonZ = createButton(FlxG.width - 132, FlxG.height - 251, 'z', 0xCCB98E));
				add(buttonA = createButton(FlxG.width - 132, FlxG.height - 131, 'a', 0xFF0000));
			case CHARACTER_EDITOR:
				add(buttonV = createButton(FlxG.width - 522, FlxG.height - 251, 'v', 0x49A9B2));
				add(buttonD = createButton(FlxG.width - 522, FlxG.height - 131, 'd', 0x0078FF));
				add(buttonX = createButton(FlxG.width - 392, FlxG.height - 251, 'x', 0x99062D));
				add(buttonC = createButton(FlxG.width - 392, FlxG.height - 131, 'c', 0x44FF00));
				add(buttonG = createButton(FlxG.width - 653, FlxG.height - 131, 'g', 0x3D3722));
				add(buttonY = createButton(FlxG.width - 262, FlxG.height - 251, 'y', 0x4A35B9));
				add(buttonB = createButton(FlxG.width - 262, FlxG.height - 131, 'b', 0xFFCB00));
				add(buttonZ = createButton(FlxG.width - 132, FlxG.height - 251, 'z', 0xCCB98E));
				add(buttonA = createButton(FlxG.width - 132, FlxG.height - 131, 'a', 0xFF0000));
			case DIALOGUE_PORTRAIT_EDITOR:
				add(buttonX = createButton(FlxG.width - 392, 4, 'x', 0x99062D));
				add(buttonC = createButton(FlxG.width - 392, 129, 'c', 0x44FF00));
				add(buttonY = createButton(FlxG.width - 262, 4, 'y', 0x4A35B9));
				add(buttonB = createButton(FlxG.width - 262, 129, 'b', 0xFFCB00));
				add(buttonZ = createButton(FlxG.width - 132, 4, 'z', 0xCCB98E));
				add(buttonA = createButton(FlxG.width - 132, 129, 'a', 0xFF0000));
			case MENU_CHARACTER_EDITOR:
				add(buttonC = createButton(FlxG.width - 392, 4, 'c', 0x44FF00));
				add(buttonB = createButton(FlxG.width - 262, 4, 'b', 0xFFCB00));
				add(buttonA = createButton(FlxG.width - 132, 4, 'a', 0xFF0000));
			case NONE: // do nothing
		}

		if (Extra) add(buttonEx = createButton((DPad == LEFT_FULL) ? 1149 : 0, 589, 'g', 0x3D3722));

		scrollFactor.set();
	}

	/**
	 * Clean up memory.
	 */
	override public function destroy():Void
	{
		super.destroy();
		for (field in Reflect.fields(this))
			if (Std.isOfType(Reflect.field(this, field), FlxButton))
				Reflect.setField(this, field, FlxDestroyUtil.destroy(Reflect.field(this, field)));
	}

	private function createButton(X:Float, Y:Float, Graphic:String, Color:Int = 0xFFFFFF):FlxButton
	{
		var graphic:FlxGraphic;

		final path:String = 'shared:assets/shared/images/virtualpad/$Graphic.png';
		#if MODS_ALLOWED
		final modsPath:String = Paths.modsImages('virtualpad/$Graphic');
		if(sys.FileSystem.exists(modsPath))
			graphic = FlxGraphic.fromBitmapData(BitmapData.fromFile(modsPath));
		else #end if(Assets.exists(path))
			graphic = FlxGraphic.fromBitmapData(Assets.getBitmapData(path));
		else
			graphic = FlxGraphic.fromBitmapData(Assets.getBitmapData('shared:assets/shared/images/virtualpad/default.png'));

		var button:FlxButton = new FlxButton(X, Y);
		button.frames = FlxTileFrames.fromGraphic(graphic, FlxPoint.get(Std.int(graphic.width / 2), graphic.height));
		button.solid = false;
		button.immovable = true;
		button.moves = false;
		button.scrollFactor.set();
		button.color = Color;
		button.antialiasing = ClientPrefs.data.globalAntialiasing;
		button.alpha = ClientPrefs.data.mobileCAlpha;
		#if FLX_DEBUG
		button.ignoreDrawDebug = true;
		#end
		return button;
	}
}
