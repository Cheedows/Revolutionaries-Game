#!/bin/sh
# Renders every screen and checks that what came out is usable.
#
# The headless suite measures minimum sizes, which is all it honestly can: a
# container only lays its children out inside a live tree and a --script run
# has none, so a label never wraps and a row never learns how tall it needs to
# be. Three rounds of visibly broken layout went past a green suite that way.
#
# This needs a rasteriser, so it runs under a virtual X server. It is the only
# check in the project that looks at pixels.
#
#   tools/check_layout.sh
#   tools/check_layout.sh --shot new_game_screen 400x800 out.png [presses...]
set -e
GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

run() {
	xvfb-run -a -s "-screen 0 1600x1600x24" "$GODOT" --path "$ROOT/game" \
		--rendering-driver opengl3 --resolution "${RES:-400x800}" "$@"
}

if [ "$1" = "--shot" ]; then
	shift
	run --script res://../tools/shots/shoot.gd -- "$@"
	exit $?
fi

log="$(mktemp)"
trap 'rm -f "$log"' EXIT
status=0
run --script res://../tools/shots/check_layout.gd 2>&1 | tee "$log" || status=$?
if grep -q "SCRIPT ERROR" "$log"; then
	echo "FAILED: the layout check hit a runtime error" >&2
	exit 1
fi
grep -qF "Every screen is laid out inside itself" "$log" || status=1
exit $status
