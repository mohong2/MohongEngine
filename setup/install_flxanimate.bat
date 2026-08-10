@echo off
rem SeiunEngine: install flxanimate 4.0.0 and apply the Haxe 4.2.5 compatibility patch.
rem Run from the repository root. Requires haxelib on PATH.
cd /d "%~dp0.."

haxelib install flxanimate 4.0.0
if errorlevel 1 (
  echo Failed to install flxanimate 4.0.0. Check network / haxelib.
  exit /b 1
)

set FLX_DIR=.haxelib\flxanimate\4,0,0
if not exist "%FLX_DIR%" (
  echo flxanimate 4.0.0 not found in .haxelib after install.
  exit /b 1
)

copy /Y setup\flxanimate_haxe425_patch\FlxElement.hx "%FLX_DIR%\flxanimate\animate\FlxElement.hx" >nul
copy /Y setup\flxanimate_haxe425_patch\MacroAnimationData.hx "%FLX_DIR%\flxanimate\data\MacroAnimationData.hx" >nul
copy /Y setup\flxanimate_haxe425_patch\FlxAnimateFrames.hx "%FLX_DIR%\flxanimate\frames\FlxAnimateFrames.hx" >nul

echo flxanimate 4.0.0 installed and patched for Haxe 4.2.5.
