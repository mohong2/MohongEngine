@echo off
color 0a
cd /d %~dp0\..
set HAXELIB_PATH=%CD%\.haxelib
echo BUILDING GAME
echo Using HAXELIB_PATH=%HAXELIB_PATH%
haxelib run lime build windows -release %*
echo.
echo done.
pause
explorer.exe export\release\windows\bin
