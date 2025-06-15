package;

import flixel.FlxG;

using StringTools;

class Highscore
{
	#if (haxe >= "4.0.0")
	public static var songScores:Map<String, Int> = new Map();
	public static var songRating:Map<String, Float> = new Map();
	public static var weekScores:Map<String, Int> = new Map();
	public static var songSicks:Map<String, Int> = new Map();
	public static var songGoods:Map<String, Int> = new Map();
	public static var songBads:Map<String, Int> = new Map();
	public static var songShits:Map<String, Int> = new Map();
	public static var songMisses:Map<String, Int> = new Map();
	public static var songMaxCombo:Map<String, Int> = new Map();
	#else
	public static var songScores:Map<String, Int> = new Map<String, Int>();
	public static var weekScores:Map<String, Int> = new Map();
	public static var songRating:Map<String, Float> = new Map();
	public static var songSicks:Map<String, Int> = new Map<String, Int>();
	public static var songGoods:Map<String, Int> = new Map<String, Int>();
	public static var songBads:Map<String, Int> = new Map<String, Int>();
	public static var songShits:Map<String, Int> = new Map<String, Int>();
	public static var songMisses:Map<String, Int> = new Map<String, Int>();
	public static var songMaxCombo:Map<String, Int> = new Map<String, Int>();
	#end

	public static function saveFullScore(
		song:String, diff:Int, 
		score:Int, sicks:Int, goods:Int, 
		bads:Int, shits:Int, misses:Int, maxCombo:Int
	):Void
	{
		var daSong:String = formatSong(song, diff);
		
		setScore(daSong, score);
		setSicks(daSong, sicks);
		setGoods(daSong, goods);
		setBads(daSong, bads);
		setShits(daSong, shits);
		setMisses(daSong, misses);
		setMaxCombo(daSong, maxCombo);
	}
	 

	public static function resetSong(song:String, diff:Int = 0):Void
	{
		var daSong:String = formatSong(song, diff);
		setScore(daSong, 0);
		setRating(daSong, 0);
		setScore(daSong, 0);
		setSicks(daSong, 0);
		setGoods(daSong, 0);
		setBads(daSong, 0);
		setShits(daSong, 0);
		setMisses(daSong, 0);
		setMaxCombo(daSong, 0);
	}

	public static function resetWeek(week:String, diff:Int = 0):Void
	{
		var daWeek:String = formatSong(week, diff);
		setWeekScore(daWeek, 0);
	}

	public static function floorDecimal(value:Float, decimals:Int):Float
	{
		if(decimals < 1)
		{
			return Math.floor(value);
		}

		var tempMult:Float = 1;
		for (i in 0...decimals)
		{
			tempMult *= 10;
		}
		var newValue:Float = Math.floor(value * tempMult);
		return newValue / tempMult;
	}

	public static function saveScore(song:String, score:Int = 0, ?diff:Int = 0, ?rating:Float = -1):Void
	{
		var daSong:String = formatSong(song, diff);

		if (songScores.exists(daSong)) {
			if (songScores.get(daSong) < score) {
				setScore(daSong, score);
				if(rating >= 0) setRating(daSong, rating);
			}
		}
		else {
			setScore(daSong, score);
			if(rating >= 0) setRating(daSong, rating);
		}
	}

	public static function saveWeekScore(week:String, score:Int = 0, ?diff:Int = 0):Void
	{
		var daWeek:String = formatSong(week, diff);

		if (weekScores.exists(daWeek))
		{
			if (weekScores.get(daWeek) < score)
				setWeekScore(daWeek, score);
		}
		else
			setWeekScore(daWeek, score);
	}

	/**
	 * YOU SHOULD FORMAT SONG WITH formatSong() BEFORE TOSSING IN SONG VARIABLE
	 */
	static function setScore(song:String, score:Int):Void
	{
		// Reminder that I don't need to format this song, it should come formatted!
		songScores.set(song, score);
		FlxG.save.data.songScores = songScores;
		FlxG.save.flush();
	}
	static function setWeekScore(week:String, score:Int):Void
	{
		// Reminder that I don't need to format this song, it should come formatted!
		weekScores.set(week, score);
		FlxG.save.data.weekScores = weekScores;
		FlxG.save.flush();
	}

	static function setRating(song:String, rating:Float):Void
	{
		// Reminder that I don't need to format this song, it should come formatted!
		songRating.set(song, rating);
		FlxG.save.data.songRating = songRating;
		FlxG.save.flush();
	}

