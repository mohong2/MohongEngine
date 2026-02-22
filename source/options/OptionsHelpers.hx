package options;



class OptionsHelpers
{
	public static function colorArray(data:String):FlxColor
	{
		switch (data)
		{
			case 'BLACK':
				return FlxColor.BLACK;
			case 'WHITE':
				return FlxColor.WHITE;
			case 'GRAY':
				return FlxColor.GRAY;
			case 'RED':
				return FlxColor.RED;
			case 'GREEN':
				return FlxColor.GREEN;
			case 'BLUE':
				return FlxColor.BLUE;
			case 'YELLOW':
				return FlxColor.YELLOW;
			case 'PINK':
				return FlxColor.PINK;
			case 'ORANGE':
				return FlxColor.ORANGE;
			case 'PURPLE':
				return FlxColor.PURPLE;
			case 'BROWN':
				return FlxColor.BROWN;
			case 'CYAN':
				return FlxColor.CYAN;
		}
		return FlxColor.WHITE;
	}
	/*
		BOOL://

		var option:Option = new Option(this, 'name', BOOL, Language.get('name', 'op'), Language.get('name', 'opSub'));
		addOption(option);


		INT://

		var option:Option = new Option(this, 'name', INT, Language.get('name', 'op'), Language.get('name', 'opSub'), [min, max, '单位']);
		addOption(option);


		FLOAT://

		var option:Option = new Option(this, 'name', FLOAT, Language.get('name', 'op'), Language.get('name', 'opSub'), [min, max, '小数点', '单位]);
		addOption(option);


		PERCENT://

		var option:Option = new Option(this, 'name', PERCENT, Language.get('name', 'op'), Language.get('name', 'opSub'), [min, max, '单位']);
		addOption(option);


		STRING://

		var option:Option = new Option(this, 'name', STRING, Language.get('name', 'op'), Language.get('name', 'opSub'), youArray);
		addOption(option);


		STATE://

		var option:Option = new Option(this, 'name', STATE, Language.get('name', 'op'), Language.get('name', 'opSub'), youState);
		addOption(option);


		SubState://

		var option:Option = new Option(this, 'name', SubState, Language.get('name', 'op'), Language.get('name', 'opSub'), youSubState);
		addOption(option);


		TITLE://

		var option:Option = new Option(this, TITLE, Language.get('name', 'op'), Language.get('name', 'opSub'));
		addOption(option);


		TEXT://

		var option:Option = new Option(this, TEXT, Language.get('name', 'op'), Language.get('name', 'opSub'));
		addOption(option);


		NOTE://

		var option:Option = new Option(this, 'name', NOTE, Language.get('name', 'op'), Language.get('name', 'opSub'));
		addOption(option);


		SPLASH://

		var option:Option = new Option(this, 'name', SPLASH, Language.get('name', 'op'), Language.get('name', 'opSub'));
		addOption(option);
	*/
}
