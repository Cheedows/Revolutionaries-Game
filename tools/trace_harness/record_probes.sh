#!/bin/sh
# Records the system probes: each runs one piece of the original in isolation
# and dumps what it produced, so a ported system can be diffed against it.
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/game/tests/golden/probes"
GAME="${LCS_BUILD:-/tmp/lcsbuild}/src/crimesquad"

[ -x "$GAME" ] || { echo "build the game first: tools/trace_harness/build.sh" >&2; exit 2; }
mkdir -p "$OUT"
cd "$ROOT"

for probe in blank creatures; do
	tmp="$(mktemp)"
	home="$(mktemp -d)"
	screen="$(mktemp)"
	HOME="$home" TERM=xterm LCS_PROBE="$probe" LCS_PROBE_OUT="$tmp" \
		timeout 120 "$GAME" >"$screen" 2>&1 </dev/null
	gzip -9 -c "$tmp" > "$OUT/$probe.jsonl.gz"
	echo "$probe: $(wc -l < "$tmp") samples -> $OUT/$probe.jsonl.gz"
	rm -rf "$tmp" "$home" "$screen"
done
