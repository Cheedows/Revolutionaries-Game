#!/bin/sh
# Records a golden trace from the original C++ build.
#
#   tools/trace_harness/record.sh <script> <seed> <output.jsonl>
#
# The build must exist; see tools/trace_harness/build.sh. Runs from the repo
# root so the game finds art/.
set -e
SCRIPT="$1"; SEED="${2:-1}"; OUT="$3"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GAME="${LCS_BUILD:-/tmp/lcsbuild}/src/crimesquad"

[ -x "$GAME" ] || { echo "build the game first: tools/trace_harness/build.sh" >&2; exit 2; }
cd "$ROOT"
# Each recording starts from a clean slate: the game writes save files under
# $HOME/.lcs and loads them on the next launch, so a leftover save from an
# earlier run silently changes the run being recorded.
HOME_DIR="$(mktemp -d)"
export HOME="$HOME_DIR"

# Curses output goes to a throwaway file, not /dev/null: with /dev/null as the
# terminal, ncurses stalls the title screen and the run never advances.
SCREEN="$(mktemp)"
# stdin is closed: the game must take every keystroke from the script, never
# from an inherited pipe or terminal.
attempt=1
while [ "$attempt" -le 3 ]; do
	STATUS=0
	TERM=xterm LCS_TRACE_SCRIPT="$SCRIPT" LCS_TRACE_SEED="$SEED" LCS_TRACE_OUT="$OUT" \
		timeout 120 "$GAME" >"$SCREEN" 2>&1 </dev/null || STATUS=$?
	[ "$STATUS" != 124 ] && break
	echo "attempt $attempt timed out, retrying: $SCRIPT seed=$SEED" >&2
	attempt=$((attempt + 1))
done
rm -f "$SCREEN"
rm -rf "$HOME_DIR"
# A truncated trace is worse than none: it looks like a shorter playthrough.
if [ "${STATUS:-0}" = 124 ]; then
	echo "TIMED OUT after $(wc -l < "$OUT") frame(s): $SCRIPT seed=$SEED" >&2
	exit 1
fi
echo "$(wc -l < "$OUT") frame(s) -> $OUT"
