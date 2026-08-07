@echo off
rem ============================================================
rem  SeiunEngine: sync from Windows -> WSL, then build Linux release
rem  Run this from Windows after editing code.
rem  (.haxelib and WSL export are preserved; local lib fixes kept)
rem ============================================================
set "SRC=O:\FNF-PsychEngine-0.6.3\FNF-PsychEngine-0.6.3\FNF-SeiunEngine"
set "DST=\\wsl.localhost\Ubuntu-24.04\home\hjy42\SeiunEngine"

echo [1/4] Syncing source...
robocopy "%SRC%\source" "%DST%\source" /MIR /NFL /NDL /NJH /NP
echo [2/4] Syncing assets...
robocopy "%SRC%\assets" "%DST%\assets" /E /NFL /NDL /NJH /NP
echo [3/4] Syncing project files...
robocopy "%SRC%" "%DST%" Project.xml hmm.json install.bat /NFL /NDL /NJH /NP
robocopy "%SRC%\setup" "%DST%\setup" /MIR /NFL /NDL /NJH /NP

rem -- Libraries: let the user choose ---------------------------
echo.
echo Libraries (.haxelib) sync:
echo   [1] Sync libraries  - copy local haxelib libs (incl. hxvlc fork
echo       fixes) into WSL. Use when you modified a library.
echo   [2] Skip libraries - faster, uses whatever is already in WSL.
echo.

rem If WSL has no .haxelib yet, skipping is pointless - force sync.
wsl -d Ubuntu-24.04 bash -lc "test -d ~/SeiunEngine/.haxelib" >nul 2>nul <nul
set "LIBS_FORCED=0"
if errorlevel 1 (
	echo WSL has no .haxelib yet - library sync is required.
	set "LIBS_FORCED=1"
)
if "%LIBS_FORCED%"=="1" goto libs_forced
choice /C 12 /N /M "Sync libs? [1=yes, 2=no] "
if errorlevel 2 goto libs_skip
set "SYNC_LIBS=1"
goto libs_chosen
:libs_forced
set "SYNC_LIBS=1"
goto libs_chosen
:libs_skip
set "SYNC_LIBS=2"
:libs_chosen

if "%SYNC_LIBS%"=="1" (
    echo [4/4] Syncing .haxelib libraries...
    robocopy "%SRC%\.haxelib" "%DST%\.haxelib" /E /NFL /NDL /NJH /NP /XD .git .gradle /R:1 /W:2
    echo [4b] Syncing hxvlc-local git source...
    robocopy "%SRC%\hxvlc-local" "%DST%\hxvlc-local" /E /NFL /NDL /NJH /NP /XD .git /R:1 /W:2
) else (
    echo [4/4] Skipping library sync.
)

rem Notes: /XD .git .gradle skips locked git internals (ERROR 5) and
rem gradle caches. /R:1 /W:2 limits retries so we never stall 30s.

echo [5/5] Building Linux release in WSL...
wsl -d Ubuntu-24.04 bash -lc "source ~/wsl-env.sh && cd ~/SeiunEngine && export HAXELIB_PATH=\"$HOME/SeiunEngine/.haxelib\" && haxelib run lime build linux -release"

if %errorlevel%==0 (
	echo.
	echo Build OK! Copying artifact back to Windows...
	robocopy "%DST%\export\release\linux" "%SRC%\export\release\linux" /E /NFL /NDL /NJH /NP
	echo.
	echo Output: %SRC%\export\release\linux\bin
	echo WSL copy: \\wsl.localhost\Ubuntu-24.04\home\hjy42\SeiunEngine\export\release\linux\bin
) else (
	echo.
	echo Build FAILED - see errors above.
)
pause
