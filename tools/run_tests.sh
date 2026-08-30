#!/bin/sh
# Runs the headless test suite. Pass a substring to filter tests.
#
#   tools/run_tests.sh            # everything
#   tools/run_tests.sh rng        # only matching suites/tests
set -e
GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

"$GODOT" --headless --path "$ROOT/game" --import >/dev/null
if [ -n "$1" ]; then
	"$GODOT" --headless --path "$ROOT/game" --script res://tests/run_tests.gd -- "$1"
else
	"$GODOT" --headless --path "$ROOT/game" --script res://tests/run_tests.gd
fi
