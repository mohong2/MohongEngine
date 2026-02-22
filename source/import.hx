import Paths;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

import flixel.system.FlxSound;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.group.FlxSpriteGroup;
import flixel.group.FlxGroup.FlxTypedGroup;

import states.MusicBeatState;
import states.PlayState;
import states.LoadingState;
import states.TitleState;
import states.substates.MusicBeatSubstate;
using StringTools;
#if HSCRIPT_ALLOWED
import script.hscript.*;
import script.hstools.*;
#end