	public static function formatSong(song:String, diff:Int):String
	{
		return Paths.formatToSongPath(song) + CoolUtil.getDifficultyFilePath(diff);
	}

	public static function getScore(song:String, diff:Int):Int
	{
		var daSong:String = formatSong(song, diff);
		if (!songScores.exists(daSong))
			setScore(daSong, 0);

		return songScores.get(daSong);
	}



	public static function getRating(song:String, diff:Int):Float
	{
		var daSong:String = formatSong(song, diff);
		if (!songRating.exists(daSong))
			setRating(daSong, 0);

		return songRating.get(daSong);
	}

	public static function getWeekScore(week:String, diff:Int):Int
	{
		var daWeek:String = formatSong(week, diff);
		if (!weekScores.exists(daWeek))
			setWeekScore(daWeek, 0);

		return weekScores.get(daWeek);
	}

	public static function load():Void
	{
		if (FlxG.save.data.weekScores != null)
		{
			weekScores = FlxG.save.data.weekScores;
		}
		if (FlxG.save.data.songScores != null)
		{
			songScores = FlxG.save.data.songScores;
		}
		if (FlxG.save.data.songRating != null)
		{
			songRating = FlxG.save.data.songRating;
		}
		if (FlxG.save.data.songSicks != null) songSicks = FlxG.save.data.songSicks;
		if (FlxG.save.data.songGoods != null) songGoods = FlxG.save.data.songGoods;
		if (FlxG.save.data.songBads != null) songBads = FlxG.save.data.songBads;
		if (FlxG.save.data.songShits != null) songShits = FlxG.save.data.songShits;
		if (FlxG.save.data.songMisses != null) songMisses = FlxG.save.data.songMisses;
		if (FlxG.save.data.songMaxCombo != null) songMaxCombo = FlxG.save.data.songMaxCombo;
	}
	public static function getSicks(song:String, diff:Int):Int
	{
		var daSong:String = formatSong(song, diff);
		if (!songSicks.exists(daSong))
			setSicks(daSong, 0);

		return songSicks.get(daSong);
	}

	public static function setSicks(song:String, sicks:Int):Void
	{
		songSicks.set(song, sicks);
		FlxG.save.data.songSicks = songSicks;
		FlxG.save.flush();
	}

	public static function getGoods(song:String, diff:Int):Int
	{
		var daSong:String = formatSong(song, diff);
		if (!songGoods.exists(daSong))
			setGoods(daSong, 0);

		return songGoods.get(daSong);
	}

	public static function setGoods(song:String, goods:Int):Void
	{
		songGoods.set(song, goods);
		FlxG.save.data.songGoods = songGoods;
		FlxG.save.flush();
	}

	public static function getBads(song:String, diff:Int):Int
	{
		var daSong:String = formatSong(song, diff);
		if (!songBads.exists(daSong))
			setBads(daSong, 0);

		return songBads.get(daSong);
	}

	public static function setBads(song:String, bads:Int):Void
	{
		songBads.set(song, bads);
		FlxG.save.data.songBads = songBads;
		FlxG.save.flush();
	}

	public static function getShits(song:String, diff:Int):Int
	{
		var daSong:String = formatSong(song, diff);
		if (!songShits.exists(daSong))
			setShits(daSong, 0);

		return songShits.get(daSong);
	}

	public static function setShits(song:String, shits:Int):Void
	{
		songShits.set(song, shits);
		FlxG.save.data.songShits = songShits;
		FlxG.save.flush();
	}

	public static function getMisses(song:String, diff:Int):Int
	{
		var daSong:String = formatSong(song, diff);
		if (!songMisses.exists(daSong))
			setMisses(daSong, 0);

		return songMisses.get(daSong);
	}

	public static function setMisses(song:String, misses:Int):Void
	{
		songMisses.set(song, misses);
		FlxG.save.data.songMisses = songMisses;
		FlxG.save.flush();
	}

	public static function getMaxCombo(song:String, diff:Int):Int
	{
		var daSong:String = formatSong(song, diff);
		if (!songMaxCombo.exists(daSong))
			setMaxCombo(daSong, 0);

		return songMaxCombo.get(daSong);
	}

	public static function setMaxCombo(song:String, maxCombo:Int):Void
	{
		songMaxCombo.set(song, maxCombo);
		FlxG.save.data.songMaxCombo = songMaxCombo;
		FlxG.save.flush();
	}

}