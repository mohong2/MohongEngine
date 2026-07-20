package editors.content;

import flixel.text.FlxText;
import flixel.util.FlxColor;

class EditorsText extends FlxText {
	public function new(X:Float = 0, Y:Float = 0, FieldWidth:Float = 0, ?Text:String, Size:Int = 10, Border:Bool = true) {
		super(X, Y, FieldWidth, Text, Size);
		setFormat(Paths.font("editors.ttf"), Size, FlxColor.WHITE);
        this.antialiasing = false;
		this.textField.sharpness = 400;
		if (Border) {
			borderStyle = OUTLINE;
			borderSize = 1;
			borderColor = 0xFF000000;
		}
    }
}