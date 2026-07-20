package options;

#if desktop
import Discord.DiscordClient;
#end
import flash.text.TextField;
import flixel.addons.display.FlxGridOverlay;
import lime.utils.Assets;
import flixel.FlxSubState;
import flash.text.TextField;
import flixel.util.FlxSave;
import haxe.Json;
import flixel.input.keyboard.FlxKey;
import flixel.graphics.FlxGraphic;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;
import Controls;
import FlxTextMenuItem;

using StringTools;

class NotesSubState extends MusicBeatSubstate
{
	private static var curSelected:Int = 0;
	private static var typeSelected:Int = 0;
	private var grpNumbers:FlxTypedGroup<FlxTextMenuItem>;
	private var grpNotes:FlxTypedGroup<FlxSprite>;
	private var shaderArray:Array<ColorSwap> = [];
	var curValue:Float = 0;
	var holdTime:Float = 0;
	var nextAccept:Int = 5;

	var blackBG:FlxSprite;
	var hsbText:FlxTextMenuItem;

	var posX = 230;
	public function new() {
		super();
		
		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xFFea71fd;
		bg.screenCenter();
		bg.antialiasing = ClientPrefs.data.globalAntialiasing;
		add(bg);
		
		blackBG = new FlxSprite(posX - 25, 200).makeGraphic(870, 200, FlxColor.BLACK);
		blackBG.alpha = 0.4;
		add(blackBG);

		grpNotes = new FlxTypedGroup<FlxSprite>();
		add(grpNotes);
		grpNumbers = new FlxTypedGroup<FlxTextMenuItem>();
		add(grpNumbers);

		// 创建三个 Note：左（上一个）、中（当前）、下（下一个）
		createThreeNotes();

		hsbText = new FlxTextMenuItem(posX + 265, 150, Language.get("notes.hsb_label", "Hue    Saturation  Brightness"), 32);
		add(hsbText);
		changeSelection();
		#if android
		addVirtualPad(LEFT_FULL, A_B);
		addPadCamera();
		#end
		
	}

	var changingNote:Bool = false;
	var switchingNote:Bool = false;
	override function update(elapsed:Float) {
		if(changingNote) {
			if(holdTime < 0.5) {
				if(controls.UI_LEFT_P) {
					updateValue(-1);
					FlxG.sound.play(Paths.sound('scrollMenu'));
				} else if(controls.UI_RIGHT_P) {
					updateValue(1);
					FlxG.sound.play(Paths.sound('scrollMenu'));
				} else if(controls.RESET) {
					resetValue(curSelected, typeSelected);
					FlxG.sound.play(Paths.sound('scrollMenu'));
				}
				if(controls.UI_LEFT_R || controls.UI_RIGHT_R) {
					holdTime = 0;
				} else if(controls.UI_LEFT || controls.UI_RIGHT) {
					holdTime += elapsed;
				}
			} else {
				var add:Float = 90;
				switch(typeSelected) {
					case 1 | 2: add = 50;
				}
				if(controls.UI_LEFT) {
					updateValue(elapsed * -add);
				} else if(controls.UI_RIGHT) {
					updateValue(elapsed * add);
				}
				if(controls.UI_LEFT_R || controls.UI_RIGHT_R) {
					FlxG.sound.play(Paths.sound('scrollMenu'));
					holdTime = 0;
				}
			}
		} else {
			if (!switchingNote) {
				if (controls.UI_UP_P) {
					changeSelection(-1);
				}
				if (controls.UI_DOWN_P) {
					changeSelection(1);
				}
			}
			if (controls.UI_LEFT_P) {
				changeType(-1);
				FlxG.sound.play(Paths.sound('scrollMenu'));
			}
			if (controls.UI_RIGHT_P) {
				changeType(1);
				FlxG.sound.play(Paths.sound('scrollMenu'));
			}
			if(controls.RESET) {
				for (i in 0...3) {
					resetValue(curSelected, i);
				}
				FlxG.sound.play(Paths.sound('scrollMenu'));
			}
			if (controls.ACCEPT && nextAccept <= 0) {
				FlxG.sound.play(Paths.sound('scrollMenu'));
				changingNote = true;
				holdTime = 0;
				highlightCurrent();
				super.update(elapsed);
				return;
			}
		}

		if (controls.BACK || (changingNote && controls.ACCEPT)) {
			if(!changingNote) {
				flixel.addons.transition.FlxTransitionableState.skipNextTransOut = true;
				FlxG.resetState();
			} else {
				changeSelection();
			}
			changingNote = false;
			FlxG.sound.play(Paths.sound('cancelMenu'));
		}

		if(nextAccept > 0) {
			nextAccept -= 1;
		}
		super.update(elapsed);
	}

