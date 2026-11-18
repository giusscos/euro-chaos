#!/usr/bin/env bash
# Full headless check: import, compile every script, boot the main scene,
# run all tests. Exits non-zero on the first failure.
# Usage: tools/check.sh            (from the project folder)
#        GODOT=/path/to/Godot tools/check.sh
set -euo pipefail

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.."

step() { printf '\n== %s\n' "$1"; }

step "Import"
"$GODOT" --headless --path . --import >/dev/null 2>&1

step "Compile scripts"
"$GODOT" --headless --path . --script res://tools/check_scripts.gd

step "Boot main scene"
boot_log="$("$GODOT" --headless --path . --quit-after 120 2>&1)"
if grep -qE 'ERROR|SCRIPT ERROR' <<<"$boot_log"; then
	echo "$boot_log"
	exit 1
fi
echo "ok"

step "Tests"
"$GODOT" --headless --path . --fixed-fps 60 --script res://tools/run_tests.gd
