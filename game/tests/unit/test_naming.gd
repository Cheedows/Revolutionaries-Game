extends TestCase
## Diffs the name generator against the original.
##
## This one matters beyond the names themselves: naming consumes randomness
## wherever a person is created, so a replay diverges without it.

const PROBE := "res://tests/golden/probes/names.jsonl.gz"


func test_names_match_the_original() -> void:
	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return

	for sample: Dictionary in samples:
		var gender := int(sample["gender"])
		var rng := Rng.new(int(sample["seed"]))

		if not _match(sample, "full", func(): return NamingRules.full_name(rng, gender)):
			return
		if not _match(sample, "first", func(): return NamingRules.first_name(rng, gender)):
			return
		if not _match(sample, "last", func():
				return NamingRules.last_name(rng, gender == Gender.WHITE_MALE_PATRIARCH)):
			return

		var expected_long: Array = sample["long"]
		for index in expected_long.size():
			var parts := NamingRules.long_name(rng, gender)
			var wanted: Array = expected_long[index]
			for part in 3:
				if parts[part] != TraceFile.recorded_name(wanted[part]):
					fail("sample %s long name %d part %d: expected %s, got %s"
							% [sample["sample"], index, part, wanted[part], parts[part]])
					return


func test_accented_names_survive_extraction() -> void:
	# The source file is a code page, not UTF-8, and seventy-odd of its four
	# thousand names carry high bytes. Read as Latin-1 they come out mojibake —
	# and they did, on the roster and in every line of news about the person,
	# because nothing here looked at what the characters actually were.
	var accented := 0
	for name: String in Names.MALE_FIRST:
		for unit in name.to_utf8_buffer():
			if unit > 127:
				accented += 1
				break
	check(accented > 0, "some first names carry accented characters")

	# Code page 437, where 0xA1 is an accented i. Latin-1 makes it "Dom¡nguez".
	check(Names.REGULAR_LAST.has("Domínguez"), "and they are the right ones")
	for name: String in Names.REGULAR_LAST:
		if name.contains("¡") or name.contains("£") or name.contains("\u0081"):
			fail("%s was decoded with the wrong code page" % name)
			return


func _match(sample: Dictionary, key: String, generate: Callable) -> bool:
	var expected: Array = sample[key]
	for index in expected.size():
		var actual: String = generate.call()
		if actual != TraceFile.recorded_name(expected[index]):
			fail("sample %s %s %d: expected %s, got %s"
					% [sample["sample"], key, index, expected[index], actual])
			return false
	return true
