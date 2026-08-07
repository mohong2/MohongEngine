@echo off
rem ============================================================
rem SeiunEngine - Lime Android template patches
rem
rem lime 8.0.1's android template needs two tweaks that cannot be
rem expressed through Project.xml:
rem   1. gradle.properties   -> android.useAndroidX=true + jetifier
rem      (extension-androidtools ships AndroidX dependencies)
rem   2. AndroidManifest.xml -> android:requestLegacyExternalStorage
rem      (keeps Android 10 users on the public /storage/emulated/0
rem       root so mods stay installable without root)
rem   3. app/build.gradle    -> lintOptions.checkReleaseBuilds=false
rem      (AGP 4.1 lint crashes on some JDK/OS combos; a game APK does
rem       not need lint)
rem
rem The patched files live in templates/android/template/ (versioned
rem in this repo) and are copied over the local Lime haxelib here.
rem Run this again after `haxelib update lime`.
rem ============================================================

set HAXELIB_PATH=%CD%\.haxelib
set LIME_TEMPLATE=%HAXELIB_PATH%\lime\8,0,1\templates\android\template

if not exist "%LIME_TEMPLATE%" (
	echo ERROR: Lime 8.0.1 template not found at %LIME_TEMPLATE%
	exit /b 1
)

copy /Y "templates\android\template\gradle.properties" "%LIME_TEMPLATE%\gradle.properties" >nul
copy /Y "templates\android\template\app\src\main\AndroidManifest.xml" "%LIME_TEMPLATE%\app\src\main\AndroidManifest.xml" >nul
copy /Y "templates\android\template\app\build.gradle" "%LIME_TEMPLATE%\app\build.gradle" >nul

rem SeiunOverlay - modern floating keyboard button (TYPE_APPLICATION_OVERLAY)
rem The Java class is registered as an android extension in Project.xml and
rem is compiled straight into the app source set (org.haxe.extension package).
if not exist "%LIME_TEMPLATE%\app\src\main\java\org\haxe\extension" mkdir "%LIME_TEMPLATE%\app\src\main\java\org\haxe\extension"
copy /Y "templates\android\java\org\haxe\extension\SeiunOverlay.java" "%LIME_TEMPLATE%\app\src\main\java\org\haxe\extension\SeiunOverlay.java" >nul

rem Material keyboard icon for the floating button.
if not exist "%LIME_TEMPLATE%\app\src\main\res\drawable" mkdir "%LIME_TEMPLATE%\app\src\main\res\drawable"
copy /Y "templates\android\template\app\src\main\res\drawable\seiun_ic_keyboard.xml" "%LIME_TEMPLATE%\app\src\main\res\drawable\seiun_ic_keyboard.xml" >nul

echo Lime android templates patched OK.
