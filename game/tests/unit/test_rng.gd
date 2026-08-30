extends TestCase
## Proves the GDScript RNG is bit-exact with the C++ original.
##
## Fixtures in tests/golden/rng/ are produced by tools/trace_harness/rng_dump,
## which uses the algorithm extracted verbatim from src/compat.cpp. Each line is
## one raw draw followed by one LCSrandom() draw per modulus in MODULI.

const GOLDEN_DIR := "res://tests/golden/rng"
const SEEDS := [1, 12345, 2147483647]

## Must match MODULI in tools/trace_harness/rng_dump.cpp.
const MODULI := [2, 3, 4, 5, 6, 10, 20, 35, 100, 1000, 65536, 1000000]


func test_matches_cpp_stream() -> void:
	for seed_value: int in SEEDS:
		var path := "%s/seed_%d.txt" % [GOLDEN_DIR, seed_value]
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			fail("missing golden fixture %s — run tools/trace_harness/record_rng.sh" % path)
			return

		var rng := Rng.new(seed_value)
		var line_number := 0
		while not file.eof_reached():
			var line := file.get_line().strip_edges()
			if line.is_empty():
				continue
			line_number += 1
			var expected := line.split(" ")

			var raw := rng.next()
			if str(raw) != expected[0]:
				fail("seed %d line %d: raw draw expected %s, got %d"
						% [seed_value, line_number, expected[0], raw])
				return

			for i in MODULI.size():
				var got := rng.below(MODULI[i])
				if str(got) != expected[i + 1]:
					fail("seed %d line %d: below(%d) expected %s, got %d"
							% [seed_value, line_number, MODULI[i], expected[i + 1], got])
					return

		if line_number < 10000:
			fail("seed %d: fixture had only %d lines, expected 10000" % [seed_value, line_number])


func test_state_roundtrip() -> void:
	var rng := Rng.new(99)
	for i in 50:
		rng.next()
	var saved := rng.get_state()
	var expected := rng.next()

	var restored := Rng.new(0)
	restored.set_state(saved)
	equal(restored.next(), expected, "restored RNG continues the same stream")


func test_below_is_bounded() -> void:
	var rng := Rng.new(7)
	for i in 5000:
		var value := rng.below(6)
		if value < 0 or value > 5:
			fail("below(6) returned out-of-range %d" % value)
			return
	equal(rng.below(0), 0, "below(0) is defined as 0")
	equal(rng.below(1), 0, "below(1) is always 0")


func test_between_is_inclusive() -> void:
	var rng := Rng.new(11)
	var seen_low := false
	var seen_high := false
	for i in 5000:
		var value := rng.between(3, 5)
		if value < 3 or value > 5:
			fail("between(3,5) returned %d" % value)
			return
		seen_low = seen_low or value == 3
		seen_high = seen_high or value == 5
	check(seen_low and seen_high, "between() reaches both endpoints")
	equal(rng.between(4, 4), 4, "between() with equal bounds")
