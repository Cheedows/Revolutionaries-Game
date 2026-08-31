extends TestCase
## Diffs the world's own news against the original, word for word.
##
## `constructeventstory()` is a thousand lines of prose with a hundred draws
## threaded through it. The port splits the two: `core/` rolls and records, and
## `ui/adapters/` says. This runs both halves and compares the sentence the
## original printed, under every issue, both slants and six settings of the
## law — because half the clauses in these stories turn on what the country
## lets a newspaper print.

const PROBE := "res://tests/golden/probes/newsprose.jsonl.gz"


func test_the_stories_read_the_same() -> void:
	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return
	var chase: Object = (load("res://tests/unit/test_chase.gd") as GDScript).new()
	for sample: Dictionary in samples:
		var state := _world(sample)
		var rng: Rng = chase._rng_at(sample)
		var view: StringName = Ids.VIEWS[int(sample["view"])]
		var good := int(sample["positive"]) != 0
		var where := "%s %s (laws %s)" % [view, "good" if good else "bad",
				sample["shape"]]

		var slots := MajorEventStory.words(state, rng, view, good)
		if rng.draws != int(sample["draws"]):
			fail("%s: draws expected %s, got %d"
					% [where, sample["draws"], rng.draws])
			return
		var written := MajorEventText.describe(state, view, good, slots)
		if not _same(written, String(sample["text"])):
			fail("%s: story differs\n  expected %s\n  got      %s"
					% [where, _readable(String(sample["text"])),
							_readable(written)])
			return


## The original's sources are in a DOS codepage and its em dashes do not
## survive the recording, so both sides are compared with everything the
## recording could not carry taken out.
func _same(written: String, expected: String) -> bool:
	return _ascii(written) == _ascii(expected)


func _ascii(text: String) -> String:
	var kept := ""
	for index in text.length():
		if text[index].unicode_at(0) < 128:
			kept += text[index]
	return kept


## The first place the two differ, with a little either side of it.
func _readable(text: String) -> String:
	return _ascii(text)


func _world(sample: Dictionary) -> GameState:
	var state := GameState.new()
	state.calendar.year = int(sample["year"])
	state.government.president_party = int(sample["presparty"])
	var laws: Array = sample["law"]
	for index in laws.size():
		state.law.values[index] = int(laws[index])
	return state


func test_every_headline_has_words() -> void:
	var state := GameState.new()
	for id: StringName in HeadlineRules.FIXED.values():
		check(not HeadlineText.lines(state, id).is_empty(), "%s is set" % id)
	for id: StringName in HeadlineRules.BY_VIEW.values():
		check(not HeadlineText.lines(state, id).is_empty(), "%s is set" % id)
	for entry: Array in MajorEventStory.GOOD.values():
		check(not HeadlineText.lines(state, entry[0]).is_empty(),
				"%s is set" % entry[0])
	for entry: Array in MajorEventStory.BAD.values():
		check(not HeadlineText.lines(state, entry[0]).is_empty(),
				"%s is set" % entry[0])
	equal(HeadlineText.of(state, &"lcs_escapes_siege"),
			"LCS ESCAPES POLICE SIEGE", "and a two-line one reads in order")
	state.law.values[Ids.LAWS.find(&"freespeech")] = Law.ARCH_CONSERVATIVE
	equal(HeadlineText.of(state, &"bastards"), "[JERKS]",
			"the one headline the law rewrites")


func test_every_picture_story_has_a_caption() -> void:
	var state := GameState.new()
	state.calendar.month = 9
	for entry: Array in (MajorEventStory.GOOD.values()
			+ MajorEventStory.BAD.values()):
		if String(entry[1]) != "picture":
			continue
		check(MajorEventPageText.picture(entry[0]) != &"",
				"%s runs a picture" % entry[0])
		if entry[0] == &"bastards":
			continue
		check(MajorEventPageText.caption(state, entry[0], {}) != "",
				"%s has a line under it" % entry[0])
	equal(MajorEventPageText.caption(state, &"they_are_here", {}),
			"Fall fashions hit the stores across the country.",
			"and September is late enough for the autumn range")


func test_every_advertisement_and_broadcast_has_words() -> void:
	var rng := Rng.new(4242)
	var story := NewsStory.new()
	story.page = 50
	story.guardian_page = 6
	for guardian in [false, true]:
		for advertisement in NewsAds.run(rng, story, guardian, 2024):
			var lines := AdText.lines(advertisement)
			check(lines.size() > 0 and String(lines[0]) != "",
					"choice %s in %s has words"
							% [advertisement["choice"],
									"the Guardian" if guardian else "the paper"])
	for film: StringName in NewsBroadcast.FILMS.values():
		check(BroadcastText.lines({"film": film}).size() == 3,
				"%s has its three lines" % film)
	var segment := {"film": &"newscast"}
	segment.merge(NewsBroadcast._segment(rng))
	check(BroadcastText.title_card(segment).begins_with("Tonight on"),
			"and the cable news segment names its show")
	equal(BroadcastText.cast(segment).size(), 2, "with two people on screen")
