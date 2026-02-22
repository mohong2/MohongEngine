package states.substates;

import script.hscript.HScript;
import script.lua.FunkinLua;

#if HSCRIPT_ALLOWED
class ScriptSubstate extends MusicBeatSubstate
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
        
        var substateName:String = Type.getClassName(Type.getClass(this));
        substateName = substateName.substr(substateName.lastIndexOf('.') + 1); 

        var filesPushed:Array<String> = [];
        var foldersToCheck:Array<String> = [Paths.getPreloadPath('hscript/substates/' + substateName + '/')];

        #if MODS_ALLOWED
        foldersToCheck.insert(0, Paths.mods('hscript/substates/' + substateName + '/'));
        if(Paths.currentModDirectory != null && Paths.currentModDirectory.length > 0)
            foldersToCheck.insert(0, Paths.mods(Paths.currentModDirectory + '/hscript/substates/' + substateName + '/'));

        for(mod in Paths.getGlobalMods())
            foldersToCheck.insert(0, Paths.mods(mod + '/hscript/substates/' + substateName + '/'));
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
        
        trace('Loaded ${hscriptArray.length} hscripts for $substateName');
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

    public function setOnHscripts(variable:String, arg:Dynamic) {
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
    
    override function destroy()
    {
        for (script in hscriptArray) {
            script.stop();
        }
        hscriptArray = [];
        super.destroy();
    }
}
#else
class ScriptSubstate extends MusicBeatSubstate
{
    public function callOnHscript(event:String, args:Array<Dynamic> = null, ignoreStops:Bool = false, exclusions:Array<String> = null):Dynamic {
        trace('Hscript is not allowed!')
        return null;
    }
    
    public function setOnHscripts(variable:String, arg:Dynamic) {
        trace('Hscript is not allowed!')
    }
    
}
#end