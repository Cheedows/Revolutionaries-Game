extends TestCase
## Everything the simulation reports, the interface has to say.
##
## `core/` emits structured Events and never words; `EventText` turns them into
## the lines the log shows. An event type with no branch there falls through
## and returns "", so the simulation reports something and the player is never
## told — which is not a crash, a failing assertion or anything else that shows
## up on its own.
##
## So this plays the game, collects every kind of event it actually produced,
## and requires each to have words. Anything deliberately silent is listed
## below with the reason, and the list is the audit.

const SEEDS: Array[int] = [1, 777, 12345]
const DAYS := 400
const PATIENCE := 400

## What the player always says yes to, so the recruitment events happen.
const ALWAYS_TAKE: Array = [RecruitMeeting.OFFER_TO_JOIN]

## What the log deliberately keeps quiet about, and why. A kind of event that
## is only silent in some of its shapes is listed by the shape, so adding a new
## one is still caught.
const SILENT := {
	"game_started": "there is nothing to say about a game beginning",
	"day_advanced": "the date is already on screen",
	"headline_run": "the paper is a panel; the log would only repeat it",
	"news_published": "as above",
	"news_segment": "as above — the television is read in the paper panel",
	"opinion_shifted:0": "opinion did not move",
	"law_changed:held": "the law did not move and nothing said why",
	"major_event:crime_suspected": "the heat readout says this better",
	"major_event:moved_house": "their record says where they live",
	"major_event:crime_unprosecuted": "nothing was booked, so nothing happened",
}


func test_everything_the_day_reports_has_words() -> void:
	var silent := {}
	var seen := 0
	for seed_value in SEEDS:
		var session := Session.new(seed_value)
		Commands.start_new_game(session, PackedInt32Array(),
				{&"win_condition": &"elite_liberal",
				&"field_skill_rate": &"fast"})
		_gather(session, session.drain_events(), silent)

		for day in DAYS:
			var offered := Recruiting.recruitable(session.state)
			for creature: Creature in session.state.creatures.values():
				if creature.is_member() and creature.activity == &"none" \
						and creature.location != -1:
					Commands.recruit_for(session, creature,
							StringName(offered[0]["type"]))
			Commands.advance_day(session, false)
			var asked := 0
			while session.is_waiting() and asked < PATIENCE:
				asked += 1
				session.answer(_pick(session.pending().intent))
			if session.is_waiting():
				fail("seed %d day %d would not stop asking" % [seed_value, day])
				return
			seen += _gather(session, session.drain_events(), silent)

	check(seen > 100, "the run produced something to look at, got %d" % seen)
	var unexplained: Array[String] = []
	for shape: String in silent:
		if not SILENT.has(shape):
			unexplained.append(shape)
	unexplained.sort()
	check(unexplained.is_empty(),
			"the log says nothing about: %s" % ", ".join(unexplained))


## Describes each event and notes the ones that came out empty.
func _gather(session: Session, events: Array[Event],
		silent: Dictionary) -> int:
	for event in events:
		if EventText.describe(event, session.state).strip_edges().is_empty():
			silent[_shape(event)] = true
	return events.size()


## What to call one silent event: its type, and for the kinds that are only
## silent in some shapes, which shape.
func _shape(event: Event) -> String:
	match event.type:
		Event.MAJOR_EVENT:
			return "major_event:%s" % event.data.get("kind", "")
		Event.OPINION_SHIFTED:
			return "opinion_shifted:%d" % int(event.data.get("amount", 0))
		Event.LAW_CHANGED:
			if int(event.data.get("from", 0)) == int(event.data.get("to", 0)):
				return "law_changed:%s" % String(
						event.data.get("outcome", &"held"))
			return "law_changed"
	return String(event.type)


func _pick(intent: Intent) -> Variant:
	var chosen: Variant = null
	for option: Dictionary in intent.options:
		if not bool(option.get("enabled", true)):
			continue
		if chosen == null or ALWAYS_TAKE.has(option["id"]):
			chosen = option["id"]
	return chosen
