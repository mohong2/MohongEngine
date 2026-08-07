#!/bin/bash
# One-time WSL toolchain setup: Haxe 4.2.5 + Neko 2.3.0 (official tarballs in ~)
# Run after extracting haxe_20220306074705_e5eec31 and neko-2.3.0-linux64 in your home dir:
#   wsl cp /mnt/o/.../setup/wsl-toolchain-setup.sh ~/wsl-toolchain-setup.sh
#   wsl bash ~/wsl-toolchain-setup.sh
set -e
cd "$HOME"

if [ -d haxe_20220306074705_e5eec31 ]; then
	if [ ! -e haxe ]; then
		mv haxe_20220306074705_e5eec31 haxe
	else
		rm -rf haxe_20220306074705_e5eec31
	fi
fi
if [ -d neko-2.3.0-linux64 ]; then
	if [ ! -e neko ]; then
		mv neko-2.3.0-linux64 neko
	else
		rm -rf neko-2.3.0-linux64
	fi
fi

# Install the environment helper into the WSL home dir
if [ -f /mnt/o/FNF-PsychEngine-0.6.3/FNF-PsychEngine-0.6.3/FNF-SeiunEngine/setup/wsl-env.sh ]; then
	cp /mnt/o/FNF-PsychEngine-0.6.3/FNF-PsychEngine-0.6.3/FNF-SeiunEngine/setup/wsl-env.sh "$HOME/wsl-env.sh"
fi
grep -q "wsl-env.sh" "$HOME/.bashrc" 2>/dev/null || echo ". \$HOME/wsl-env.sh" >> "$HOME/.bashrc"

. "$HOME/wsl-env.sh"
echo "haxe:    $(haxe -version 2>&1)"
echo "neko:    $(neko -version 2>&1)"
echo "haxelib: $(haxelib version 2>&1)"