	/** 创建三个 Note 精灵：左（上一个）、中（当前）、下（下一个） */
	function createThreeNotes()
	{
		var animations:Array<String> = ['purple0', 'blue0', 'green0', 'red0'];
		var prevIdx = getPrevIndex(curSelected);
		var nextIdx = getNextIndex(curSelected);

		// 位置常量
		var leftX = 100;
		var centerX = 300;
		var belowX = 330;
		var centerY = 200;
		var belowY = 400;

		// 三个位置的数据：[索引, x, y, 缩放]
		var noteData = [
			{idx: prevIdx,        x: leftX,   y: centerY, scale: 0.65, alpha: 0.5},
			{idx: curSelected,    x: centerX, y: centerY, scale: 1.0,  alpha: 1.0},
			{idx: nextIdx,        x: belowX,  y: belowY,  scale: 0.65, alpha: 0.5}
		];

		for (d in noteData)
		{
			var note = new FlxSprite(d.x, d.y);
			note.frames = Paths.getSparrowAtlas('NOTE_assets');
			note.animation.addByPrefix('idle', animations[d.idx]);
			note.animation.play('idle');
			note.antialiasing = ClientPrefs.data.globalAntialiasing;
			note.scale.set(d.scale, d.scale);
			note.alpha = d.alpha;
			grpNotes.add(note);

			var shader = new ColorSwap();
			note.shader = shader.shader;
			shader.hue = ClientPrefs.data.arrowHSV[d.idx][0] / 360;
			shader.saturation = ClientPrefs.data.arrowHSV[d.idx][1] / 100;
			shader.brightness = ClientPrefs.data.arrowHSV[d.idx][2] / 100;
			shaderArray.push(shader);
		}

		// HSV 文字（在当前 Note 下方）
		for (j in 0...3) {
			var optionText:FlxTextMenuItem = new FlxTextMenuItem(posX + (225 * j) + 250, centerY + 60, Std.string(ClientPrefs.data.arrowHSV[curSelected][j]), 48);
			optionText.fieldWidth = 200;
			optionText.alignment = CENTER;
			optionText.ID = j;
			grpNumbers.add(optionText);
		}
	}

	/** 更新三个 Note 的显示数据 */
	function updateThreeNotes(?mapping:Array<Int>)
	{
		var animations:Array<String> = ['purple0', 'blue0', 'green0', 'red0'];
		if (mapping == null)
			mapping = [getPrevIndex(curSelected), curSelected, getNextIndex(curSelected)];

		for (i in 0...3)
		{
			if (i >= grpNotes.members.length) break;
			var note = grpNotes.members[i];
			var idx = mapping[i];
			note.animation.addByPrefix('idle', animations[idx]);
			note.animation.play('idle');
			if (i < shaderArray.length) {
				var s = shaderArray[i];
				s.hue = ClientPrefs.data.arrowHSV[idx][0] / 360;
				s.saturation = ClientPrefs.data.arrowHSV[idx][1] / 100;
				s.brightness = ClientPrefs.data.arrowHSV[idx][2] / 100;
			}
		}

		// 更新中心 Note 对应的 HSV 文字（mapping[1] 是当前居中的 Note 索引）
		var centerIdx = (mapping.length >= 3) ? mapping[1] : curSelected;
		for (j in 0...3) {
			if (j < grpNumbers.length) {
				grpNumbers.members[j].text = Std.string(ClientPrefs.data.arrowHSV[centerIdx][j]);
			}
		}
	}

	function getPrevIndex(idx:Int):Int
	{
		var v = idx - 1;
		if (v < 0) v = ClientPrefs.data.arrowHSV.length - 1;
		return v;
	}
	function getNextIndex(idx:Int):Int
	{
		var v = idx + 1;
		if (v >= ClientPrefs.data.arrowHSV.length) v = 0;
		return v;
	}

