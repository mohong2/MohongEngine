package;

import haxe.Json;
import sys.FileSystem;
import sys.io.File;

class Language
{
    private static var strings:Map<String, String> = new Map();
    private static var loadedFiles:Map<String, Bool> = new Map();
    private static var currentLang:String = null;

    public static function load(?lang:String):Void
    {
        if(lang == null)
            lang = ClientPrefs.data.language;

        // 语言切换时清理旧数据，防止内存泄漏
        if(currentLang != null && currentLang != lang) {
            reset();
        }

        currentLang = lang;
        loadDirectory(Paths.locale(lang));
        loadDirectory(Paths.localeMod(lang));
    }

    private static function loadDirectory(path:String):Void
    {
        if(path == null) return;
        if(!FileSystem.exists(path) || !FileSystem.isDirectory(path)) return;

        var files:Array<String> = [];
        try {
            files = FileSystem.readDirectory(path);
        } catch(e:Dynamic) {
            trace('Failed to read language directory: $path');
            return;
        }

        for(file in files) {
            if(!file.endsWith(".json")) continue;

            var filePath:String = path + "/" + file;
            // 跳过已加载的文件，避免重复解析
            if(loadedFiles.exists(filePath)) continue;

            try {
                var rawJson:String = File.getContent(filePath);
                var parsedData:Dynamic = Json.parse(rawJson);

                for(field in Reflect.fields(parsedData)) {
                    strings.set(field, Reflect.field(parsedData, field));
                }
                loadedFiles.set(filePath, true);
            } catch(e:Dynamic) {
                trace('Failed to load language file: $filePath');
            }
        }
    }

    public static inline function get(key:String, ?defaultText:String):String
    {
        return strings.exists(key) ? strings.get(key) : (defaultText != null ? defaultText : key);
    }

    public static inline function has(key:String):Bool
    {
        return strings.exists(key);
    }

    /** 重新加载语言（清空缓存后重新加载） */
    public static function reload(?lang:String):Void
    {
        reset();
        load(lang);
    }

    /** 释放所有已加载的语言资源 */
    public static function reset():Void
    {
        strings.clear();
        loadedFiles.clear();
        currentLang = null;
    }
}