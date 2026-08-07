@echo off
color 0a
cd ..
set HAXELIB_PATH=%CD%\.haxelib
@echo on
echo BUILDING GAME
lime test html5 -release
pause
