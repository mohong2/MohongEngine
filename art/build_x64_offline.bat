@echo off
REM 离线构建: 不编译任何联机代码, 不发起任何网络请求, 主菜单无联机入口。
cd /d %~dp0\..
set HAXELIB_PATH=%CD%\.haxelib
echo BUILDING OFFLINE GAME
echo Using HAXELIB_PATH=%HAXELIB_PATH%
haxelib run lime build windows -release -D SEIUN_NO_ONLINE %*
echo done.
pause
