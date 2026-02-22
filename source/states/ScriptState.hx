package states;


import script.hscript.HScript;
import script.lua.FunkinLua;
import flixel.FlxState;

#if HSCRIPT_ALLOWED
class ScriptState extends MusicBeatState
{
    public var hscriptArray:Array<HScript> = [];
    
    override function create()
    {
        super.create();
        initHScripts();
        
    }
    
    public function initHScripts()
    {
        hscriptArray = [];
        
        var stateName:String = Type.getClassName(Type.getClass(this));
        stateName = stateName.substr(stateName.lastIndexOf('.') + 1); 

        var filesPushed:Array<String> = [];
        var foldersToCheck:Array<String> = [Paths.getPreloadPath('hscript/' + stateName + '/')];

        #if MODS_ALLOWED
        foldersToCheck.insert(0, Paths.mods('hscript/' + stateName + '/'));
        if(Paths.currentModDirectory != null && Paths.currentModDirectory.length > 0)
            foldersToCheck.insert(0, Paths.mods(Paths.currentModDirectory + '/hscript/' + stateName + '/'));

        for(mod in Paths.getGlobalMods())
            foldersToCheck.insert(0, Paths.mods(mod + '/hscript/' + stateName + '/'));
        #end

        for (folder in foldersToCheck) {
            if(FileSystem.exists(folder)) {
                for (file in FileSystem.readDirectory(folder)) {
                    if(HScript.isHscriptFile(file) && !filesPushed.contains(file)) {
                        try {
                            var script = new HScript(folder + file);

                            if(script != null) {
                                hscriptArray.push(script);
                                filesPushed.push(file);
                            }
                        } catch (e:Dynamic) {
                            trace('Failed to load hscript: $file - $e');
                        }
                    }
                }
            }
        }
        trace('Loaded ${hscriptArray.length} hscripts for $stateName');
    }
    
    public function callOnHscript(event:String, args:Array<Dynamic> = null, ignoreStops:Bool = false, exclusions:Array<String> = null):Dynamic {
        if (args == null) args = [];
        if (exclusions == null) exclusions = [];
        var returnVal:Dynamic = FunkinLua.Function_Continue;

        var globalResult = HScript.callOnGlobalScript(event, args);
        if(globalResult == FunkinLua.Function_StopHScript && !ignoreStops) {
            return globalResult;
        }

        for (script in hscriptArray) {
            if(exclusions.contains(script.scriptName) || script.closed)
                continue;
            
            var ret:Dynamic = script.call(event, args);
            if(ret == FunkinLua.Function_StopHScript && !ignoreStops) {
                returnVal = ret;
                break;
            }
            
            if(ret != FunkinLua.Function_Continue) {
                returnVal = ret;
            }
        }
        
        return returnVal;
    }

    public function setOnHscript(variable:String, arg:Dynamic) {
        HScript.setOnGlobalScript(variable, arg);
        for (script in hscriptArray) {
            if (!script.closed) {
                script.set(variable, arg);
            }
        }
    }
    
    override function update(elapsed:Float)
    {
        var retVal:Dynamic = callOnHscript('onUpdate', [elapsed]);
        if(retVal == FunkinLua.Function_StopHScript) return;
        
        super.update(elapsed);

        callOnHscript('onUpdatePost', [elapsed]);
    }
    
    override function stepHit()
    {
        callOnHscript('onStepHit', [curStep]);
        super.stepHit();
    }
    
    override function beatHit()
    {
        callOnHscript('onBeatHit', [curBeat]);
        super.beatHit();
    }
    
    override function sectionHit()
    {
        callOnHscript('onSectionHit', [curSection]);
        super.sectionHit();
    }
    
    override function destroy()
    {
        if (hscriptArray != null){
        for (script in hscriptArray) {
            script.stop();
        }
    }
        hscriptArray = [];
        super.destroy();
    }
}
#else
class ScriptState extends MusicBeatState
{
    public function callOnHscript(event:String, args:Array<Dynamic> = null, ignoreStops:Bool = false, exclusions:Array<String> = null):Dynamic {
        return null;
        trace("Hscript is not allowed!");
    }
    
    public function setOnHscripts(variable:String, arg:Dynamic) {
        trace("Hscript is not allowed!");
    }
    
}
#end