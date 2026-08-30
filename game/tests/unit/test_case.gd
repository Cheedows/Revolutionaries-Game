class_name TestCase
extends RefCounted
## Base class for unit tests. See tests/run_tests.gd.

var failures := PackedStringArray()


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [message, expected, actual])


func fail(message: String) -> void:
	failures.append(message)