	function changeSelection(change:Int = 0) {
		if (change == 0) {
			// 初始化高亮
			curValue = ClientPrefs.data.arrowHSV[curSelected][typeSelected];
			updateValue();
			highlightCurrent();
			FlxG.sound.play(Paths.sound('scrollMenu'));
			return;
		}
		if (switchingNote) return; // 动画进行中忽略新切换

		switchingNote = true;
		var oldIdx = curSelected;
		curSelected += change;
		if (curSelected < 0) curSelected = ClientPrefs.data.arrowHSV.length - 1;
		if (curSelected >= ClientPrefs.data.arrowHSV.length) curSelected = 0;

		curValue = ClientPrefs.data.arrowHSV[curSelected][typeSelected];
		updateValue();

		// 动画：三个 Note 同步移动到新位置，同时更新数据
		var leftX = 100;
		var centerX = 300;
		var belowX = 330;
		var centerY = 200;
		var belowY = 400;

		if (change < 0)
		{
			// UP：左→中，中→下，下→左
			if (grpNotes.members.length >= 3)
			{
				var left = grpNotes.members[0];
				var center = grpNotes.members[1];
				var below = grpNotes.members[2];

				// 左→中
				FlxTween.tween(left, {x: centerX, y: centerY, alpha: 1}, 0.35, {ease: FlxEase.backOut});
				FlxTween.tween(left.scale, {x: 1, y: 1}, 0.35, {ease: FlxEase.backOut});

				// 中→下
				FlxTween.tween(center, {x: belowX, y: belowY, alpha: 0.5}, 0.3, {ease: FlxEase.cubeIn});
				FlxTween.tween(center.scale, {x: 0.65, y: 0.65}, 0.3, {ease: FlxEase.cubeIn});

				// 下→左
				FlxTween.tween(below, {x: leftX, y: centerY, alpha: 0.5}, 0.35, {ease: FlxEase.cubeOut});
				FlxTween.tween(below.scale, {x: 0.65, y: 0.65}, 0.35, {ease: FlxEase.cubeOut});

				// 位置交换后：members[0]=新中, members[1]=新下, members[2]=新左
				updateThreeNotes([curSelected, getNextIndex(curSelected), getPrevIndex(curSelected)]);
			}
		}
		else
		{
			// DOWN：下→中，中→左，左→下
			if (grpNotes.members.length >= 3)
			{
				var left = grpNotes.members[0];
				var center = grpNotes.members[1];
				var below = grpNotes.members[2];

				// 下→中
				FlxTween.tween(below, {x: centerX, y: centerY, alpha: 1}, 0.35, {ease: FlxEase.backOut});
				FlxTween.tween(below.scale, {x: 1, y: 1}, 0.35, {ease: FlxEase.backOut});

				// 中→左
				FlxTween.tween(center, {x: leftX, y: centerY, alpha: 0.5}, 0.3, {ease: FlxEase.cubeIn});
				FlxTween.tween(center.scale, {x: 0.65, y: 0.65}, 0.3, {ease: FlxEase.cubeIn});

				// 左→下
				FlxTween.tween(left, {x: belowX, y: belowY, alpha: 0.5}, 0.35, {ease: FlxEase.cubeOut});
				FlxTween.tween(left.scale, {x: 0.65, y: 0.65}, 0.35, {ease: FlxEase.cubeOut});

				// 位置交换后：members[0]=新下, members[1]=新左, members[2]=新中
				updateThreeNotes([getNextIndex(curSelected), getPrevIndex(curSelected), curSelected]);
			}
		}
		FlxG.sound.play(Paths.sound('scrollMenu'));

		// 动画结束后解锁切换
		new FlxTimer().start(0.4, function(_) { switchingNote = false; });
	}

	/** 高亮当前选中的 HSV 文字 */
	function highlightCurrent()
	{
		for (i in 0...grpNumbers.length) {
			var item = grpNumbers.members[i];
			item.alpha = (i == typeSelected) ? 1 : 0.6;
		}
	}

	function changeType(change:Int = 0) {
		typeSelected += change;
		if (typeSelected < 0)
			typeSelected = 2;
		if (typeSelected > 2)
			typeSelected = 0;

		curValue = ClientPrefs.data.arrowHSV[curSelected][typeSelected];
		updateValue();
		highlightCurrent();
	}

	function resetValue(selected:Int, type:Int) {
		curValue = 0;
		ClientPrefs.data.arrowHSV[selected][type] = 0;
		// 更新中心 Note 的 shader
		if (shaderArray.length > 1) {
			switch(type) {
				case 0: shaderArray[1].hue = 0;
				case 1: shaderArray[1].saturation = 0;
				case 2: shaderArray[1].brightness = 0;
			}
		}
		if (type < grpNumbers.length) {
			grpNumbers.members[type].text = '0';
			grpNumbers.members[type].alignment = CENTER;
		}
	}
	function updateValue(change:Float = 0) {
		curValue += change;
		var roundedValue:Int = Math.round(curValue);
		var max:Float = 180;
		switch(typeSelected) {
			case 1 | 2: max = 100;
		}
		if(roundedValue < -max) { curValue = -max; }
		else if(roundedValue > max) { curValue = max; }
		roundedValue = Math.round(curValue);
		ClientPrefs.data.arrowHSV[curSelected][typeSelected] = roundedValue;

		// 实时更新中心 Note 颜色（shaderArray[1] = 中央 Note）
		if (shaderArray.length > 1) {
			switch(typeSelected) {
				case 0: shaderArray[1].hue = roundedValue / 360;
				case 1: shaderArray[1].saturation = roundedValue / 100;
				case 2: shaderArray[1].brightness = roundedValue / 100;
			}
		}
		if (typeSelected < grpNumbers.length) {
			grpNumbers.members[typeSelected].text = Std.string(roundedValue);
			grpNumbers.members[typeSelected].alignment = CENTER;
		}
	}
}