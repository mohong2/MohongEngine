package;

import haxe.Json;
#if !js
import sys.FileSystem;
import sys.io.File;
#end

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

        var files:Array<String> = [];
        #if js
        var allAssets:Array<String> = lime.utils.Assets.list();
        var prefix:String = path + '/';
        for(asset in allAssets)
        {
            if(asset.startsWith(prefix) && asset.endsWith('.json'))
                files.push(asset.substr(prefix.length));
        }
        if(files.length == 0)
        {
            var known:Array<String> = [
                'English.json', 'Android.json', 'option.json', 'playstate.json', 'pause.json',
                'ResultsScreen.json', 'ScoreHistorySubstate.json',
                'characterEditor.json', 'creditsEditor.json',
                'dialogueCharacterEditor.json', 'dialogueEditor.json',
                'menuCharacterEditor.json', 'newchartEditor.json',
                'script.json', 'weekEditor.json', 'backgroundEditor.json',
                'CrashCatcherState.json', 'GameplayChangersSubstate.json'
            ];
            for(name in known)
            {
                var full:String = path + '/' + name;
                if(lime.utils.Assets.exists(full, TEXT))
                    files.push(name);
            }
        }
        #else
        if(!FileSystem.exists(path) || !FileSystem.isDirectory(path)) return;
        try {
            files = FileSystem.readDirectory(path);
        } catch(e:Dynamic) {
            trace('Failed to read language directory: $path');
            return;
        }
        #end

        for(file in files) {
            if(!file.endsWith(".json")) continue;

            var filePath:String = path + "/" + file;
            // 跳过已加载的文件，避免重复解析
            if(loadedFiles.exists(filePath)) continue;

            try {
                #if js
                var rawJson:String = lime.utils.Assets.getText(filePath);
                if(rawJson == null) continue;
                #else
                var rawJson:String = File.getContent(filePath);
                #end
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
