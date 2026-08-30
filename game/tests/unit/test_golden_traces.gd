extends TestCase
## Checks the golden traces are readable and that the ported RNG tracks the
## original through real gameplay.
##
## The second test is the load-bearing one: it replays the exact number of draws
## the C++ made up to a decision point and asserts the generator state matches
## word for word. If that holds across a four-month playthrough, every system
## ported afterwards can be diffed against these traces meaningfully.

const EXPECTED_TRACES := 6


func test_traces_are_readable() -> void:
	var traces := TraceFile.list_traces()
	equal(traces.size(), EXPECTED_TRACES,
			"recorded trace count — re-run tools/trace_harness/record_all.sh")
	for trace: Dictionary in traces:
		var records := TraceFile.load_records(trace.path)
		if records.is_empty():
			fail("%s decoded to nothing" % trace.path)
			return
		for i in records.size():
			var record: Dictionary = records[i]
			equal(record["frame"], i, "%s frame numbering" % trace.path)
			if not record.has("state") or not record.has("draws"):
				fail("%s frame %d is missing state or draws" % [trace.path, i])
				return


func test_rng_tracks_the_original_through_a_playthrough() -> void:
	var compared := 0
	for trace: Dictionary in TraceFile.list_traces():
		var records := TraceFile.load_records(trace.path)
		if records.is_empty():
			fail("%s decoded to nothing" % trace.path)
			return

		var rng := Rng.new(trace.seed)
		for i in range(1, records.size()):
			var previous: Dictionary = records[i - 1]
			var current: Dictionary = records[i]
			# The original keeps side streams (per-location map seeds, an
			# attorney seed) and splices them into the main generator with
			# copyRNG. A frame that did that is not a continuous draw
			# sequence, so it is not comparable this way — the port will have
			# to model the splice itself when those systems are ported.
			if int(current["swaps"]) != 0:
				continue

			rng.set_state(_words(previous["state"]["rng"]))
			for draw in int(current["draws"]):
				rng.next()

			var expected := _words(current["state"]["rng"])
			var actual := rng.get_state()
			for word in 4:
				if actual[word] != expected[word]:
					fail("%s frame %d: RNG word %d diverged over %d draws (expected %d, got %d)"
							% [trace.path, current["frame"], word, int(current["draws"]),
									expected[word], actual[word]])
					return
			compared += 1

	check(compared > 1000, "compared %d frame transitions, expected over 1000" % compared)


func _words(recorded: Array) -> PackedInt64Array:
	var words := PackedInt64Array()
	for value in recorded:
		words.append(TraceFile.to_unsigned(value))
	return words
