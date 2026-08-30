#!/bin/sh
# Records the golden trace matrix: every script in scripts/ at every seed.
#
# Traces land gzipped in game/tests/golden/traces/ as <script>.<seed>.jsonl.gz.
# Re-run this after changing the harness; commit the result with the reason.
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/game/tests/golden/traces"
SEEDS="${SEEDS:-1 777 12345}"

mkdir -p "$OUT"
for script in "$ROOT"/tools/trace_harness/scripts/*.keys; do
	name="$(basename "$script" .keys)"
	for seed in $SEEDS; do
		tmp="$(mktemp)"
		"$ROOT/tools/trace_harness/record.sh" "$script" "$seed" "$tmp" >/dev/null
		gzip -9 -c "$tmp" > "$OUT/$name.$seed.jsonl.gz"
		echo "$name seed=$seed $(wc -l < "$tmp") frames -> $(basename "$OUT/$name.$seed.jsonl.gz")"
		rm -f "$tmp"
	done
done
