extends SceneTree
## Minimal headless test runner.
##
## Deliberately dependency-free: the sim core must be testable with nothing but
## the engine, so the test rig is not allowed to need a plugin either. Discovers
## every tests/unit/test_*.gd, instantiates it, and runs each method named
## test_*. A test fails by calling fail() or check(); anything else is a pass.
##
##   godot --headless --path game --script res://tests/run_tests.gd [-- filter]

const UNIT_DIR := "res://tests/unit"


func _initialize() -> void:
	var filter := ""
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		filter = args[0]

	var scripts := _discover(UNIT_DIR)
	if scripts.is_empty():
		printerr("no test scripts found in %s" % UNIT_DIR)
		quit(2)
		return

	var total := 0
	var failed := 0
	var started := Time.get_ticks_msec()

	for path in scripts:
		var script: GDScript = load(path)
		if script == null:
			printerr("could not load %s" % path)
			failed += 1
			continue
		var suite: Object = script.new()
		var suite_name := path.get_file().get_basename()
		for method in script.get_script_method_list():
			var name: String = method.name
			if not name.begins_with("test_"):
				continue
			if filter != "" and not (suite_name.contains(filter) or name.contains(filter)):
				continue
			total += 1
			suite.set("failures", PackedStringArray())
			suite.call(name)
			var failures: PackedStringArray = suite.get("failures")
			if failures.is_empty():
				print("  PASS  %s.%s" % [suite_name, name])
			else:
				failed += 1
				print("  FAIL  %s.%s" % [suite_name, name])
				for message in failures:
					print("          %s" % message)

	var elapsed := Time.get_ticks_msec() - started
	print("\n%d test(s), %d failed, %dms" % [total, failed, elapsed])
	quit(1 if failed > 0 else 0)


func _discover(dir_path: String) -> PackedStringArray:
	var found := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	for file in dir.get_files():
		if file.begins_with("test_") and file.ends_with(".gd"):
			found.append(dir_path.path_join(file))
	found.sort()
	return found
