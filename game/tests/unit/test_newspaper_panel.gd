extends TestCase
## Prints every page the paper can print.
##
## The stories themselves are compared against the original word for word by
## the `newsprose` case; what this checks is the wiring between them and the
## page — that the panel hands each text function the story it was actually
## given. It exists because it did not: a major event's side was read off the
## printed page rather than off the event, so every Conservative story was
## drawn with the Liberal version's words and a missing slot took the whole
## paper down with it.

## Enough of a country for the clauses that turn on the law.
const YEAR := 2011


func test_every_major_event_prints_on_both_sides() -> void:
	var panel := NewspaperPanel.new()
	var printed := 0
	for view: StringName in Ids.VIEWS:
		for good in [true, false]:
			var table: Dictionary = MajorEventStory.GOOD if good \
					else MajorEventStory.BAD
			if not table.has(view):
				continue
			printed += 1
			if not _prints(panel, view, good):
				panel.free()
				return
	check(printed >= 30, "every written page was printed, got %d" % printed)
	panel.free()


## One page, built the way the paper builds it: the story is rolled by the
## simulation, wrapped in the event the simulation emits, and handed to the
## panel exactly as the safehouse screen hands it over.
func _prints(panel: NewspaperPanel, view: StringName, good: bool) -> bool:
	for seed_value in [1, 99, 4242]:
		var state := _country(seed_value)
		var rng := Rng.new(seed_value)
		var story := NewsStory.new()
		story.type = &"majorevent"
		story.view = view
		story.positive = 1 if good else 0

		var written := MajorEventStory.write(state, rng, story)
		if written.is_empty():
			fail("%s %s: the paper had no page for it"
					% [view, "good" if good else "bad"])
			return false
		var event := Event.new(Event.HEADLINE_RUN, {
			"story": story.type, "guardian": false, "view": view,
			"positive": good, "headline": written["headline"],
			"major": written, "advertisements": [],
		})
		var events: Array[Event] = [event]
		panel.show_paper(state, events)

		# A page that printed nothing means the panel dropped the story on the
		# floor, which is what a wiring mistake looks like from out here.
		var words := _words_on(panel)
		if words.strip_edges().is_empty():
			fail("%s %s: the page came out blank"
					% [view, "good" if good else "bad"])
			return false
		# And the words have to be the ones the story rolled, not the other
		# side's: a picture page says so, a written one carries its own text.
		if String(written["shape"]) == "story":
			var expected := MajorEventText.describe(state, view, good,
					written.get("slots", {}))
			if not expected.is_empty() \
					and not words.contains(expected.replace("&r", "\n")):
				fail("%s %s: the page is not the story that was rolled"
						% [view, "good" if good else "bad"])
				return false
	return true


func test_the_page_says_which_paper_it_is_and_which_page() -> void:
	var panel := NewspaperPanel.new()
	var state := _country(7)
	state.calendar.month = 3
	state.calendar.day = 14

	# A mainstream story on page four, and a Liberal Guardian story after it.
	var mainstream := Event.new(Event.NEWS_PUBLISHED, {
		"story": &"squad_site", "page": 4, "guardian": false,
		"guardian_page": 1, "slots": {}, "advertisements": [],
	})
	var guardian := Event.new(Event.NEWS_PUBLISHED, {
		"story": &"squad_site", "page": 9, "guardian": true,
		"guardian_page": 2, "slots": {}, "advertisements": [],
	})
	var events: Array[Event] = [mainstream, guardian]
	panel.show_paper(state, events)
	var words := _words_on(panel)

	# The masthead is the date, which is what the original prints across the
	# front page.
	check(words.contains(state.calendar.to_display()),
			"the paper is dated, got %s" % words.replace("\n", " / "))
	# The Guardian is named, because otherwise its story reads as though the
	# mainstream press had run it.
	check(words.contains("Liberal Guardian"),
			"and the Guardian's own story says so")
	# Page numbers are the paper in hand's, and bare — the original prints the
	# number in the corner and nothing else. Never the story's internal type.
	check(words.contains("4") and words.contains("2"),
			"and each story carries its own paper's page number")
	check(not words.contains("squad site") and not words.contains("squad_site"),
			"and the story's internal name is not printed at the player")
	panel.free()


func test_an_empty_paper_says_so() -> void:
	var panel := NewspaperPanel.new()
	var nothing: Array[Event] = []
	panel.show_paper(_country(3), nothing)
	var words := _words_on(panel)
	# Not "Unfortunately, nobody seems interested." — that is printnews() in
	# src/monthly/lcsmonthly.cpp talking about the readership of the squad's
	# own monthly newsletter, which is a different publication entirely.
	check(not words.contains("nobody seems interested"),
			"the monthly newsletter's line stays in the monthly newsletter")
	check(words.contains("Nothing in today's paper."),
			"and an empty paper says it is empty, got %s"
			% words.replace("\n", " / "))
	panel.free()


## Everything the panel put on the page, as one string.
func _words_on(panel: NewspaperPanel) -> String:
	var found := ""
	for child in _labels(panel):
		found += child.text + "\n"
	return found


func _labels(node: Node) -> Array[Label]:
	var found: Array[Label] = []
	for child in node.get_children():
		if child is Label:
			found.append(child)
		found.append_array(_labels(child))
	return found


func _country(seed_value: int) -> GameState:
	var state := GameState.new()
	state.calendar.year = YEAR
	var rng := Rng.new(seed_value)
	for index in state.law.values.size():
		state.law.values[index] = rng.below(5) - 2
	state.government.president_party = rng.below(2)
	return state
