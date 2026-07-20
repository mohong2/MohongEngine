package script.hscript;

import script.lua.FunkinLua;
import flixel.util.FlxColor;
import mohong.TraceManager;

#if LUA_ALLOWED
import llua.Lua;
import llua.LuaL;
import llua.State;
import llua.Convert;
#end

/**
 * LUAApi - Global API class for managing Lua functions from HScript
 * 
 * Provides methods for adding, modifying, and overriding Lua functions
 * accessible across all Lua scripts. Acts as a bridge between HScript and Lua.
 * 
 * Usage in HScript:
 * ```
 * // Add a global Lua function
 * LUAApi.addLuaFunction("myFunc", function(x, y) { return x + y; });
 * 
 * // Override existing function
 * LUAApi.overrideLuaFunction("getProperty", function(original, variable, allowMaps) {
 *     trace('Intercepted: ' + variable);
 *     return original(variable, allowMaps);
 * });
 * ```
 */
class LuaApi {
    
    // Store original functions for restore capability
    private static var originalFunctions:Map<String, Dynamic> = new Map<String, Dynamic>();
    
    // Store custom added functions
    private static var customFunctions:Map<String, Dynamic> = new Map<String, Dynamic>();
    
    // Track overridden functions
    private static var overriddenFunctions:Map<String, Bool> = new Map<String, Bool>();
    
    /**
     * Initialize LUAApi
     */
    public static function initialize():Void {
        TraceManager.info('trace.luaApi.initialized', 'LUAApi initialized');
    }
    
    /**
     * Add a new global Lua function callable from any Lua script
     * 
     * @param functionName The function name in Lua global namespace
     * @param func The Haxe function to bind
     * @param overrideExisting If true, overrides existing function with same name
     * @return Bool True if successfully added
     */
    public static function addLuaFunction(functionName:String, func:Dynamic, overrideExisting:Bool = false):Bool {
        if (functionName == null || functionName.length == 0) {
            TraceManager.warn('trace.luaApi.invalidName', 'LUAApi: Invalid function name');
            return false;
        }
        
        if (func == null || !Reflect.isFunction(func)) {
            TraceManager.error('trace.luaApi.invalidFunction', 'LUAApi: Invalid function provided for "{}"', [functionName]);
            return false;
        }
        
        #if LUA_ALLOWED
        try {
            if (luaFunctionExists(functionName)) {
                if (!overrideExisting) {
                    TraceManager.warn('trace.luaApi.alreadyExists', 'LUAApi: Function "{}" already exists. Use overrideLuaFunction() instead.', [functionName]);
                    return false;
                }
                // Backup original if not already saved
                if (!originalFunctions.exists(functionName)) {
                    originalFunctions.set(functionName, getLuaFunctionDirect(functionName));
                }
            }
            
            // Store function reference
            customFunctions.set(functionName, func);
            
            // Register to all active Lua instances
            registerFunctionToAllLuaInstances(functionName, func);
            
            TraceManager.info('trace.luaApi.added', 'LUAApi: Function "{}" added successfully', [functionName]);
            return true;
        } catch (e:Dynamic) {
            TraceManager.error('trace.luaApi.addError', 'LUAApi: Error adding function "{}": {}', [functionName, e]);
            return false;
        }
        #else
        TraceManager.warn('trace.luaApi.unsupported', 'LUAApi: Lua not supported on this platform');
        return false;
        #end
    }
    
    /**
     * Override an existing Lua function with a wrapper
     * The wrapper receives the original function as first parameter
     * 
     * @param functionName The Lua function name to override
     * @param wrapperFunc The wrapper function (first param = original function)
     * @return Bool True if override successful
     */
    public static function overrideLuaFunction(functionName:String, wrapperFunc:Dynamic):Bool {
        if (functionName == null || functionName.length == 0) {
            TraceManager.warn('trace.luaApi.invalidName', 'LUAApi: Invalid function name');
            return false;
        }
        
        if (wrapperFunc == null || !Reflect.isFunction(wrapperFunc)) {
            TraceManager.error('trace.luaApi.invalidWrapper', 'LUAApi: Invalid wrapper function for "{}"', [functionName]);
            return false;
        }
        
        #if LUA_ALLOWED
        try {
            if (!luaFunctionExists(functionName)) {
                TraceManager.warn('trace.luaApi.notExists', 'LUAApi: Function "{}" does not exist to override', [functionName]);
                return false;
            }
            
            // Backup original if not already saved
            if (!originalFunctions.exists(functionName)) {
                originalFunctions.set(functionName, getLuaFunctionDirect(functionName));
            }
            
            var originalFunc = originalFunctions.get(functionName);
            
            // Create wrapped function with original as first argument
            var wrappedFunc = function(...args:Array<Dynamic>):Dynamic {
                var allArgs:Array<Dynamic> = [originalFunc];
                if (args != null) {
                    for (arg in args) {
                        allArgs.push(arg);
                    }
                }
                return Reflect.callMethod(null, wrapperFunc, allArgs);
            };
            
            // Register override
            overriddenFunctions.set(functionName, true);
            customFunctions.set(functionName, wrappedFunc);
            
            // Update all Lua instances
            registerFunctionToAllLuaInstances(functionName, wrappedFunc);
            
            TraceManager.info('trace.luaApi.overridden', 'LUAApi: Function "{}" overridden successfully', [functionName]);
            return true;
        } catch (e:Dynamic) {
            TraceManager.error('trace.luaApi.overrideError', 'LUAApi: Error overriding "{}": {}', [functionName, e]);
            return false;
        }
        #else
        TraceManager.warn('trace.luaApi.unsupported', 'LUAApi: Lua not supported on this platform');
        return false;
        #end
    }
    
