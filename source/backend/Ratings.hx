package backend;

import ClientPrefs;
import CoolUtil;
import Paths;

/**
 * LeatherEngine 移植: 判定手感工具类。
 * - getRating: 根据 judgementTimings 判定 marvelouse/sick/good/bad/shit
 * - timingPresets.txt: 预设判定窗口 (Leather / Psych-Kade / FNF)
 * - syncWindows: 将 judgementTimings 同步到 Psych 的 ClientPrefs 窗口字段,
 *   保证 Psych 评分 / 回放 / 结果界面全部使用同一套判定。
 */
class Ratings
{
	private static var scores:Array<Dynamic> = [['marvelous', 400], ['sick', 350], ['good', 200], ['bad', 50], ['shit', -150]];

	/** 根据毫秒差返回判定名 ('marvelous' / 'sick' / 'good' / 'bad' / 'shit') */
	public static function getRating(time:Float):String
	{
		var judges:Array<Int> = ClientPrefs.data.judgementTimings;
		if (judges == null || judges.length < 4)
			judges = [25, 50, 70, 100];

		var timings:Array<Array<Dynamic>> = [
			[judges[0], "marvelous"],
			[judges[1], "sick"],
			[judges[2], "good"],
			[judges[3], "bad"]
		];

		var rating:String = 'bruh';

		for (x in timings)
		{
			if (x[1] == "marvelous" && ClientPrefs.data.marvelousRatings || x[1] != "marvelous")
			{
				if (time <= x[0] && rating == 'bruh')
				{
					rating = x[1];
				}
			}
		}

		if (rating == 'bruh')
			rating = "shit";

		return rating;
	}

	public static var timingPresets:Map<String, Array<Int>> = [];
	public static var presets:Array<String> = [];

	public static function returnPreset(name:String = "leather engine"):Array<Int>
	{
		if (timingPresets.exists(name))
			return timingPresets.get(name);

		return [25, 50, 70, 100];
	}

	/**
	 * 根据判定窗口反查预设名, 匹配不到则返回 "Custom"。
	 * 用于回放/成绩历史中显示判定类型。
	 */
	public static function presetNameForTimings(timings:Array<Int>):String
	{
		if (timings == null || timings.length < 4) return 'Custom';
		if (presets.length == 0) loadPresets();

		for (name in presets)
		{
			var t:Array<Int> = timingPresets.get(name);
			if (t != null && t.length >= 4
				&& t[0] == timings[0] && t[1] == timings[1] && t[2] == timings[2] && t[3] == timings[3])
				return name;
		}
		return 'Custom';
	}

	public static function loadPresets()
	{
		presets = [];
		timingPresets = [];

		var timingPresetsArray = CoolUtil.coolTextFile(Paths.txt("timingPresets"));

		for (array in timingPresetsArray)
		{
			var values = array.split(",");
			if (values.length < 5) continue;

			timingPresets.set(values[0], [
				Std.parseInt(values[1]),
				Std.parseInt(values[2]),
				Std.parseInt(values[3]),
				Std.parseInt(values[4])
			]);
			presets.push(values[0]);
		}

		// 兜底: txt 缺失或损坏时至少保留 Leather Engine 预设
		if (presets.length == 0)
		{
			timingPresets.set("Leather Engine", [25, 50, 70, 100]);
			presets.push("Leather Engine");
		}
	}

	/**
	 * 将 judgementTimings [marvelous, sick, good, bad] 同步到
	 * ClientPrefs 的 marvelousWindow / sickWindow / goodWindow / badWindow。
	 * Psych 的 Rating / 回放 / 结果界面都读取这些窗口字段。
	 */
	public static function syncWindows():Void
	{
		var t:Array<Int> = ClientPrefs.data.judgementTimings;
		if (t == null || t.length < 4)
			t = [25, 50, 70, 100];

		ClientPrefs.data.marvelousWindow = t[0];
		ClientPrefs.data.sickWindow = t[1];
		ClientPrefs.data.goodWindow = t[2];
		ClientPrefs.data.badWindow = t[3];
	}

	public static function getScore(rating:String)
	{
		var score:Int = 0;

		for (x in scores)
		{
			if (rating == x[0])
			{
				score = x[1];
			}
		}

		return score;
	}
}
