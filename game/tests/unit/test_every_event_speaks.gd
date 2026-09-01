extends TestCase
## Every kind of event the simulation can emit has words for it.
##
## The gameplay sweeps in `test_event_text` check what a run actually
## produces, which is the honest half: it only sees what it can reach. This is
## the other half. It reads `core/events.gd` for every event type there is,
## builds one of each out of the field list written beside it, and asks
## [EventText] to describe it.
##
## An event type with no branch anywhere in the adapters falls through and
## returns "", so the simulation reports something and the player is never
## told. That is not a crash and nothing else catches it.
##
## The fields are synthesized, so this cannot check that a line reads well —
## the gameplay sweeps and the adapters' own tests do that. What it checks is
## that a line exists at all.

## What is deliberately silent, and why. Anything else has to speak.
const SILENT := {
	"GAME_STARTED": "there is nothing to say about a game beginning",
	"DAY_ADVANCED": "the date is already on screen",
	"MONTH_ADVANCED": "said by its own branch, which needs no fields",
	"CREATURE_SPAWNED": "somebody arriving is the encounter's news, not theirs",
	"CREATURE_TRAINED": "practice is constant; the skill going up is the news",
	"CREATURE_JUICE_CHANGED": "standing is a number on the roster",
	"ACTIVITY_RESOLVED": "the assignment's own events say what came of it",
	"ATTACK_RESOLVED": "a marker the rules read, not a blow",
	"SQUAD_MOVED": "the floor plan shows where they are",
	"ITEM_EQUIPPED": "the kit list says what they are carrying",
	"WEAPON_RELOADED": "the kit list says what is loaded",
	"NEWS_PUBLISHED": "the paper is a panel; the log would only repeat it",
	"NEWS_SEGMENT": "as above — the television is read in the paper panel",
	"HEADLINE_RUN": "as above",
}

## How a field is filled, by name. A field the simulation documents as an index
## or a type is filled as one; everything else is guessed from what it is
## called, which is enough to reach the branch.
const IDS: Array[String] = [
	"creature", "target", "attacker", "victim", "recruit", "date", "by", "for",
	"holder", "held", "medic", "carrier", "keeper", "interrogator", "lead",
	"boss", "killer", "against", "recruiter", "replacing",
]
const PLACES: Array[String] = [
	"location", "site", "base", "vehicle", "squad", "x", "y", "z", "seat",
]
const FLAGS: Array[String] = [
	"found", "fatal", "friendly", "escaped", "good", "guardian", "warmly",
	"politely", "trapped", "crawling", "sneak", "positive", "forced",
	"pickable", "stood_up", "informed", "mapped", "caught", "bystander",
	"close", "wasteful", "won", "tortured", "overdose", "executed", "death",
	"ready", "quiet", "held_up", "worked", "badge", "metal_detector", "fooled",
	"won_over", "from_base", "up", "mural", "wasted", "television",
	"president", "machine", "wing", "square", "threatened", "founder",
	"hiding", "tampered",
]

## A field with a name this does not know is filled with a word, which is what
## most of them are.
const SOMETHING := &"something"


func test_every_event_has_words() -> void:
	var state := _a_world()
	var mute: Array[String] = []
	var counted := 0
	for line in FileAccess.get_file_as_string(
			"res://core/events.gd").split("\n"):
		var declared := _declaration(line)
		if declared.is_empty():
			continue
		counted += 1
		var event := Event.new(StringName(declared["id"]),
				_fields(state, String(declared["fields"])))
		if not EventText.describe(event, state).strip_edges().is_empty():
			continue
		if SILENT.has(declared["name"]):
			continue
		mute.append(String(declared["name"]))

	check(counted > 200, "every event was tried, got %d" % counted)
	mute.sort()
	check(mute.is_empty(),
			"nothing is said about: %s" % ", ".join(mute))


## And every question the simulation can ask has words too.
##
## An Intent with no question falls back on its own id with the underscores
## taken out, which is a debugging string rather than something to read.
func test_every_intent_has_a_question() -> void:
	var mute: Array[String] = []
	var counted := 0
	var text := FileAccess.get_file_as_string(
			"res://ui/adapters/intent_text.gd")
	var pattern := RegEx.new()
	pattern.compile('^const ([A-Z_0-9]+) := &"[a-z_0-9]+"')
	for line in FileAccess.get_file_as_string(
			"res://core/intents.gd").split("\n"):
		var found := pattern.search(line)
		if found == null:
			continue
		counted += 1
		if not text.contains("Intent.%s" % found.get_string(1)):
			mute.append(found.get_string(1))

	check(counted > 25, "every intent was tried, got %d" % counted)
	mute.sort()
	check(mute.is_empty(),
			"nothing is asked for: %s" % ", ".join(mute))


## The name, id and documented fields of one declaration, or {}.
func _declaration(line: String) -> Dictionary:
	var pattern := RegEx.new()
	pattern.compile('^const ([A-Z_0-9]+) := &"([a-z_0-9]+)"' \
			+ '\\s*(?:#\\s*\\{([^}]*)\\})?')
	var found := pattern.search(line)
	if found == null:
		return {}
	return {"name": found.get_string(1), "id": found.get_string(2),
			"fields": found.get_string(3)}


## One of every field the declaration names, filled with something of the
## right shape.
func _fields(state: GameState, documented: String) -> Dictionary:
	var data := {}
	for entry in documented.split(","):
		var raw := entry.strip_edges()
		if raw == "" or raw == "...":
			continue
		var parts := raw.split(":")
		var key := parts[0].strip_edges()
		var hint := parts[1].strip_edges() if parts.size() > 1 else ""
		if hint == "index" or hint == "count":
			data[key] = 1
		elif hint == "type":
			data[key] = &"CREATURE_COP"
		elif IDS.has(key):
			data[key] = 2
		elif PLACES.has(key):
			data[key] = 1
		elif FLAGS.has(key):
			data[key] = true
		elif key == "candidates":
			data[key] = PackedInt32Array([2])
		elif key.ends_with("s") or key in ["amount", "power", "level",
				"manner", "way", "stunt", "effect", "day", "from", "to",
				"page", "rent", "price", "paid", "quality", "sentence",
				"jury", "defense", "escalation", "freed", "joined", "team",
				"proximity", "survey", "approval", "concern", "cost",
				"difficulty", "count", "fact", "reaction"]:
			data[key] = 1
		else:
			data[key] = SOMETHING
	return data


## Two people and a place, so the lines have something to name.
func _a_world() -> GameState:
	var state := GameState.new()
	state.slogan = "A slogan"
	var ada := state.add_creature(Creature.new())
	ada.name = "Ada"
	ada.alignment = &"liberal"
	var bo := state.add_creature(Creature.new())
	bo.name = "Bo"
	bo.alignment = &"conservative"
	var place := Location.new()
	place.id = 1
	place.name = "The Juice Bar"
	place.type = &"business_juicebar"
	state.locations[1] = place
	return state