    /**
     * Restore a Lua function to its original state
     * 
     * @param functionName The function name to restore
     * @return Bool True if restored successfully
     */
    public static function restoreLuaFunction(functionName:String):Bool {
        #if LUA_ALLOWED
        try {
            if (!originalFunctions.exists(functionName)) {
                TraceManager.warn('trace.luaApi.noBackup', 'LUAApi: No backup exists for "{}"', [functionName]);
                return false;
            }
            
            var originalFunc = originalFunctions.get(functionName);
            
            // Register original to all instances
            registerFunctionToAllLuaInstances(functionName, originalFunc);
            
            // Clean up tracking
            customFunctions.remove(functionName);
            overriddenFunctions.remove(functionName);
            originalFunctions.remove(functionName);
            
            TraceManager.info('trace.luaApi.restored', 'LUAApi: Function "{}" restored to original', [functionName]);
            return true;
        } catch (e:Dynamic) {
            TraceManager.error('trace.luaApi.restoreError', 'LUAApi: Error restoring "{}": {}', [functionName, e]);
            return false;
        }
        #else
        TraceManager.warn('trace.luaApi.unsupported', 'LUAApi: Lua not supported on this platform');
        return false;
        #end
    }
    
    /**
     * Remove a custom Lua function
     * 
     * @param functionName The custom function name to remove
     * @return Bool True if removed successfully
     */
    public static function removeLuaFunction(functionName:String):Bool {
        #if LUA_ALLOWED
        try {
            if (!customFunctions.exists(functionName)) {
                TraceManager.warn('trace.luaApi.notCustom', 'LUAApi: "{}" is not a custom function', [functionName]);
                return false;
            }
            
            // If it was an override, restore original
            if (overriddenFunctions.exists(functionName) && originalFunctions.exists(functionName)) {
                registerFunctionToAllLuaInstances(functionName, originalFunctions.get(functionName));
                overriddenFunctions.remove(functionName);
            } else {
                // Set to nil in all Lua instances
                setFunctionToNil(functionName);
            }
            
            customFunctions.remove(functionName);
            
            TraceManager.info('trace.luaApi.removed', 'LUAApi: Function "{}" removed', [functionName]);
            return true;
        } catch (e:Dynamic) {
            TraceManager.error('trace.luaApi.removeError', 'LUAApi: Error removing "{}": {}', [functionName, e]);
            return false;
        }
        #else
        TraceManager.warn('trace.luaApi.unsupported', 'LUAApi: Lua not supported on this platform');
        return false;
        #end
    }
    
    /**
     * Check if a Lua function exists globally
     * 
     * @param functionName The function name
     * @return Bool True if function exists
     */
    public static function luaFunctionExists(functionName:String):Bool {
        #if LUA_ALLOWED
        return getLuaFunctionDirect(functionName) != null;
        #else
        return false;
        #end
    }
    
    /**
     * Get a reference to a Lua function (for calling from HScript)
     * 
     * @param functionName The function name
     * @return Dynamic Function reference or null
     */
    public static function getLuaFunction(functionName:String):Dynamic {
        #if LUA_ALLOWED
        return getLuaFunctionDirect(functionName);
        #else
        return null;
        #end
    }
    
    /**
     * Get all custom-added function names
     * 
     * @return Array<String> Custom function names
     */
    public static function getCustomFunctions():Array<String> {
        var result:Array<String> = [];
        for (key in customFunctions.keys()) {
            result.push(key);
        }
        return result;
    }
    
    /**
     * Get all overridden function names
     * 
     * @return Array<String> Overridden function names
     */
    public static function getOverriddenFunctions():Array<String> {
        var result:Array<String> = [];
        for (key in overriddenFunctions.keys()) {
            result.push(key);
        }
        return result;
    }
    
    /**
     * Get original version of an overridden function
     * 
     * @param functionName The function name
     * @return Dynamic Original function or null
     */
    public static function getOriginalFunction(functionName:String):Dynamic {
        return originalFunctions.exists(functionName) ? originalFunctions.get(functionName) : null;
    }
    
