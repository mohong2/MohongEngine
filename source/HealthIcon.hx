package;

import openfl.utils.Assets as OpenFlAssets;

using StringTools;

class HealthIcon extends FlxSprite
{
	public var sprTracker:FlxSprite;
	private var isOldIcon:Bool = false;
	private var isPlayer:Bool = false;
	private var char:String = '';
	public var frameCount:Int = 2;

	public function new(char:String = 'bf', isPlayer:Bool = false)
	{ 
		super();
		isOldIcon = (char == 'bf-old');
		this.isPlayer = isPlayer;
		changeIcon(char);
		scrollFactor.set();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (sprTracker != null)
			setPosition(sprTracker.x + sprTracker.width + 12, sprTracker.y - 30);
	}

	public function swapOldIcon() {
		if(isOldIcon = !isOldIcon) changeIcon('bf-old');
		else changeIcon('bf');
	}

	private var iconOffsets:Array<Float> = [0, 0, 0];
	public function changeIcon(char:String) {
		if(this.char != char) {
			var name:String = 'icons/' + char;
			if(!Paths.fileExists('images/' + name + '.png', IMAGE)) name = 'icons/icon-' + char; //Older versions of psych engine's support
			if(!Paths.fileExists('images/' + name + '.png', IMAGE)) name = 'icons/icon-face'; //Prevents crash from missing icon
			var file:Dynamic = Paths.image(name);

			loadGraphic(file);
			var imgWidth:Int = Math.floor(width);
			var imgHeight:Int = Math.floor(height);
			
			frameCount = Math.round(imgWidth / imgHeight);
			
			if (frameCount < 2) frameCount = 2;
			if (frameCount > 3) frameCount = 3;
			
			var frameWidth:Int = Math.round(imgWidth / frameCount);
			
			loadGraphic(file, true, frameWidth, imgHeight);
			
			var offsetX:Float = (frameWidth - 150) / 2;
			var offsetY:Float = (imgHeight - 150) / 2;
			
			for (i in 0...iconOffsets.length) {
				iconOffsets[i] = 0;
			}
			iconOffsets[0] = offsetX;
			iconOffsets[1] = offsetY;
			if (frameCount == 3) {
				iconOffsets[2] = 0; 
			}
			
			updateHitbox();


			if (frameCount == 3) {
				animation.add(char, [0, 1, 2], 0, false, isPlayer);
			} else {
				animation.add(char, [0, 1, 0], 0, false, isPlayer);
			}
			animation.play(char);
			drawFrame(true);
			this.char = char;

			antialiasing = ClientPrefs.data.globalAntialiasing;
			if(char.endsWith('-pixel')) {
				antialiasing = false;
			}
		}
	}
	public var autoAdjustOffset:Bool = true;
	override function updateHitbox()
	{
		super.updateHitbox();
		if(autoAdjustOffset)
		{
			offset.x = iconOffsets[0];
			offset.y = iconOffsets[1];
		}
	}

	public function getCharacter():String {
		return char;
	}
}
