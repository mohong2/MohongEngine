@echo off
rem ============================================================
rem SeiunEngine - Lime iOS template patches
rem
rem lime 8.0.1's iOS Info.plist template gets two extra keys so
rem the app's Documents folder shows up in the system Files app:
rem   UIFileSharingEnabled                 -> allow file sharing
rem   LSSupportsOpeningDocumentsInPlace    -> keep files in place
rem This lets players drop charts into the app and export saves
rem without a computer.
rem
rem Run this again after `haxelib update lime`.
rem ============================================================

set HAXELIB_PATH=%CD%\.haxelib
set LIME_IOS_TEMPLATE=%HAXELIB_PATH%\lime\8,0,1\templates\ios\template

if not exist "%LIME_IOS_TEMPLATE%" (
	echo ERROR: Lime 8.0.1 iOS template not found at %LIME_IOS_TEMPLATE%
	exit /b 1
)

if not exist "%LIME_IOS_TEMPLATE%\{{app.file}}" (
	echo ERROR: iOS app template folder not found
	exit /b 1
)

copy /Y "templates\ios\template\{{app.file}}\{{app.file}}-Info.plist" "%LIME_IOS_TEMPLATE%\{{app.file}}\{{app.file}}-Info.plist" >nul

echo Lime iOS templates patched OK.
