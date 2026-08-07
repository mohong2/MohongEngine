# RIGHT NOW THE MODS FOLDER DOES NOT WORK ENTIRELY JUST YET!!!
## THIS IS WORK IN PROGRESS!!!

# QUICK AND DIRTY MOD GUIDE

With the 0.2.6 update, I added a bit of a slightly nicer mod support backend.

It's POLYMOD, which is made by Lars Doucet: https://github.com/larsiusprime/polymod

You may have noticed that there's a new folder in the assets. MODS. Within it you will see 2 files. modList.txt, and a folder called introMod.
modList.txt will load any folder into the game. Put the folder you want to load into a new line in modList.txt, and reboot the game.

Now you may be wondering, what do I put in the folder? Well later down it'll get a bit more complicated, especially as I'll make the IN-GAME mod loader nicer.

# Close Animation Modding (Windows)

The window close animation (Alt+F4 / X button) exposes three hooks so mods can customize
or fully replace it. They only run on Windows.

## HScript (global scripts)

Add these functions to any global HScript:

```haxe
function onCloseAnimStart(style:String, speed:Float) {
	// Return a different style name ("squeeze", "zoom", "drop", "slide", "off"),
	// or {style: ..., duration: ...} to also change the total duration.
	return null; // keep current style
}

function onCloseAnimUpdate(progress:Float, style:String, speed:Float) {
	// progress goes 0 -> 1. Return {x, y, width, height} to take full control
	// of the window position/size every frame.
	return null; // use the built-in animation
}

function onCloseAnimEnd(style:String) {
	// Called right before the window actually closes.
}
```

## Lua (current state scripts)

Lua scripts attached to the current state (e.g. data/states/TitleState.lua,
data/states/MainMenuState.lua) can implement the same functions:

```lua
function onCloseAnimStart(style, speed)
	-- return "off" to close instantly, or {style = "zoom", duration = 0.5}
	return nil
end

function onCloseAnimUpdate(progress, style, speed)
	-- return {x = ..., y = ..., width = ..., height = ...} for full control
	return nil
end

function onCloseAnimEnd(style)
	-- cleanup if needed
end
```

Unknown/custom style names fall back to a center "zoom" animation; pair
`onCloseAnimUpdate` with a custom style name for a fully custom animation.
