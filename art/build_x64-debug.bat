@echo off
color 0a
cd ..
set HAXELIB_PATH=%CD%\.haxelib
echo BUILDING GAME
lime build windows -debug
echo.
echo done.
pause
pwd
explorer.exe export\debug\windows\bin
