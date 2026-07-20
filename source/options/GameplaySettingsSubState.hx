package options;

/**
 * GameplaySettingsSubState 已合并至 OptionsState。
 * 参见：OptionsState.hx（getGameplayOptions）
 */
@:deprecated("已合并至 OptionsState")
class GameplaySettingsSubState { 
	

	function onChangeHitsoundVolume()
	{
		FlxG.sound.play(Paths.sound('hitsound'), ClientPrefs.data.hitsoundVolume);
	}
}

