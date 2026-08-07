#!/bin/sh
# SeiunEngine - Linux / WSL dependency setup
# Run from the project root:  ./setup/setup-unix.sh
set -e

# Load Haxe/Neko environment if present (~/wsl-env.sh or project setup/wsl-env.sh)
if [ -f "$HOME/wsl-env.sh" ]; then
	. "$HOME/wsl-env.sh"
elif [ -f "./setup/wsl-env.sh" ]; then
	. "./setup/wsl-env.sh"
fi

if ! command -v haxe >/dev/null 2>&1; then
	echo "ERROR: haxe not found on PATH."
	echo "Install Haxe 4.2.5 and Neko first (see setup/wsl-env.sh), then re-run this script."
	exit 1
fi

echo "=== Haxe version: $(haxe -version 2>&1) ==="

echo "=== Installing system packages (g++, make, VLC, GL/X11 dev headers) ==="
sudo apt-get update
sudo apt-get install -y g++ make git curl unzip \
	zenity \
	libpulse0 \
	libvlc-dev libvlccore-dev \
	libgl1-mesa-dev libglu1-mesa-dev libx11-dev

if [ -d ".haxelib" ] && [ -n "$(ls -A .haxelib 2>/dev/null)" ]; then
	echo "=== .haxelib already exists -> pointing haxelib to it and SKIPPING library install ==="
	echo "    (this keeps any local modifications you made to the libraries)"
	haxelib setup "$(pwd)/.haxelib"
	haxelib fixrepo
else
	echo "=== Configuring haxelib (global ~/haxelib) ==="
	haxelib setup ~/haxelib

	echo "=== Installing Haxe libraries (see hmm.json) ==="
	haxe -cp ./setup -main Main --interp
fi

echo "=== Patching Lime iOS templates (Files-app Documents sharing) ==="
LIME_IOS_TEMPLATE="$(pwd)/.haxelib/lime/8,0,1/templates/ios/template"
if [ -f "$LIME_IOS_TEMPLATE/{{app.file}}/{{app.file}}-Info.plist" ]; then
	cp "templates/ios/template/{{app.file}}/{{app.file}}-Info.plist" \
		"$LIME_IOS_TEMPLATE/{{app.file}}/{{app.file}}-Info.plist"
	echo "Lime iOS templates patched OK."
else
	echo "WARNING: Lime iOS template not found - skipped (run after haxelib install lime)."
fi

echo ""
echo "Done! Now build with:"
echo "  haxelib run lime build linux -release"
echo "Output: export/release/linux/bin"
