extends TestCase
## Diffs the newspaper's filler against the original.
##
## It is only rows of tildes on the page, but it is the great majority of what
## the paper takes out of the random sequence — several draws per word, several
## hundred words per story — so every draw of it has to land in the same place.

const PROBE := "res://tests/golden/probes/filler.jsonl.gz"

## What the original writes between the paragraph mark and the first word.
const OPENING := "&r"
const PARAGRAPH := "&r  "


func test_the_filler_is_the_same_length() -> void:
	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return
	var chase: Object = (load("res://tests/unit/test_chase.gd") as GDScript).new()
	for sample: Dictionary in samples:
		var rng: Rng = chase._rng_at(sample)
		var where := "sample %s (%s words)" % [sample["sample"], sample["amount"]]
		var padding := StoryFiller.run(rng, int(sample["amount"]))
		if rng.draws != int(sample["draws"]):
			fail("%s: draws expected %s, got %d"
					% [where, sample["draws"], rng.draws])
			return
		if not _text_matches(where, padding, String(sample["text"])):
			return


## Rebuilds the original's own string from the word lengths and compares it.
##
## The original writes the word, then a space unless it was the last, then the
## paragraph mark if this was where the paragraph ended.
func _text_matches(where: String, padding: Dictionary,
		expected: String) -> bool:
	var words: PackedInt32Array = padding["words"]
	var total := 0
	for length in words:
		if length != 0:
			total += 1
	var written := ""
	var written_words := 0
	for length in words:
		if length == 0:
			written += PARAGRAPH
			continue
		written_words += 1
		written += "~".repeat(length)
		if written_words < total:
			written += " "
	written += OPENING
	var wanted := expected.substr(expected.find(" - ") + 3)
	# The original's sources are in a DOS codepage, so an accented city
	# survives the recording as one byte the probe could not encode. Only the
	# spelling differs; the choice is what is being compared.
	var wanted_city := expected.split(" - ")[0].trim_prefix(OPENING)
	var got_city := String(padding["city"])
	if _ascii(wanted_city) != _ascii(got_city):
		fail("%s: dateline expected %s, got %s"
				% [where, wanted_city, got_city])
		return false
	if written != wanted:
		fail("%s: filler differs\n  expected %s\n  got      %s"
				% [where, wanted, written])
		return false
	return true


## A name with everything the recording could not carry taken out of it.
func _ascii(text: String) -> String:
	var kept := ""
	for index in text.length():
		var letter := text[index]
		if letter.unicode_at(0) < 128:
			kept += letter
	return kept
