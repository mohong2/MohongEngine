@echo off
color 0a
cd ..
set HAXELIB_PATH=%CD%\.haxelib
echo BUILDING GAME
lime test windows -debug
echo.
echo done.
pause
