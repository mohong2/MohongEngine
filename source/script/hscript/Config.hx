package script.hscript;

import hscript.iris.Iris;

/**
 * HScript 运行时配置（hscript-seiun）。
 *
 * 控制脚本可以 import 哪些包、哪些模块被运行时拉黑。
 * 包前缀列表同时用于编译期影子类宏（见库内 `hscript.Config`），
 * 模块黑名单则在这里同步进运行时导入检查。
 */
class Config
{
	/** 允许脚本访问（import）的包前缀。 */
	public static final ALLOWED_IMPORT_PACKAGES:Array<String> = [
		"flixel",
		"openfl",
		"lime",
		"haxe",
		"script",
		"states",
		"substates",
		"backend",
		"options",
		"editors",
		"mohong"
	];

	/** 运行时禁止 import 的完整模块名（例如黑名单上有问题的模块）。 */
	public static final BLOCKED_MODULES:Array<String> = [];

	/**
	 * 检查某个包前缀是否在允许列表内；空值一律放行。
	 */
	public static function isPackageAllowed(pack:String):Bool
	{
		if (pack == null || pack.length == 0) return true;
		for (prefix in ALLOWED_IMPORT_PACKAGES)
			if (pack == prefix || pack.startsWith(prefix + "."))
				return true;
		return false;
	}

	/**
	 * 将 BLOCKED_MODULES 同步进全局运行时导入黑名单；
	 * 之后脚本里 `import` 这些模块会被直接拒绝。
	 */
	public static function applyBlocklist():Void
	{
		for (name in BLOCKED_MODULES)
		{
			if (!Iris.blocklistImports.contains(name))
				Iris.blocklistImports.push(name);
		}
	}
}
