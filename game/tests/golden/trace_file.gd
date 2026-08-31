class_name TraceFile
extends RefCounted
## Reads a golden trace recorded from the original C++ build.
##
## Traces live in tests/golden/traces as gzipped JSON Lines, one record per
## player decision point: what the game drew, how much randomness it consumed,
## and its whole simulation state.

const TRACE_DIR := "res://tests/golden/traces"
const MAX_SIZE := 64 * 1024 * 1024


## Every recorded (script, seed) pair, as {name, seed, path}.
static func list_traces() -> Array[Dictionary]:
	var traces: Array[Dictionary] = []
	var dir := DirAccess.open(TRACE_DIR)
	if dir == null:
		return traces
	for file in dir.get_files():
		if not file.ends_with(".jsonl.gz"):
			continue
		var parts := file.trim_suffix(".jsonl.gz").split(".")
		if parts.size() != 2:
			continue
		traces.append({
			"name": parts[0],
			"seed": int(parts[1]),
			"path": TRACE_DIR.path_join(file),
		})
	traces.sort_custom(func(a, b): return str(a.path) < str(b.path))
	return traces


## Decodes one trace into its records, or [] if it cannot be read.
static func load_records(path: String) -> Array:
	var compressed := FileAccess.get_file_as_bytes(path)
	if compressed.is_empty():
		return []
	var raw := compressed.decompress_dynamic(MAX_SIZE, FileAccess.COMPRESSION_GZIP)
	if raw.is_empty():
		return []
	var records: Array = []
	for line in raw.get_string_from_utf8().split("\n"):
		if line.strip_edges().is_empty():
			continue
		var parsed: Variant = JSON.parse_string(line)
		if parsed == null:
			return []
		records.append(parsed)
	return records


## The C++ writes RNG words through a signed conversion; this brings them back
## into the unsigned 32-bit range the generator actually works in.
static func to_unsigned(value: int) -> int:
	return value & 0xffffffff
