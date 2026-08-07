@echo off
rem Launch the SeiunEngine Linux build.
rem The window appears on the Windows desktop via WSLg.
wsl -d Ubuntu-24.04 bash -lc "cd ~/SeiunEngine/export/release/linux/bin && exec ./SeiunEngine"
