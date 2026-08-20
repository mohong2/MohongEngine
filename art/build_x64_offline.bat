@echo off
REM Offline build: no online code is compiled, no network requests are made, and the main menu has no online entry.
cd /d %~dp0\..
set HAXELIB_PATH=%CD%\.haxelib
echo BUILDING OFFLINE GAME
echo Using HAXELIB_PATH=%HAXELIB_PATH%
haxelib run lime build windows -release -D SEIUN_NO_ONLINE %*
echo done.
pause
