# SeiunEngine Script System Documentation

## Table of Contents

1. [Overview](#1-overview)
2. [System Architecture](#2-system-architecture)
3. [Lua Script System](#3-lua-script-system)
4. [HScript System](#4-hscript-system)
5. [ModState & ModSubState](#5-modstate--modsubstate)
6. [Helper Classes](#6-helper-classes)
7. [Lua API (Managing Lua from HScript)](#7-lua-api-managing-lua-from-hscript)
8. [Script Event Callbacks Reference](#8-script-event-callbacks-reference)
9. [Script Load Paths](#9-script-load-paths)
10. [Common Usage Examples](#10-common-usage-examples)
11. [Platform-Specific Notes](#11-platform-specific-notes)
12. [Troubleshooting](#12-troubleshooting)

---

## 1. Overview

SeiunEngine uses a **dual-engine script architecture**, supporting both **Lua** and **HScript (Haxe Script)** languages. Developers can choose either language to write MOD logic, and the two languages can call each other.

- **Lua**: Uses `llua` bindings, full Lua 5.x interpreter, suitable for dynamic scripting
- **HScript**: Uses `crowplexus-hscript`, a native Haxe script interpreter, with syntax close to Haxe

### Version Information

| Component | Version |
|-----------|---------|
| Lua Support | 0.63.1fix-2 |
| HScript Support | 0.2.0 |
| Psych Engine | See MainMenuState |

### Compile Flags

Both systems are controlled by compile-time flags:

```hxml
#if LUA_ALLOWED     // Enable Lua support
#if HSCRIPT_ALLOWED // Enable HScript support
```

---

## 2. System Architecture

### Core File Structure

```
source/script/
├── hscript/                        # HScript System
│   ├── HScript.hx                  # Main HScript Engine (568 lines)
│   ├── LuaApi.hx                   # Lua Bridge API from HScript (459 lines)
│   └── import.hx                   # Import helper
├── lua/                            # Lua Script System
│   ├── FunkinLua.hx                # Main Lua Engine (3839 lines)
│   ├── DebugLuaText.hx             # Screen debug text class
│   ├── ModchartSprite.hx           # Scriptable Sprite class
│   ├── ModchartText.hx             # Scriptable Text class
│   └── import.hx                   # Import helper
└── FunkinText.hx                   # FNF-styled text component
```

### Script Management in Base States

All states and substates inherit from `MusicBeatState` and `MusicBeatSubstate`, which manage two parallel script arrays:

```haxe
// Fields in MusicBeatState / MusicBeatSubstate
var luaArray:Array<FunkinLua>;     // Lua script instances
var hscriptArray:Array<HScript>;   // HScript instances
```

### Script Initialization Order

In the `create()` method, scripts are initialized in this order:

```
MusicBeatState.create()
├── super.create()
├── initHScripts()          // 1. Load HScript files
├── setOnHscript(...)       // 2. Set HScript variables
└── callOnHscript(          // 3. Trigger HScript callbacks
      'onCreatePost', [])
```

For `ModState` and `ModSubState`, Lua is additionally handled:

```
ModState.create()
├── super.create()          // Automatically runs initHScripts()
├── initLuaScripts()        // Additional: load Lua files
├── setOnLuas(...)          // Set Lua variables
├── callOnLuas(             // Trigger Lua callbacks
      'onCreatePost', [])
└── setOnHscript('data', this.data)
```

### Callback Call Chain

**In MusicBeatState / MusicBeatSubstate:**

```
MusicBeatState.callOnLuas(func, args)
└── Iterates luaArray, calls each script
    ├── Function_StopLua / Function_StopAll → breaks
    └── Function_Stop / Function_Continue → continues

MusicBeatState.callOnHscript(func, args)
├── HScript.callOnGlobalScript()  // Global scripts first
└── Iterates hscriptArray
    └── Function_StopHScript → breaks
```

**In PlayState (overridden):**

```
PlayState.callOnScripts(func, args)          ← PlayState-specific method
├── callOnLuas(func, args)                   ← Overridden from MusicBeatState
│   └── Function_StopLua / Function_StopAll → halt Lua
├── If Lua returns Function_Continue or null
│   └── callOnHScript(func, args)            ← PlayState-specific method
│       └── Function_StopHScript → halt HScript
└── Returns final result
```

**Return Value Priority Rules:**
- Lua returns `Function_Continue` (0) → HScript continues
- Lua returns `Function_Stop` (1) → Only current script stops, others continue
- Lua returns `Function_StopLua` (2) → All Lua stops, HScript continues
- Lua returns `Function_StopHScript` (3) → Lua continues, HScript stops
- Lua returns `Function_StopAll` (4) → All scripts stop

> **Important**: PlayState's `callOnScripts` calls Lua first, then HScript if Lua returns Function_Continue. However, `goodNoteHit` manually calls `callOnLuas` and `callOnHScript` separately with **different parameter signatures** — see Chapter 8 for details.

---

## 3. Lua Script System

### 3.1 FunkinLua Class

`FunkinLua` is the core Lua engine (located at `source/script/lua/FunkinLua.hx`).

**Key Features**:
- Creates and manages Lua interpreter states
- Registers Lua global functions (223+ callbacks)
- Manages script calls and variable assignments
- Provides bidirectional bridging between Lua and Haxe

### 3.2 Lua Script File Format

Lua scripts use the standard `.lua` extension and follow standard Lua 5.x syntax.

**Supported Return Values**:
```lua
Function_Continue    = 0  -- Continue execution (default)
Function_Stop        = 1  -- Stop current execution flow
Function_StopLua     = 2  -- Stop all Lua scripts
Function_StopHScript = 3  -- Stop HScript (ineffective from Lua)
Function_StopAll     = 4  -- Stop all scripts
```

### 3.3 Lua Pre-defined Variables

#### Song/Week Info (available when PlayState is active)

| Variable | Type | Description |
|----------|------|-------------|
| `curBpm` | Float | Current BPM |
| `bpm` | Float | Song BPM |
| `scrollSpeed` | Float | Scroll speed |
| `crochet` | Float | Beat length (ms) |
| `stepCrochet` | Float | Step length (ms) |
| `songLength` | Float | Song length (ms) |
| `songName` | String | Song name |
| `songPath` | String | Formatted song path |
| `curStage` | String | Current stage name |
| `isStoryMode` | Bool | Is story mode |
| `difficulty` | Int | Difficulty index |
| `difficultyName` | String | Difficulty name |
| `difficultyPath` | String | Formatted difficulty path |
| `week` | String | Week name |
| `weekRaw` | Int | Week index |
| `seenCutscene` | Bool | Cutscene played |

#### Gameplay Variables

| Variable | Type | Description |
|----------|------|-------------|
| `score` | Int | Current score |
| `misses` | Int | Miss count |
| `hits` | Int | Hit count |
| `rating` | Float | Rating value |
| `ratingName` | String | Rating name |
| `ratingFC` | String | Full Combo status |
| `inGameOver` | Bool | Is in game over |
| `mustHitSection` | Bool | Current section is player's |
| `altAnim` | Bool | Use alternate animation |
| `gfSection` | Bool | Current section is GF's |
| `healthGainMult` | Float | Health gain multiplier |
| `healthLossMult` | Float | Health loss multiplier |
| `playbackRate` | Float | Playback rate |
| `instakillOnMiss` | Bool | Instant kill on miss |
| `botPlay` | Bool | Auto-play mode |
| `practice` | Bool | Practice mode |
| `combo` | Int | Current combo count |
| `curSection` | Int | Current section |
| `curBeat` | Int | Current beat |
| `curStep` | Int | Current step |
| `curDecBeat` | Float | Current decimal beat |
| `curDecStep` | Float | Current decimal step |
| `hasVocals` | Bool | Has vocal track |
| `defaultBoyfriendX/Y` | Float | Default BF position |
| `defaultOpponentX/Y` | Float | Default opponent position |
| `defaultGirlfriendX/Y` | Float | Default GF position |
| `boyfriendName` | String | Player character name |
| `dadName` | String | Opponent character name |
| `gfName` | String | GF character name |

#### Settings Variables

| Variable | Type | Description |
|----------|------|-------------|
| `downscroll` | Bool | Downscroll mode |
| `middlescroll` | Bool | Middle scroll mode |
| `framerate` | Int | Frame rate limit |
| `ghostTapping` | Bool | Ghost tapping mode |
| `hideHud` | Bool | Hide HUD |
| `timeBarType` | String | Time bar type |
| `scoreZoom` | Bool | Score zoom |
| `cameraZoomOnBeat` | Bool | Camera beat zoom |
| `flashingLights` | Bool | Flashing lights |
| `noteOffset` | Int | Note offset |
| `healthBarAlpha` | Float | Health bar alpha |
| `noResetButton` | Bool | Disable reset button |
| `lowQuality` | Bool | Low quality mode |
| `shadersEnabled` | Bool | Shaders enabled |
| `scriptName` | String | Current script name |
| `currentModDirectory` | String | Current mod directory |
| `guitarHeroSustains` | Bool | Guitar hero sustains |
| `noteSkin` | String | Note skin |
| `splashSkin` | String | Splash skin |
| `splashAlpha` | Float | Splash alpha |
| `luattf` | String | Lua text font setting |

#### Other Variables

| Variable | Type | Description |
|----------|------|-------------|
| `version` | String | Psych Engine version |
| `buildTarget` | String | Build target platform |
| `language` | String | Current language |
| `luaVersion` | String | Lua version |
| `hscriptVersion` | String | HScript version |
| `screenWidth` | Int | Screen width |
| `screenHeight` | Int | Screen height |
| `cameraX/Y` | Float | Camera position |
| `luaDebugMode` | Bool | Lua debug mode |
| `luaDeprecatedWarnings` | Bool | Deprecation warnings |
| `inChartEditor` | Bool | In chart editor |

### 3.4 Lua API Function Reference

#### Property Operations

| Function | Parameters | Description |
|----------|-----------|-------------|
| `getProperty(variable, allowMaps)` | `String, Bool?` | Get object property with dot-chaining |
| `setProperty(variable, value, allowMaps)` | `String, Dynamic, Bool?` | Set object property |
| `getPropertyFromGroup(obj, index, variable)` | `String, Int, Dynamic` | Get property from group element |
| `setPropertyFromGroup(obj, index, variable, value)` | `String, Int, Dynamic, Dynamic` | Set property on group element |
| `getPropertyFromClass(className, variable)` | `String, String` | Get class static property |
| `setPropertyFromClass(className, variable, value)` | `String, String, Dynamic` | Set class static property |
| `removeFromGroup(obj, index, dontDestroy)` | `String, Int, Bool?` | Remove element from group |

#### Object Creation & Manipulation

| Function | Parameters | Description |
|----------|-----------|-------------|
| `makeLuaSprite(tag, image, x, y)` | `String, String, Float, Float` | Create a Sprite |
| `makeAnimatedLuaSprite(tag, image, x, y, gridX?, gridY?)` | ... | Create animated Sprite |
| `addLuaSprite(tag, front)` | `String, Bool` | Add Sprite to scene |
| `addInstance(objectName, inFront)` | `String, Bool` | Add instance reference to script context |
| `instanceArg(instanceName, className)` | `String, String` | Create typed instance argument |
| `addAnimationByPrefix(obj, name, prefix, framerate, loop)` | ... | Add animation by prefix |
| `addAnimationByIndices(obj, name, prefix, indices, framerate, loop)` | ... | Add animation by indices |
| `addAnimationByAnimIndices(obj, name, prefix, indices, framerate, loop)` | ... | Alternative animation add |
| `addAnimation(obj, name, frames, framerate, loop)` | ... | Add animation by frame array |
| `addAnimationByIndicesLoop(obj, name, prefix, indices, framerate)` | ... | Add looping anim by indices |
| `addOffset(obj, anim, x, y)` | `String, String, Float, Float` | Add animation offset |
| `objectPlayAnimation(obj, name, forced, ?reverse, ?startFrame)` | ... | Play object animation |
| `setObjectCamera(obj, camera)` | `String, String` | Set object camera ('game'/'hud'/'other') |
| `setObjectOrder(obj, order)` | `String, Int` | Set render order |
| `getObjectOrder(obj)` | `String` | Get render order |
| `setScrollFactor(obj, x, y)` | `String, Float, Float` | Set scroll factor |
| `loadGraphic(variable, image, gridX?, gridY?)` | ... | Load graphic |
| `loadFrames(variable, image, spriteType)` | ... | Load frame animation |
| `makeGraphic(obj, width, height, color)` | `String, Int, Int, String` | Make colored rectangle graphic |
| `updateHitbox(obj)` | `String` | Update object hitbox |
| `updateHitboxFromGroup(group, index)` | `String, Int` | Update hitbox from group member |
| `createInstance(variableToSave, className, args)` | ... | Create class instance dynamically |
| `callMethod(func, args)` | ... | Call PlayState method |
| `callMethodFromClass(className, func, args)` | ... | Call class static method |
| `luaSpriteExists(tag)` | `String` | Check if sprite exists |
| `luaTextExists(tag)` | `String` | Check if text exists |
| `luaSoundExists(tag)` | `String` | Check if sound exists |
| `objectsOverlap(obj1, obj2)` | `String, String` | Check if objects overlap |
| `getPixelColor(obj, x, y)` | `String, Int, Int` | Get pixel color at coordinates |
| `removeLuaSprite(tag, destroy)` | `String, Bool` | Remove sprite |
| `removeLuaText(tag, destroy)` | `String, Bool` | Remove text |
| `scaleObject(obj, x, y, updateHitbox)` | ... | Scale object |
| `setGraphicSize(obj, x, y, updateHitbox)` | ... | Set graphic size |
| `screenCenter(obj, pos)` | `String, String` | Center on screen |
| `setBlendMode(obj, blend)` | `String, String` | Set blend mode |

#### Text Objects

| Function | Parameters | Description |
|----------|-----------|-------------|
| `makeLuaText(tag, text, width, x, y)` | ... | Create text object |
| `addLuaText(tag)` | `String` | Add text to scene |
| `setTextString(tag, text)` | ... | Set text content |
| `setTextSize(tag, size)` | ... | Set text size |
| `setTextWidth(tag, width)` | ... | Set text width |
| `setTextAlignment(tag, alignment)` | ... | Set text alignment |
| `setTextColor(tag, color)` | ... | Set text color |
| `setTextFont(tag, font)` | ... | Set text font |
| `setTextBorder(tag, size, color, style)` | ... | Set text border |
| `setTextItalic(tag, italic)` | `String, Bool` | Set text italic |
| `setTextAutoSize(tag, value)` | `String, Bool` | Set text auto size |
| `getTextString(tag)` | `String` | Get text content |
| `getTextSize(tag)` | `String` | Get text size |
| `getTextFont(tag)` | `String` | Get text font |
| `getTextWidth(tag)` | `String` | Get text width |

#### Audio

| Function | Parameters | Description |
|----------|-----------|-------------|
| `playSound(sound, volume, tag)` | ... | Play sound effect |
| `playMusic(sound, volume, loop)` | ... | Play music |
| `stopSound(tag)` | ... | Stop sound |
| `pauseSound(tag)` | ... | Pause sound |
| `resumeSound(tag)` | ... | Resume sound |
| `soundFadeIn(tag, duration, from, to)` | ... | Sound fade in |
| `soundFadeOut(tag, duration, to)` | ... | Sound fade out |
| `soundFadeCancel(tag)` | ... | Cancel sound fade |
| `getSoundVolume(tag)` | ... | Get sound volume |
| `setSoundVolume(tag, volume)` | ... | Set sound volume |
| `getSoundTime(tag)` | ... | Get sound playback position |
| `setSoundTime(tag, value)` | ... | Set sound playback position |
| `getSoundPitch(tag)` | ... | Get sound pitch (`#if FLX_PITCH`) |
| `setSoundPitch(tag, value)` | ... | Set sound pitch (`#if FLX_PITCH`) |

#### Tweens

| Function | Parameters | Description |
|----------|-----------|-------------|
| `doTweenX(tag, vars, value, duration, ease)` | ... | X-axis tween |
| `doTweenY(tag, vars, value, duration, ease)` | ... | Y-axis tween |
| `doTweenAngle(tag, vars, value, duration, ease)` | ... | Angle tween |
| `doTweenAlpha(tag, vars, value, duration, ease)` | ... | Alpha tween |
| `doTweenZoom(tag, vars, value, duration, ease)` | ... | Zoom tween |
| `doTweenColor(tag, vars, value, duration, ease)` | ... | Color tween |
| `cancelTween(tag)` | ... | Cancel tween |
| `tweenCameraX/Y/Zoom/Angle/Alpha(value, duration, ease)` | ... | Camera tweens |

#### Timers

| Function | Parameters | Description |
|----------|-----------|-------------|
| `runTimer(tag, time, loops)` | ... | Run a timer |
| `cancelTimer(tag)` | ... | Cancel a timer |
| `getTimer(tag)` | ... | Get timer remaining time |

#### Color Utilities

| Function | Parameters | Description |
|----------|-----------|-------------|
| `getColorFromHex(color)` | `String` | Get color from hex string |
| `getColorFromRGB(r, g, b, a)` | ... | Get color from RGB values |
| `getColorFromName(color)` | `String` | Get color from name (e.g. 'RED') |
| `getColorFromString(color)` | `String` | Get color from string |
| `FlxColor(color)` | `String` | Alias for color from string |

#### Note Tweens (Strum Notes)

| Function | Parameters | Description |
|----------|-----------|-------------|
| `noteTweenX(tag, note, value, duration, ease)` | `String, Int, Float, Float, String` | Note strum X tween |
| `noteTweenY(tag, note, value, duration, ease)` | ... | Note strum Y tween |
| `noteTweenAngle(tag, note, value, duration, ease)` | ... | Note strum angle tween |
| `noteTweenDirection(tag, note, value, duration, ease)` | ... | Note strum direction tween |
| `noteTweenAlpha(tag, note, value, duration, ease)` | ... | Note strum alpha tween |
| `cancelTween(tag)` | ... | Cancel a tween |

#### Camera

| Function | Parameters | Description |
|----------|-----------|-------------|
| `cameraSetTarget(target)` | `target: String` | Set camera focus target |
| `cameraShake(camera, intensity, duration)` | ... | Shake camera |
| `cameraFlash(camera, color, duration, forced)` | ... | Flash camera |
| `cameraFade(camera, color, duration, forced)` | ... | Fade camera |
| `tweenCameraX/Y/Zoom/Angle/Alpha(value, duration, ease)` | ... | Camera tweens |

#### Mouse Input

| Function | Parameters | Description |
|----------|-----------|-------------|
| `mouseClicked(button)` | `button: String` | Check mouse button clicked |
| `mousePressed(button)` | `button: String` | Check mouse button held |
| `mouseReleased(button)` | `button: String` | Check mouse button released |
| `getMouseX(camera)` | `camera: String` | Get mouse X position |
| `getMouseY(camera)` | `camera: String` | Get mouse Y position |

#### Character Operations

| Function | Parameters | Description |
|----------|-----------|-------------|
| `characterDance(character)` | `character: String` | Force character to dance |
| `addCharacterToList(name, type)` | `String, String` | Preload character to list |
| `getCharacterX(type)` | `type: String` | Get character X position |
| `getCharacterY(type)` | `type: String` | Get character Y position |
| `setCharacterX(type, value)` | `type: String, value: Float` | Set character X position |
| `setCharacterY(type, value)` | `type: String, value: Float` | Set character Y position |

#### Dialogue/Video

| Function | Parameters | Description |
|----------|-----------|-------------|
| `startDialogue(dialogueFile, music)` | `String, String?` | Start dialogue from JSON |
| `startVideo(videoFile)` | `videoFile: String` | Play video |
| `triggerEvent(name, arg1, arg2)` | ... | Trigger a custom event |

#### Position Utilities

| Function | Parameters | Description |
|----------|-----------|-------------|
| `getMidpointX(variable)` | `variable: String` | Get object midpoint X |
| `getMidpointY(variable)` | `variable: String` | Get object midpoint Y |
| `getGraphicMidpointX(variable)` | `variable: String` | Get graphic midpoint X |
| `getGraphicMidpointY(variable)` | `variable: String` | Get graphic midpoint Y |
| `getScreenPositionX(variable)` | `variable: String` | Get screen position X |
| `getScreenPositionY(variable)` | `variable: String` | Get screen position Y |

#### Discord Integration

| Function | Parameters | Description |
|----------|-----------|-------------|
| `changePresence(details, state, smallImageKey, hasStartTimestamp, endTimestamp)` | ... | Change Discord presence (`#if desktop` only) |

#### Utility Functions

| Function | Parameters | Description |
|----------|-----------|-------------|
| `stringStartsWith(str, start)` | `String, String` | Check if string starts with |
| `stringEndsWith(str, end)` | `String, String` | Check if string ends with |
| `stringSplit(str, split)` | `String, String` | Split string |
| `stringTrim(str)` | `String` | Trim string whitespace |
| `directoryFileList(folder)` | `folder: String` | List directory contents |
| `getRandomInt(min, max, exclude)` | `Int, Int, String` | Get random integer |
| `getRandomFloat(min, max, exclude)` | `Float, Float, String` | Get random float |
| `getRandomBool(chance)` | `Float` | Get random boolean |
| `getModSetting(saveTag, modName)` | ... | Get mod setting value |
| `setTimeBarColors(leftHex, rightHex)` | ... | Set time bar colors |
| `debugPrint(text, color)` | `text: String, color: String` | Print debug text to screen |
| `close()` | - | Close the current Lua script |

#### Deprecated APIs

These functions are deprecated. Use their replacements instead:

| Deprecated | Replacement |
|------------|-------------|
| `objectPlayAnimation()` | `playAnim()` |
| `characterPlayAnim()` | `playAnim()` |
| `luaSpriteMakeGraphic()` | `makeGraphic()` |
| `luaSpriteAddAnimationByPrefix()` | `addAnimationByPrefix()` |
| `luaSpriteAddAnimationByIndices()` | `addAnimationByIndices()` |
| `luaSpritePlayAnimation()` | `playAnim()` |
| `setLuaSpriteCamera()` | `setObjectCamera()` |
| `setLuaSpriteScrollFactor()` | `setScrollFactor()` |
| `scaleLuaSprite()` | `scaleObject()` |
| `getPropertyLuaSprite()` | `getProperty()` |
| `setPropertyLuaSprite()` | `setProperty()` |
| `musicFadeIn()` | `soundFadeIn()` |
| `musicFadeOut()` | `soundFadeOut()` |

#### Scoring

| Function | Parameters | Description |
|----------|-----------|-------------|
| `addScore(value)` | `Int` | Add score |
| `setScore(value)` | `Int` | Set score |
| `getScore()` | - | Get score |
| `addMisses(value)` | `Int` | Add misses |
| `setMisses(value)` | `Int` | Set misses |
| `getMisses()` | - | Get misses |
| `addHits(value)` | `Int` | Add hits |
| `setHits(value)` | `Int` | Set hits |
| `getHits()` | - | Get hits |
| `setHealth(value)` | `Float` | Set health |
| `addHealth(value)` | `Float` | Add health |
| `getHealth()` | - | Get health |
| `setRatingPercent(value)` | `Float` | Set rating percent |
| `setRatingString(value)` | `String` | Set rating name |
| `setRatingName(value)` | `String` | Alias for setRatingString |
| `setRatingFC(value)` | `String` | Set FC status |

#### Song Control

| Function | Parameters | Description |
|----------|-----------|-------------|
| `getSongPosition()` | - | Get song playback position |
| `setSongPosition(value)` | `Float` | Set song playback position |
| `loadSong(name, difficultyNum)` | ... | Load a new song |
| `startCountdown()` | - | Start/restart countdown |
| `endSong()` | - | End current song |
| `restartSong(skipTransition)` | `Bool` | Restart song |
| `exitSong(skipTransition)` | `Bool` | Exit to main menu |
| `triggerEvent(name, v1, v2)` | ... | Trigger an event |

#### Cross-Script Communication

| Function | Parameters | Description |
|----------|-----------|-------------|
| `getRunningScripts()` | - | Get list of all running scripts |
| `callOnScripts(funcName, args, ignoreStops, ignoreSelf, exclusions)` | ... | Call callback on all scripts |
| `callScript(luaFile, funcName, args)` | ... | Call function on specific script |
| `getGlobalFromScript(luaFile, global)` | ... | Get global from specific script |
| `setGlobalFromScript(luaFile, global, val)` | ... | Set global on specific script |
| `isRunning(luaFile)` | ... | Check if script is running |
| `addLuaScript(luaFile, ignoreAlreadyRunning)` | ... | Dynamically add Lua script |
| `removeLuaScript(luaFile)` | ... | Dynamically remove Lua script |
| `runHaxeCode(codeToRun)` | `String` | Execute HScript code from Lua |
| `addHaxeLibrary(libName, libPackage)` | ... | Import Haxe class to HScript context |
| `callOnLuas(func, args, ignoreStops, exclusions)` | ... | Call all Lua scripts |
| `callOnHScript(func, args, ignoreStops, exclusions)` | ... | Call all HScripts |
| `setOnLuas(varName, arg)` | ... | Set variable on all Lua scripts |
| `setOnHScript(varName, arg)` | ... | Set variable on all HScripts |
| `setOnScripts(varName, arg)` | ... | Set variable on all scripts |

#### Custom Substate

| Function | Parameters | Description |
|----------|-----------|-------------|
| `openCustomSubstate(name, pauseGame)` | ... | Open custom substate |
| `closeCustomSubstate()` | - | Close custom substate |

#### Shaders

| Function | Parameters | Description |
|----------|-----------|-------------|
| `initLuaShader(name, glslVersion)` | ... | Initialize shader |
| `setSpriteShader(obj, shader)` | ... | Set sprite shader |
| `removeSpriteShader(obj)` | ... | Remove sprite shader |
| `getShaderBool/Int/Float(obj, prop)` | ... | Get shader property |
| `setShaderBool/Int/Float(obj, prop, value)` | ... | Set shader property |
| `setShaderSampler2D(obj, prop, bitmapdataPath)` | ... | Set shader texture |

#### Debug

| Function | Parameters | Description |
|----------|-----------|-------------|
| `debugPrint(text)` | `String` | Debug print |
| `luaTrace(text, ignoreCheck, deprecated, color)` | ... | Lua trace output |
| `luaDeprecations(value)` | `Bool` | Enable/disable deprecation warnings |

#### Keyboard/Gamepad Input

| Function | Parameters | Description |
|----------|-----------|-------------|
| `keyJustPressed(name)` | `String` | Check key just pressed |
| `keyPressed(name)` | `String` | Check key held |
| `keyReleased(name)` | `String` | Check key just released |
| `isKeyPressed(name)` | `String` | Generic key check |
| `isGamepadPressed(name)` | ... | Gamepad button check |

#### File & Save System

| Function | Parameters | Description |
|----------|-----------|-------------|
| `getTextFromFile(path, ignoreModFolders)` | ... | Read text file |
| `checkFileExists(path, ignoreModFolders)` | ... | Check file exists |
| `saveFile(path, content, ignoreModFolders)` | ... | Save file |
| `deleteFile(path, ignoreModFolders)` | ... | Delete file |
| `initSaveData(name, ?folder)` | ... | Initialize save data |
| `flushSaveData()` | - | Flush save to disk |
| `getDataFromSave(name, ?default)` | ... | Read save data |
| `setDataFromSave(name, value)` | ... | Write save data |

#### Miscellaneous

| Function | Parameters | Description |
|----------|-----------|-------------|
| `precacheImage(key)` | `String` | Pre-cache image |
| `precacheSound(key)` | `String` | Pre-cache sound |
| `precacheMusic(key)` | `String` | Pre-cache music |
| `loadLanguage(lang)` | ... | Load language pack |
| `getLanguage(key, defaultText)` | ... | Get language text |
| `setVar(name, value)` | ... | Set PlayState variable |
| `getVar(name)` | ... | Get PlayState variable |

---

## 4. HScript System

### 4.1 HScript Class

The `HScript` class (located at `source/script/hscript/HScript.hx`) is the core engine for Haxe scripting.

**Supported Extensions**: `.hx`, `.hscript`, `.hsc`, `.hxs`

### 4.2 Default Variable Bindings

HScript scripts are automatically injected with these variables (from `HScript.getDefaultVariables()`):

#### Haxe Standard Library

```
Math, Std, StringTools, Sys, Type, Reflect,
Date, DateTools, Lambda, EReg, Xml, Json (haxe.Json)
```

#### Flixel Framework

```
FlxG, FlxMath, FlxSprite, FlxCamera,
FlxTimer, FlxTween, FlxEase,
FlxText, FlxSound, FlxGroup, FlxTypedGroup,
FlxSpriteGroup, FlxStringUtil, FlxSpriteUtil,
FlxAtlasFrames, FlxColor (CustomFlxColor)
```

#### Engine Classes

```
Paths, Conductor, ClientPrefs,
Character, Alphabet, FunkinText
```

#### State Classes

```
MusicBeatState, MusicBeatSubstate,
ModState, ModSubState,
PlayState, FreeplayState, StoryMenuState,
TitleState, CreditsState, MainMenuState,
HScript
```

#### Shaders

```
ShaderFilter, ColorMatrixFilter
FlxRuntimeShader (non-Flash + sys platforms)
VideoSpriteManager
MP4Handler (hxCodec >= 3.0.0 or 2.5.1)
```

#### Script Control Constants

```
Function_Stop       = 1  -- Stop current execution
Function_Continue   = 0  -- Continue execution
Function_StopLua    = 2  -- Stop Lua scripts
Function_StopHScript = 3 -- Stop HScripts
Function_StopAll    = 4  -- Stop all scripts
```

#### Shorthand Functions

```haxe
add(obj:Dynamic)              // Add to current state
insert(pos:Int, obj:Dynamic)  // Insert at position
remove(obj:Dynamic, splice:Bool = false)  // Remove from state
```

#### Version & Screen Info

```haxe
hscriptVersion    // "0.2.0"
version           // Psych Engine version
screenWidth       // FlxG.width
screenHeight      // FlxG.height
buildTarget       // "windows" / "linux" / "mac" / "browser" / "android"
language          // Current language string
```

#### Input Functions

```haxe
keyJustPressed(name:String)            // Key just pressed
keyPressed(name:String)                // Key held
keyReleased(name:String)               // Key released
// name supports: 'left', 'down', 'up', 'right', 'accept', 'back', 'pause', 'reset', 'space'

keyboardJustPressed(name:String)       // Any keyboard key just pressed
keyboardPressed(name:String)           // Any keyboard key held
keyboardReleased(name:String)          // Any keyboard key released

anyGamepadJustPressed(name:String)     // Any gamepad button just pressed
anyGamepadPressed(name:String)         // Any gamepad button held
anyGamepadReleased(name:String)        // Any gamepad button released

gamepadAnalogX(id:Int, leftStick:Bool) // Gamepad analog X axis
gamepadAnalogY(id:Int, leftStick:Bool) // Gamepad analog Y axis
gamepadJustPressed(id:Int, name:String) // Specific gamepad button just pressed
gamepadPressed(id:Int, name:String)     // Specific gamepad button held
gamepadReleased(id:Int, name:String)    // Specific gamepad button released
```

#### Import & Bridge Functions

```haxe
importScript(path:String)       // Import another HScript file
runLuaCode(code:String)         // Execute Lua code inline
FunkinLua                       // Reference to Lua engine class
LuaApi                          // Lua API management class
customSubstate                  // Current custom substate
customSubstateName              // Custom substate name string
```

### 4.3 PlayState-Specific Bindings

When `PlayState.instance` is available, HScript automatically binds:

| Variable | Type | Description |
|----------|------|-------------|
| `game` | PlayState | PlayState instance reference |
| `curBpm` | Float | Current BPM |
| `bpm` | Float | Song BPM |
| `scrollSpeed` | Float | Scroll speed |
| `crochet` | Float | Beat length |
| `stepCrochet` | Float | Step length |
| `songLength` | Float | Song length |
| `songName` | String | Song name |
| `songPath` | String | Song path |
| `startedCountdown` | Bool | Countdown started |
| `curStage` | String | Current stage |
| `isStoryMode` | Bool | Story mode |
| `difficulty` | Int | Difficulty index |
| `difficultyName` | String | Difficulty name |
| `difficultyPath` | String | Difficulty path |
| `weekRaw` | Int | Week index |
| `week` | String | Week name |
| `seenCutscene` | Bool | Cutscene seen |
| `boyfriend` | Character | Player character |
| `dad` | Character | Opponent character |
| `gf` | Character | GF character |
| `camGame` | FlxCamera | Game camera |
| `camHUD` | FlxCamera | HUD camera |
| `camOther` | FlxCamera | Other camera |
| `healthGainMult` | Float | Health gain multiplier |
| `healthLossMult` | Float | Health loss multiplier |
| `playbackRate` | Float | Playback rate |
| `instakillOnMiss` | Bool | Instant kill on miss |
| `botPlay` | Bool | Auto-play |
| `practice` | Bool | Practice mode |
| `luattf` | String | Font setting |

#### PlayState Variable Management

```haxe
setVar(name:String, value:Dynamic)        // Set PlayState variable
getVar(name:String):Dynamic                // Get PlayState variable
removeVar(name:String):Bool                // Remove PlayState variable
```

---

## 5. ModState & ModSubState

### 5.1 ModState

`ModState` (located at `source/states/ModState.hx`) supports **both Lua and HScript** scripting. It extends `MusicBeatState` and allows defining a complete game state through script files.

**Script File Locations**:
- HScript: `data/states/<Name>.hx` or `data/states/<Name>/`
- Lua: `data/states/<Name>.lua` or `data/states/<Name>/`

**Usage**:
```haxe
FlxG.switchState(new ModState("MyState"));
// With data
FlxG.switchState(new ModState("MyState", {someData: 123}));
```

**How It Works**:
1. Constructor receives state name and optional data
2. Data persists across state switches via static variables `lastName` and `lastData`
3. `super(scriptName)` passes to `MusicBeatState`, triggering `initHScripts()`
4. `create()` additionally initializes Lua scripts via `initLuaScripts()`, sets Lua variables, and triggers callbacks

**Lua Variable Bindings** (auto-set in ModState.create):
```lua
-- Directly accessible in Lua scripts
data      -- Passed data object
controls  -- Controls object
state     -- ModState instance itself
```

**Data Passing**:
```haxe
// Data persisted to static variables (automatic)
ModState.lastName = "MyState";
ModState.lastData = {playerName: "John"};

// Access in HScript
trace(data.playerName);  // "John"
```

### 5.2 ModSubState

`ModSubState` (located at `source/substates/ModSubState.hx`) is similar to `ModState`, supporting **both Lua and HScript**, but for substates, extending `MusicBeatSubstate`.

**Script File Locations**:
- HScript: `data/states/<Name>.hx` or `data/states/<Name>/`
- Lua: `data/states/<Name>.lua` or `data/states/<Name>/`

**Usage**:
```haxe
// Open from any state or substate
openSubState(new ModSubState("MySubState"));
openSubState(new ModSubState("MySubState", {someData: 456}));
```

**Lua Variable Bindings** (auto-set in ModSubState.create):
```lua
data      -- Passed data object
controls  -- Controls object
state     -- ModSubState instance itself
```

**Differences from ModState**:
- Extends `MusicBeatSubstate` instead of `MusicBeatState`
- Script search path includes legacy `hscripts/substates/` and `lua/substates/` directories
- Different lifecycle methods (`create()`, etc.)

### 5.3 Lifecycle

The `ModState` / `ModSubState` `create()` flow:

```
ModState.create()
├── super.create()
│   ├── FlxG configuration
│   └── initHScripts()   ← Loads data/states/<Name>.hx
│       └── HScript constructor auto-calls onCreate()
├── initLuaScripts()     ← Additional Lua loading
├── setOnLuas('data', data)
├── setOnLuas('controls', controls)
├── setOnLuas('state', this)
├── callOnLuas('onCreatePost', [])
└── setOnHscript('data', data)
```

---

## 6. Helper Classes

### 6.1 DebugLuaText

**File**: `source/script/lua/DebugLuaText.hx`

A class for displaying debug text on screen that automatically fades out.

```haxe
class DebugLuaText extends FlxText
```

**Features**:
- Default duration of 6 seconds, then auto-fades out
- Font selection based on `ClientPrefs.data.luattf`
- Scroll factor set to 0 (fixed to screen)
- Uses `parentGroup:FlxTypedGroup<DebugLuaText>` to manage multiple texts

### 6.2 ModchartSprite

**File**: `source/script/lua/ModchartSprite.hx`

An extendable Sprite class for use in Lua scripts.

```haxe
class ModchartSprite extends FlxSprite
```

**Features**:
- `wasAdded:Bool` — tracks whether added to scene
- `animOffsets:Map<String, Array<Float>>` — animation offset map
- `playAnim(name, forced, reverse, startFrame)` — play animation with auto-offset
- `addOffset(name, x, y)` — add animation offset
- Anti-aliasing enabled by default (based on `ClientPrefs.data.globalAntialiasing`)

### 6.3 ModchartText

**File**: `source/script/lua/ModchartText.hx`

A scriptable text class for use in Lua scripts.

```haxe
class ModchartText extends FlxText
```

**Features**:
- Default camera set to `camHUD`
- Border size of 2 (thicker than normal text)
- Font selection based on `luattf` setting (VCR or system font)
- `wasAdded:Bool` — tracks whether added to scene
- Scroll factor fixed to 0

### 6.4 FunkinText

**File**: `source/script/FunkinText.hx`

A general-purpose FNF-styled text component usable directly in HScript.

```haxe
class FunkinText extends FlxText
```

**Constructor**:
```haxe
new FunkinText(X:Float = 0, Y:Float = 0, FieldWidth:Float = 0,
               ?Text:String, Size:Int = 16, Border:Bool = true)
```

**Features**:
- Default font: `vcr.ttf`
- Default color: white
- Optional black outline (controlled by `Border:Bool` parameter)

**HScript Example**:
```haxe
var myText = new FunkinText(100, 100, 400, "Hello World", 24, true);
add(myText);
```

---

## 7. Lua API (Managing Lua from HScript)

The `LuaApi` class (located at `source/script/hscript/LuaApi.hx`) provides a global API for managing Lua functions from HScript.

### 7.1 Method Reference

| Method | Parameters | Description |
|--------|-----------|-------------|
| `addLuaFunction(name, func, overrideExisting)` | `String, Function, Bool` | Add a new global Lua function |
| `overrideLuaFunction(name, wrapper)` | `String, Function` | Override existing Lua function (wrapper receives original as 1st param) |
| `restoreLuaFunction(name)` | `String` | Restore original function |
| `removeLuaFunction(name)` | `String` | Remove custom function |
| `luaFunctionExists(name)` | `String` | Check if function exists |
| `getLuaFunction(name)` | `String` | Get Lua function reference |
| `getCustomFunctions()` | - | Get all custom function names |
| `getOverriddenFunctions()` | - | Get all overridden function names |
| `getOriginalFunction(name)` | `String` | Get original version of overridden function |
| `batchOverrideLuaFunctions(overrides)` | `Map<String, Function>` | Batch override |
| `batchAddLuaFunctions(functions, overrideExisting)` | `Map<String, Function>, Bool` | Batch add |
| `restoreAllLuaFunctions()` | - | Restore all functions |
| `clearAll()` | - | Clear all custom functions and restore originals |

### 7.2 HScript Usage Examples

```haxe
// Add a global Lua function
LuaApi.addLuaFunction("myFunc", function(x, y) {
    return x + y;
});

// Override an existing function
LuaApi.overrideLuaFunction("getProperty", function(original, variable) {
    trace('Intercepted getProperty call: ' + variable);
    return original(variable);
});

// Restore original function
LuaApi.restoreLuaFunction("getProperty");
```

---

## 8. Script Event Callbacks Reference

The following event callbacks work for both Lua and HScript (same function names in HScript):

### Creation/Destruction

```lua
function onCreate()
    -- Triggered when the lua file starts (some variables not yet created)
end

function onCreatePost()
    -- End of "create" phase
end

function onDestroy()
    -- Triggered when the lua file ends (song fade out finished)
end
```

### Update Loop

```lua
function onUpdate(elapsed)
    -- Start of "update" phase
    -- elapsed: Float - frame time delta
end

function onUpdatePost(elapsed)
    -- End of "update" phase
end
```

### Beat/Step

```lua
function onBeatHit()
    -- Triggered 4 times per section (per beat)
end

function onStepHit()
    -- Triggered 16 times per section (per step)
end
```

### Countdown

```lua
function onStartCountdown()
    -- Countdown started
    -- Return Function_Stop to prevent countdown
    return Function_Continue;
end

function onCountdownTick(counter)
    -- counter = 0 -> "Three"
    -- counter = 1 -> "Two"
    -- counter = 2 -> "One"
    -- counter = 3 -> "Go!"
    -- counter = 4 -> Simultaneous with onSongStart
end

function onSongStart()
    -- Inst and Vocals start playing, songPosition = 0
end
```

### Song End

```lua
function onEndSong()
    -- Song ended / starting transition
    -- Return Function_Stop to prevent ending
    return Function_Continue;
end
```

### Pause

```lua
function onPause()
    -- Called when you press Pause
    -- Return Function_Stop to prevent pausing
    return Function_Continue;
end

function onResume()
    -- Called after resume from pause
end
```

### Game Over

```lua
function onGameOver()
    -- You died! Called every frame when health <= 0
    -- Return Function_Stop to prevent game over screen
    return Function_Continue;
end

function onGameOverConfirm(retry)
    -- Called when pressing Enter/Esc on Game Over
    -- retry: Bool - false if Esc was pressed
end
```

### Dialogue

```lua
function onNextDialogue(line)
    -- Next dialogue line starts
    -- line: Int - dialogue line number (starts at 1)
end

function onSkipDialogue(line)
    -- Skipping unfinished dialogue line
end
```

### Note Hit/Miss

**⚠️ IMPORTANT: Lua vs HScript Parameter Differences**

In `goodNoteHit()`, PlayState manually calls Lua and HScript with **different parameters**. `opponentNoteHit` uses `callOnScripts`, so parameters are consistent.

```lua
-- Lua version
function goodNoteHit(id, direction, noteType, isSustainNote)
    -- Called when you hit a note (after hit calculations)
    -- id: Int       - Note index in the 'notes' group (use getPropertyFromGroup for more)
    -- direction: Int - 0=Left, 1=Down, 2=Up, 3=Right
    -- noteType: String - Note type tag (e.g. 'Hurt Note', 'Hey!')
    -- isSustainNote: Bool - Hold note or not
end
```

```haxe
// HScript version — DIFFERENT PARAMETERS!
function goodNoteHit(note:Note) {
    // Receives the actual Note object reference
    // note.strumTime  - Note timing
    // note.noteData   - Lane direction
    // note.noteType   - Note type
    // note.isSustainNote - Sustain check
    // note.mustPress  - Player lane check
    // note.gfNote     - GF section check
    // ... all Note properties directly accessible
}
```

When using `callOnScripts('goodNoteHit', [id, direction, noteType, isSustainNote])`, both Lua and HScript receive **4 parameters**.

```lua
function opponentNoteHit(id, direction, noteType, isSustainNote)
    -- Opponent note hit (same parameters as goodNoteHit Lua version)
end
```

```lua
function noteMissPress(direction)
    -- Ghost miss (button pressed but no note to hit)
    -- direction: Int - 0=Left, 1=Down, 2=Up, 3=Right
end

function noteMiss(id, direction, noteType, isSustainNote)
    -- Note went off-screen without being hit
    -- Same parameters as goodNoteHit
end
```

### Note Spawning

```lua
function onSpawnNote(id, direction, noteType, isSustainNote)
    -- Called when a note is added to the active notes list
    -- id: Int - Note index in the 'notes' group
    -- direction: Int - Lane direction
    -- noteType: String - Note type
    -- isSustainNote: Bool - Sustain check
end
```

### Keyboard Input

```lua
function preKeyPress(key)
    -- Called before key press hit detection
    -- key: Int - Lane index (0-7)
end

function onKeyPress(key)
    -- Called after key press (after animation plays)
    -- key: Int - Lane index (0-7)
end

function onKeyRelease(key)
    -- Called when a key is released
    -- key: Int - Lane index
end

function onGhostTap(key)
    -- Called on ghost tap (pressed but no note to hit)
    -- key: Int - Lane index
end
```

### Scoring

```lua
function onUpdateScore(miss)
    -- Called when score updates (after each rating calculation)
    -- miss: Bool - true if it was a miss, false if hit
end

function onRecalculateRating()
    -- Called before rating calculation
    -- Return Function_Stop for custom rating
    -- Use setRatingPercent() and setRatingString()
    return Function_Continue;
end
```

### Camera

```lua
function onMoveCamera(focus)
    -- Camera focus changes
    -- focus: String - 'boyfriend', 'dad' or 'gf'
    if focus == 'boyfriend' then
        -- Focus on player
    elseif focus == 'dad' then
        -- Focus on opponent
    elseif focus == 'gf' then
        -- Focus on GF
    end
end
```

### Countdown

```lua
function onCountdownStarted()
    -- Called when the countdown starts playing (after onStartCountdown)
end
```

### Song Section

```lua
function onSectionHit()
    -- Called when a new section starts (after onBeatHit)
    -- The following variables are set automatically beforehand:
    --   mustHitSection, altAnim, gfSection, curSection
end
```

### Events

```lua
function onEvent(name, value1, value2)
    -- Event note triggered
    -- name: String   - Event name
    -- value1: String - Event parameter 1
    -- value2: String - Event parameter 2
    -- NOTE: triggerEvent() does NOT call this function!
end

function eventEarlyTrigger(name)
    -- Override event early trigger time (ms)
    -- Return value overrides engine's default
    -- Example: if name == 'Kill Henchmen' then return 280; end
end
```

### Tween/Timer/Sound

```lua
function onTweenCompleted(tag)
    -- A tween has been completed
    -- tag: String - Tween identifier (first param of doTweenX)
end

function onTimerCompleted(tag, loops, loopsLeft)
    -- A timer loop completed
    -- tag: String       - Timer identifier (first param of runTimer)
    -- loops: Int        - Total loop count set
    -- loopsLeft: Int    - Remaining loop count
end

function onSoundFinished(tag)
    -- A tagged sound finished playing
    -- tag: String - Sound tag (from playSound with tag parameter)
end
```

### Achievements

```lua
function onCheckForAchievement(name)
    -- Achievement check handling
    -- name: String - Achievement name
    -- Return Function_Continue to mark achievement as completed
end
```

---

## 9. Script Load Paths

### Priority Order

Script files are searched in this priority order:

```
1. MOD current dir: mods/<currentMod>/data/states/<Name>.lua/.hx
2. MOD global dir:  mods/<globalMod>/data/states/<Name>.lua/.hx
3. MOD root:        mods/data/states/<Name>.lua/.hx
4. Base path:       assets/data/states/<Name>.lua/.hx
```

### Load Sequence

```
initLuaScripts() / initHScripts()
├── 1. Standalone: data/states/<Name>.lua (or .hx/.hscript)
├── 2. Directory:  data/states/<Name>/*.lua (or *.hx)
└── 3. Legacy:     lua/<stateName>/*.lua (or hscripts/<stateName>/*.hx)
```

For **SubStates**:
```
initLuaScripts() / initHScripts()
├── 1. Standalone: data/states/<Name>.lua (or .hx/.hscript)
├── 2. Directory:  data/states/<Name>/*.lua (or *.hx)
└── 3. Legacy:     lua/substates/<substateName>/*.lua
                   (or hscripts/substates/<substateName>/*.hx)
```

### PlayState Additional Load Paths (Independent from Base Class)

In `PlayState.create()`, in addition to the base class `initHScripts()` and `initLuaScripts()`, the following scripts are also loaded:

**Global scripts (scripts/ directory):**
```
scripts/*.lua / scripts/*.hx
├── mods/<currentMod>/scripts/    (highest priority)
├── mods/<globalMod>/scripts/
├── mods/scripts/
└── assets/scripts/               (lowest priority)
```

**Stage scripts (stages/ directory):**
```
stages/<curStage>.lua / stages/<curStage>.hx
├── mods/stages/<curStage>.lua/.hx   (preferred)
└── assets/stages/<curStage>.lua/.hx (fallback)
```

PlayState load order:
```
PlayState.create()
├── super.create()
│   ├── MusicBeatState.initHScripts()   ← Loads data/states/<Name>.hx
│   └── MusicBeatState.initLuaScripts() ← Loads data/states/<Name>.lua (if called)
├── Additional: scripts/*.lua            ← PlayState-specific
├── Additional: stages/<curStage>.lua    ← PlayState-specific
├── Additional: scripts/*.hx             ← PlayState-specific
└── Additional: stages/<curStage>.hx     ← PlayState-specific
```

### Global HScript

Global HScript files loaded from the `hscripts/` directory execute before all state-specific scripts:

```
hscripts/
├── mods/<currentMod>/hscripts/*.hx    (highest priority)
├── mods/<globalMod>/hscripts/*.hx
├── mods/hscripts/*.hx
└── assets/hscripts/*.hx               (lowest priority)
```

---

## 10. Common Usage Examples

### 10.1 Creating a Custom Menu State

**HScript** (`data/states/MyMenu.hx`):
```haxe
function onCreate() {
    var bg = new FlxSprite().loadGraphic(Paths.image('menuBG'));
    bg.screenCenter();
    add(bg);

    var title = new FunkinText(0, 50, FlxG.width, "My Mod Menu", 32);
    title.screenCenter(X);
    add(title);

    FlxTween.tween(title, {y: title.y + 10}, 0.5, {
        type: PINGPONG,
        ease: FlxEase.quadInOut
    });
}

function onUpdate(elapsed) {
    if (keyJustPressed('accept')) {
        FlxG.switchState(new PlayState());
    }
    if (keyJustPressed('back')) {
        FlxG.switchState(new MainMenuState());
    }
}
```

**Launching**:
```haxe
FlxG.switchState(new ModState("MyMenu"));
```

### 10.2 Lua Custom Chart Events

**Lua** (`data/states/MySong.lua`):
```lua
function onCreate()
    makeLuaSprite('myBgEffect', 'myEffectImage', 0, 0);
    setScrollFactor('myBgEffect', 0.5, 0.5);
    addLuaSprite('myBgEffect', false);
end

function goodNoteHit(id, direction, noteType, isSustainNote)
    if noteType == 'Health Bonus' then
        setHealth(getHealth() + 0.1);
    end
end

function onEvent(name, value1, value2)
    if name == 'MyCustomEvent' then
        setProperty('boyfriend.color', getColorFromHex(value1));
        doTweenAlpha('fadeTween', 'boyfriend', 0.5, tonumber(value2), 'linear');
    end
end

function onBeatHit()
    if curBeat % 8 == 0 then
        cameraFlash('camGame', '0xFFFFFFFF', 0.5);
    end
end
```

### 10.3 Cross-Script Communication in HScript

```haxe
// Add a function to Lua via LuaApi
LuaApi.addLuaFunction("myHelper", function(value) {
    return "Processed: " + value;
});

// Execute Lua code directly
runLuaCode("
    result = myHelper('test')
    debugPrint(result)
");

// Import another HScript file
importScript('data/states/Utils');
```

### 10.4 Creating a Pause Menu with ModSubState

**HScript** (`data/states/MyPause.hx`):
```haxe
function onCreate() {
    var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
    bg.alpha = 0.5;
    add(bg);

    var pauseText = new FunkinText(0, 200, FlxG.width, "Custom Pause", 48);
    pauseText.screenCenter(X);
    add(pauseText);
}

function onUpdate(elapsed) {
    if (keyJustPressed('pause') || keyJustPressed('back')) {
        close();
    }
}
```

**Launching**:
```haxe
openSubState(new ModSubState("MyPause"));
```

---

## 11. Platform-Specific Notes

### 11.1 Build Target Detection

The script system uses platform compile-time checks in multiple places. When writing cross-platform MODs, note:

| Macro | Platforms | Script System Impact |
|-------|-----------|---------------------|
| `#if cpp` | Windows/Linux/Mac (C++ target) | Discord Rich Presence, some video playback |
| `#if !flash` | Non-Flash platforms | `FlxRuntimeShader` support |
| `#if sys` | Desktop (Windows/Linux/Mac) | File I/O (`sys.FileSystem`, `sys.io.File`) |
| `#if windows` | Windows | `buildTarget = "windows"` |
| `#if linux` | Linux | `buildTarget = "linux"` |
| `#if mac` | macOS | `buildTarget = "mac"` |
| `#if html5` / `#if web` | Browser | `buildTarget = "browser"` |
| `#if android` | Android | Android controls, virtual pad, back key handling |

### 11.2 Platform-Limited Lua APIs

```
Desktop only (sys):
├── getTextFromFile(), saveFile(), deleteFile(), checkFileExists()
├── initLuaShader(), setSpriteShader() (requires !flash && sys)
├── runHaxeCode() (requires HSCRIPT_ALLOWED)
└── addHaxeLibrary() (requires HSCRIPT_ALLOWED)

Non-Flash only (!flash):
├── FlxRuntimeShader related functions
└── ShaderFilter, ColorMatrixFilter

Android specific:
├── AndroidControls / FlxVirtualPad auto-handling
├── BACK key mapped to PAUSE
└── Touch input handling
```

### 11.3 Compile Flag Dependencies

```
LUA_ALLOWED     → FunkinLua, ModchartSprite/Text, DebugLuaText
HSCRIPT_ALLOWED → HScript, LuaApi
MODS_ALLOWED    → Mod file system loading (affects script search paths)
VIDEOS_ALLOWED  → MP4/FLV video playback (hxCodec)
```

### 11.4 PlayState Script System Details

PlayState overrides the base class script methods for more complex callback logic:

**`callOnScripts()`** — PlayState's central hub method:
```haxe
PlayState.callOnScripts(funcToCall, args, ignoreStops, exclusions, excludeValues)
├── Default excludeValues = [Function_Continue]
├── callOnLuas(funcToCall, args, ...)
│   ├── Function_StopLua → halt Lua (HScript continues)
│   ├── Function_StopAll → halt all
│   └── Function_Continue → continues
└── If Lua returns null or a value in excludeValues
    └── callOnHScript(funcToCall, args, ...)
        └── Function_StopHScript → halt HScript
```

**`callOnLuas()`** — Overridden from MusicBeatState:
- PlayState version **auto-cleans closed scripts** during iteration
- Handles `Function_StopLua` and `Function_StopAll`

**`callOnHScript()`** — PlayState-specific method (not an override):
- Only executes when `hscriptArray` is non-empty
- Checks if script contains the target function (`script.exists()`)
- Handles `Function_StopHScript` and `Function_StopAll`

**`setOnScripts()`** — Sets variables on both Lua and HScript:
```haxe
PlayState.setOnScripts(variable, arg, exclusions)
├── setOnLuas(variable, arg, exclusions)
└── setOnHScript(variable, arg, exclusions)
```

### 11.5 HScript Error Handling

- Controlled by `ClientPrefs.data.hscriptErrorHandling`
- When enabled: error dialog pops up and error is logged via `TraceManager`
- When disabled: errors are silently ignored, script closes (`closed = true`)

---

## 12. Troubleshooting

### Lua Script Not Executing

1. Verify `LUA_ALLOWED` is enabled at compile time
2. Check script path:
   - `data/states/<StateName>.lua` — use state class name
   - `data/states/<ModStateName>.lua` — use ModState script name
3. Check file exists in correct MOD directory
4. Check `TraceManager` logs for error messages at runtime

### HScript Not Executing

1. Verify `HSCRIPT_ALLOWED` is enabled at compile time
2. Check file extension (supports `.hx`, `.hscript`, `.hsc`, `.hxs`)
3. Ensure `ClientPrefs.data.hscriptErrorHandling` is enabled to see error dialogs
4. Verify `data/states/<Name>.hx` path is correct

### Common Errors

| Issue | Possible Cause | Solution |
|-------|---------------|----------|
| Lua: "attempt to call a nil value" | Function undefined | Check function name spelling |
| HScript: "Variable doesn't exist" | Variable not bound | Check `setOnHscript` was called |
| Script not auto-loading | Wrong file name/path | Use `TraceManager` to check load paths |
| Cross-script communication fails | Script name mismatch | Use `getRunningScripts()` to check names |
| Tween/Timer callback not firing | Tag conflict | Ensure each tween/timer has a unique tag |

---

> This documentation corresponds to MohongEngine script system version Lua 0.63.1fix-2 / HScript 0.2.0
