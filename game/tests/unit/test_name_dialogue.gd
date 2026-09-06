extends TestCase

func _person(state: GameState, name: String, alignment: StringName) -> Creature:
	var person := state.add_creature(Creature.new())
	person.name = name
	person.alignment = alignment
	return person


func test_names_are_distinct_coloured_spans_and_survive_history() -> void:
	var state := GameState.new()
	_person(state, "Ann", &"liberal")
	_person(state, "Anna", &"moderate")
	_person(state, "Robert [x]", &"conservative")
	var log := LogView.new()
	log.context = state
	log.append("Anna meets Ann and Robert [x].")
	var history := log.snapshot()
	var colours := {}
	for run: Dictionary in history[0].runs:
		colours[run.text] = run.colour
	equal(colours["Anna"], Palette.MODERATE, "neutral name is yellow")
	equal(colours["Ann"], Palette.LIBERAL, "shorter name is independently green")
	equal(colours["Robert [x]"], Palette.CONSERVATIVE, "literal brackets do not inject markup")
	var restored := LogView.new()
	restored.restore(history)
	equal(restored.snapshot(), history, "routing preserves every coloured span")
	log.free()
	restored.free()


func test_original_recruitment_exchange_and_back_and_forth_are_present() -> void:
	var state := GameState.new()
	var speaker := _person(state, "Alex", &"liberal")
	var listener := _person(state, "Morgan", &"moderate")
	var data := {"by": speaker.id, "creature": listener.id, "issue": &"abortion", "reply": 4}
	var said := SiteDialogueText.recruitment(Event.new(Event.RECRUIT_INTERESTED, data), state)
	check(said.contains("Do you want to hear something disturbing?"), "opening retained")
	check(said.contains('Morgan responds, "What?"'), "listener's opening reply retained")
	check(said.contains("control their own destinies"), "actual issue argument retained")
	check(said.contains('Morgan responds, "Oh, really?"'), "recorded reply retained")
	check(said.contains('Alex says, "Yeah, really!"'), "speaker answers the listener")
	check(said.contains("agrees to come by later tonight"), "meeting outcome retained")
	data.counterargument = true
	said = SiteDialogueText.recruitment(Event.new(Event.RECRUIT_REFUSED, data), state)
	check(said.contains('Morgan responds, "Abortion is murder." <turns away>'), "actual opposing response retained")


func test_every_flirting_line_keeps_its_matching_reply() -> void:
	var state := GameState.new()
	var speaker := _person(state, "Alex", &"liberal")
	var listener := _person(state, "Morgan", &"moderate")
	for censored in [false, true]:
		for accepted in [false, true]:
			var replies: Array = SiteDialogueTables.FLIRT_ACCEPT if accepted else SiteDialogueTables.FLIRT_REFUSE
			if censored:
				replies = SiteDialogueTables.FLIRT_ACCEPT_CENSORED if accepted else SiteDialogueTables.FLIRT_REFUSE_CENSORED
			for line in replies.size():
				var data := {"by": speaker.id, "creature": listener.id, "line": line, "censored": censored, "outcome": &"agreed" if accepted else &"refused"}
				var said := SiteDialogueText.flirting(state, data)
				check(said.contains("Morgan responds, " + replies[line]), "the original reply and gesture match the chosen line")


func test_rejected_people_are_disabled_and_cannot_start_a_conversation() -> void:
	var state := GameState.new()
	var person := _person(state, "Morgan", &"liberal")
	person.cannot_bluff = 1
	state.site.encounter_ids.append(person.id)
	var people := SitePeople.new()
	people.can_talk = true
	people.refresh(state)
	var row: OptionRow = people._list.get_child(0)
	check(row.disabled, "failed contact is visibly unavailable")
	check(not SiteConversation.available(state, person), "the core also rejects another approach")
	state.site.alarm = true
	check(SiteConversation.available(state, person), "original alarm exception is retained")
	person.animal_gloss = &"animal"
	check(not SiteConversation.available(state, person), "animals do not get the alarm exception")
	people.free()
