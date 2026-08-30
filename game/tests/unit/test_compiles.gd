extends TestCase
## Every script under core/, app/ and data/ must compile.
##
## This exists because of a real failure: a type-inference error in one system
## left it uncompilable, and calls into it silently returned null rather than
## failing — which let a suite pass while the system it tested did nothing.

const ROOTS := ["res://core", "res://app", "res://data"]


func test_every_script_loads() -> void:
	for root: String in ROOTS:
		var failures := _check(root)
		if not failures.is_empty():
			fail("scripts that do not compile: %s" % ", ".join(failures))
			return


func _check(path: String) -> Array[String]:
	var failures: Array[String] = []
	var dir := DirAccess.open(path)
	if dir == null:
		return failures
	for file in dir.get_files():
		if not file.ends_with(".gd"):
			continue
		var script: GDScript = load(path.path_join(file))
		if script == null or not script.can_instantiate():
			failures.append(path.path_join(file))
	for sub in dir.get_directories():
		failures.append_array(_check(path.path_join(sub)))
	return failures
