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

for probe in blank creatures training checks equipment politics activities damage congress elections court names opinion wincheck world spawn sitemaps; do
	tmp="$(mktemp)"
	home="$(mktemp -d)"
	screen="$(mktemp)"
	# Some probes reach code that reports through getkey(); giving them a
	# keystroke script keeps that from blocking. Frames go to /dev/null: the
	# probe's own output is what matters.
	keys="$(mktemp)"
	i=0
	while [ $i -lt 4000 ]; do echo "[space]" >> "$keys"; i=$((i + 1)); done
	HOME="$home" TERM=xterm LCS_PROBE="$probe" LCS_PROBE_OUT="$tmp" \
		LCS_TRACE_SCRIPT="$keys" LCS_TRACE_OUT=/dev/null \
		timeout 120 "$GAME" >"$screen" 2>&1 </dev/null
	gzip -9 -c "$tmp" > "$OUT/$probe.jsonl.gz"
	echo "$probe: $(wc -l < "$tmp") samples -> $OUT/$probe.jsonl.gz"
	rm -rf "$tmp" "$home" "$screen" "$keys"
done
