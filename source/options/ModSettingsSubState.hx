package options;

import flixel.FlxG;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxe.Json;
import sys.FileSystem;
import sys.io.File;

class ModSettingsSubState extends BaseOptionsMenu
{
    var folder:String;
    var modName:String;
    var modSettings:Map<String, Dynamic> = new Map();
    
    public function new(settings:Array<Dynamic>, folder:String, name:String)
    {
        this.folder = folder;
        this.modName = name;
        title = '$name Settings';
        rpcTitle = 'Mod Settings ($name)';
        
            if(FlxG.save.data.modSettings == null) {
            FlxG.save.data.modSettings = new Map<String, Map<String, Dynamic>>();
        }
        
        var allModSettings:Map<String, Map<String, Dynamic>> = FlxG.save.data.modSettings;
        if(allModSettings.exists(folder)) {
            modSettings = allModSettings.get(folder);
        } else {
            modSettings = new Map();
            allModSettings.set(folder, modSettings);
        }
        
        for (setting in settings)
        {
            if (setting == null || setting.save == null) continue;
            
            var option:Option = null;
            var saveVar:String = setting.save;
            var defaultValue:Dynamic = setting.value != null ? setting.value : getDefaultValue(setting.type);
            
            var descriptionText:String = setting.description;
            if (setting.zhdescription != null) {
                descriptionText = setting.zhdescription;
            }
            
            if(!modSettings.exists(saveVar)) {
                modSettings.set(saveVar, defaultValue);
            }
            
            switch (setting.type.toLowerCase())
            {
                case "bool":
                    option = new Option(
                        setting.name != null ? setting.name : "Unnamed Setting",
                        descriptionText,
                        saveVar,
                        "bool",
                        defaultValue
                    );
                    option.setValue(modSettings.get(saveVar));
                
                case "int" | "integer":
                    option = new Option(
                        setting.name != null ? setting.name : "Unnamed Setting",
                        descriptionText,
                        saveVar,
                        "int",
                        defaultValue
                    );
                    if (setting.min != null) option.minValue = setting.min;
                    if (setting.max != null) option.maxValue = setting.max;
                    if (setting.step != null) option.changeValue = setting.step;
                    if (setting.scroll != null) option.scrollSpeed = setting.scroll;
                    option.setValue(modSettings.get(saveVar));
                
                case "float" | "number":
                    option = new Option(
                        setting.name != null ? setting.name : "Unnamed Setting",
                        descriptionText,
                        saveVar,
                        "float",
                        defaultValue
                    );
                    if (setting.min != null) option.minValue = setting.min;
                    if (setting.max != null) option.maxValue = setting.max;
                    if (setting.step != null) option.changeValue = setting.step;
                    if (setting.scroll != null) option.scrollSpeed = setting.scroll;
                    if (setting.decimals != null) option.decimals = setting.decimals;
                    option.setValue(modSettings.get(saveVar));
                
                case "percent":
                    option = new Option(
                        setting.name != null ? setting.name : "Unnamed Setting",
                        descriptionText,
                        saveVar,
                        "percent",
                        defaultValue
                    );
                    if (setting.min != null) option.minValue = setting.min;
                    if (setting.max != null) option.maxValue = setting.max;
                    if (setting.step != null) option.changeValue = setting.step;
                    if (setting.scroll != null) option.scrollSpeed = setting.scroll;
                    option.setValue(modSettings.get(saveVar));
                
                case "string":
                    option = new Option(
                        setting.name != null ? setting.name : "Unnamed Setting",
                        descriptionText,
                        saveVar,
                        "string",
                        defaultValue
                    );
                    if (setting.options != null) option.options = setting.options;
                    option.setValue(modSettings.get(saveVar));
                
                default:
                    trace('Unsupported setting type: ${setting.type}');
            }
            
            if (option != null)
            {
                var originalSetValue = option.setValue;
                
                option.setValue = function(value:Dynamic) {
                    originalSetValue(value);
                    modSettings.set(saveVar, value);
                };
                
                option.getValue = function() {
                    return modSettings.get(saveVar);
                };
                
                addOption(option);
            }
        }
        
        super();
    }
    
    override function close() {
        FlxG.save.data.modSettings.set(folder, modSettings);
        FlxG.save.flush();
        super.close();
    }
    
    function getDefaultValue(type:String):Dynamic
    {
        return switch (type.toLowerCase())
        {
            case "bool": false;
            case "int" | "integer": 0;
            case "float" | "number": 0.0;
            case "percent": 1.0;
            case "string": "";
            default: null;
        }
    }
}