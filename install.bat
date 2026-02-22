@echo off
echo ================================================
echo Mohong Engine - HaxeLib Installation Script
echo ================================================

:: Create local .haxelib directory if it doesn't exist
if not exist ".haxelib" mkdir ".haxelib"
cd .haxelib

echo Installing libraries to local .haxelib directory...

:: Install core libraries
echo Installing flixel...
haxelib install flixel --always

echo Installing flixel-addons...
haxelib install flixel-addons --always

echo Installing hscript-improved...
haxelib git hscript-improved https://github.com/Erizur/hscript-improved

echo Installing flixel-ui...
haxelib install flixel-ui --always

:: Install Lua support libraries
echo Installing linc_luajit...
haxelib git linc_luajit https://github.com/superpowers04/linc_luajit

:: Install video support libraries
echo Installing hxCodec...
haxelib install hxCodec --always

:: Install audio libraries (for Switch support)
echo Installing faxe...
haxelib install faxe --always

:: Install utility libraries
echo Installing tjson...
haxelib install tjson --always

echo Installing extension-androidtools...
haxelib install extension-androidtools --always

echo Installing discord_rpc (optional)...
haxelib git discord_rpc https://github.com/Aidan63/linc_discord-rpc

echo ================================================
echo Installation completed!
echo ================================================
echo.
echo To use these local libraries, run:
echo haxelib dev [library_name] .haxelib\[library_name]
echo.
echo Available libraries:
haxelib list

pause