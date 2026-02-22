package;

import haxe.Json;
import sys.FileSystem;
import sys.io.File;

class Language
{
    private static var strings:Map<String, String> = new Map();
    
    public static function load(?lang:String):Void
    {
        strings.clear();

        if(lang == null)
            lang = ClientPrefs.data.language;

        try {
            var path:String = Paths.locale(lang);
            if(FileSystem.exists(path) && FileSystem.isDirectory(path)) {
                var files:Array<String> = FileSystem.readDirectory(path);
                
                for (file in files) {
                    if (file.endsWith(".json")) {
                        var filePath = path + "/" + file;
                        var rawJson:String = File.getContent(filePath);
                        var parsedData:Dynamic = Json.parse(rawJson);
                        
                        for (field in Reflect.fields(parsedData)) {
                            strings.set(field, Reflect.field(parsedData, field));
                        }
                    }
                }
            } else {
                trace('Language directory not found: $path');
            }

            var modPath:String = Paths.localeMod(lang);
            if(FileSystem.exists(modPath) && FileSystem.isDirectory(modPath) && modPath != null) {
                var files:Array<String> = FileSystem.readDirectory(modPath);
                
                for (file in files) {
                    if (file.endsWith(".json")) {
                        var filePath = modPath + "/" + file;
                        var rawJson:String = File.getContent(filePath);
                        var parsedData:Dynamic = Json.parse(rawJson);
                        
                        for (field in Reflect.fields(parsedData)) {
                            strings.set(field, Reflect.field(parsedData, field));
                        }
                    }
                }
            } else {
                trace('Mod Language directory not found: $modPath');
            }


        } catch(e:Dynamic) {
            trace('Error loading language: $e');
        }
    } 

    public static inline function get(key:String, ?defaultText:String):String
    {
        if(!strings.exists(key)) load();
        return strings.exists(key) ? strings.get(key) : (defaultText != null ? defaultText : key);
    }
}