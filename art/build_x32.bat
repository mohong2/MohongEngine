@echo off
color 0a
cd ..
set HAXELIB_PATH=%CD%\.haxelib
echo BUILDING GAME
lime build windows -32 -release -D 32bits
echo.
echo done.
pause
pwd
explorer.exe export\32bit\windows\bin
