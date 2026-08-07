@echo off
color 0a
cd ..
set HAXELIB_PATH=%CD%\.haxelib
echo BUILDING GAME
lime build windows -release
echo.
echo done.
pause
pwd
explorer.exe export\release\windows\bin
