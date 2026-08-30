#!/bin/sh
# Runs the headless test suite. Pass a substring to filter tests.
#
#   tools/run_tests.sh            # everything
#   tools/run_tests.sh rng        # only matching suites/tests
set -e
GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

"$GODOT" --headless --path "$ROOT/game" --import >/dev/null

# A test that hits a runtime error stops where it is, and the runner has no way
# to see that from inside the engine — it just records no failures and prints
# PASS. So the output is watched for engine-level errors too, and any of them
# fails the run.
log="$(mktemp)"
trap 'rm -f "$log"' EXIT
status=0
if [ -n "$1" ]; then
	"$GODOT" --headless --path "$ROOT/game" --script res://tests/run_tests.gd -- "$1" 2>&1 | tee "$log" || status=$?
else
	"$GODOT" --headless --path "$ROOT/game" --script res://tests/run_tests.gd 2>&1 | tee "$log" || status=$?
fi

if grep -q "SCRIPT ERROR" "$log"; then
	echo "FAILED: a test hit a runtime error; a PASS above cannot be trusted" >&2
	exit 1
fi
exit $status