    /**
     * Batch override multiple functions
     * 
     * @param overrides Map of function names to wrapper functions
     * @return Int Number of successful overrides
     */
    public static function batchOverrideLuaFunctions(overrides:Map<String, Dynamic>):Int {
        var successCount:Int = 0;
        
        for (functionName in overrides.keys()) {
            if (overrideLuaFunction(functionName, overrides.get(functionName))) {
                successCount++;
            }
        }
        
        return successCount;
    }
    
    /**
     * Batch add multiple functions
     * 
     * @param functions Map of function names to functions
     * @param overrideExisting Whether to override existing
     * @return Int Number of successful additions
     */
    public static function batchAddLuaFunctions(functions:Map<String, Dynamic>, overrideExisting:Bool = false):Int {
        var successCount:Int = 0;
        
        for (functionName in functions.keys()) {
            if (addLuaFunction(functionName, functions.get(functionName), overrideExisting)) {
                successCount++;
            }
        }
        
        return successCount;
    }
    
    /**
     * Restore all overridden functions
     * 
     * @return Int Number of restored functions
     */
    public static function restoreAllLuaFunctions():Int {
        var restoredCount:Int = 0;
        
        // Create copy to avoid modification during iteration
        var overriddenCopy:Array<String> = [];
        for (key in overriddenFunctions.keys()) {
            overriddenCopy.push(key);
        }
        
        for (functionName in overriddenCopy) {
            if (restoreLuaFunction(functionName)) {
                restoredCount++;
            }
        }
        
        return restoredCount;
    }
    
    /**
     * Clear all custom functions and restore originals
     */
    public static function clearAll():Void {
        restoreAllLuaFunctions();
        
        // Remove any remaining custom functions
        for (functionName in customFunctions.keys()) {
            setFunctionToNil(functionName);
        }
        
        customFunctions.clear();
        originalFunctions.clear();
        overriddenFunctions.clear();
        TraceManager.info('trace.luaApi.cleared', 'LUAApi: All custom functions cleared');
    }
    
    // ==================== Private Helper Methods ====================
    
    #if LUA_ALLOWED
    /**
     * Get function reference directly from Lua state
     * Uses the correct Lua stack operations to avoid thread value errors
     */
    private static function getLuaFunctionDirect(functionName:String):Dynamic {
        if (PlayState.instance == null || PlayState.instance.luaArray == null) {
            return null;
        }
        
        for (luaInstance in PlayState.instance.luaArray) {
            if (luaInstance.closed || luaInstance.lua == null) continue;
            
            var lua:State = luaInstance.lua;
            
            // Push the global function onto stack
            Lua.getglobal(lua, functionName);
            
            // Check the type of the value at top of stack
            var funcType:Int = Lua.type(lua, -1);
            
            if (funcType == Lua.LUA_TFUNCTION) {
                // It's a proper function, get reference and return
                var result = Convert.fromLua(lua, -1);
                Lua.pop(lua, 1);
                return result;
            } else if (funcType == Lua.LUA_TNIL) {
                // Function doesn't exist
                Lua.pop(lua, 1);
            } else {
                // Something else is there (might be thread/userdata), skip it
                Lua.pop(lua, 1);
            }
        }
        
        return null;
    }
    
    /**
     * Register a function to all active Lua instances
     * Uses LuaL_ref for proper function registration
     */
    private static function registerFunctionToAllLuaInstances(functionName:String, func:Dynamic):Void {
        if (PlayState.instance == null || PlayState.instance.luaArray == null) return;
        
        for (luaInstance in PlayState.instance.luaArray) {
            if (luaInstance.closed || luaInstance.lua == null) continue;
            
            try {
                // Use the existing callback registration mechanism
                // This ensures proper function type registration
                Lua_helper.add_callback(luaInstance.lua, functionName, func);
                
                // Alternative: Direct Lua C API method
                // Lua.pushcfunction(luaInstance.lua, cpp.Function.fromStaticFunction(cast func));
                // Lua.setglobal(luaInstance.lua, functionName);
            } catch (e:Dynamic) {
                TraceManager.error('trace.luaApi.registerError', 'LUAApi: Error registering \"{}\": {}', [functionName, e]);
            }
        }
    }
    
    /**
     * Set a global function to nil in all Lua instances
     */
    private static function setFunctionToNil(functionName:String):Void {
        if (PlayState.instance == null || PlayState.instance.luaArray == null) return;
        
        for (luaInstance in PlayState.instance.luaArray) {
            if (luaInstance.closed || luaInstance.lua == null) continue;
            
            try {
                Lua.pushnil(luaInstance.lua);
                Lua.setglobal(luaInstance.lua, functionName);
            } catch (e:Dynamic) {
                TraceManager.error('trace.luaApi.removeError', 'LUAApi: Error removing \"{}\": {}', [functionName, e]);
            }
        }
    }
    #end
}