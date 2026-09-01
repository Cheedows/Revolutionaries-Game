extends TestCase
## Holds the combat event vocabulary to being complete.
##
## The check is not a list — a list drifts the moment somebody adds an event.
## It walks core/systems/combat/ and core/systems/chase/ for every `Event.X`
## they emit, and insists that [CombatText] has something to say about each.
## Anything a picture of a fight would need has to be in the event for that to
## be possible, which is what makes this a test of the vocabulary rather than
## of the wording.

const COMBAT_DIRS: Array[String] = [
	"res://core/systems/combat", "res://core/systems/chase",
]

## Events that carry no line by design: the resolution marker exists so a
## caller can tell a real swing from a refusal, and the blow itself has already
## been described by the time it arrives.
const SILENT: Array[StringName] = [&"attack_resolved"]


func test_every_combat_event_can_be_said() -> void:
	var state := _room()
	var constants: Dictionary = (load("res://core/events.gd") as GDScript) \
			.get_script_constant_map()
	var missing: Array[String] = []
	for name in _emitted():
		if not constants.has(name):
			continue
		var type: StringName = constants[name]
		if SILENT.has(type):
			continue
		var line := CombatText.describe(_sample(type), state)
		if line.strip_edges() == "":
			missing.append(name)
	check(missing.is_empty(),
			"nothing to say about: %s" % ", ".join(missing))


func test_a_blow_reads_the_way_it_landed() -> void:
	var state := _room()
	var shot := Event.new(Event.ATTACK_HIT, {
		"attacker": 1, "target": 2, "part": &"leg_left", "damage": 12,
		"wound": Wound.SHOT | Wound.BLEEDING,
	})
	equal(CombatText.describe(shot, state), "Ada shoots Bo in the left leg.",
			"a bullet in the leg")

	shot.data["wound"] = Wound.SHOT | Wound.CLEAN_OFF
	equal(CombatText.describe(shot, state), "Ada takes Bo in the left leg.",
			"and one that takes the leg with it")

	var stopped := Event.new(Event.ATTACK_HIT, {
		"attacker": 1, "target": 2, "part": &"head", "damage": 0,
		"stopped_by": &"window", "bounced": true,
	})
	equal(CombatText.describe(stopped, state),
			"The shot bounces off the window.", "and one the car turned away")

	stopped.data["bounced"] = false
	equal(CombatText.describe(stopped, state),
			"The shot comes through the window and stops on Bo.",
			"and one the car only slowed")

	var through := Event.new(Event.ATTACK_HIT, {
		"attacker": 1, "target": 2, "part": &"body", "damage": 9,
		"wound": Wound.SHOT, "through": &"body",
	})
	equal(CombatText.describe(through, state),
			"Ada shoots Bo in the chest through the bodywork.",
			"and one that came through the door first")


func test_a_chase_reads() -> void:
	var state := _room()
	# Every line here is src/combat/chase.cpp's. The simulation rolls which
	# one and carries the index; the adapter says it rather than summarising
	# what it meant.
	equal(ChaseText.describe(Event.new(Event.CHASE_CAR_CRASHED,
			{"friendly": true, "manner": 0}), state),
			"Your car slams into a building!",
			"the squad's own crash is the original's exclamation")
	equal(ChaseText.describe(Event.new(Event.CHASE_CAR_CRASHED,
			{"friendly": false, "manner": 2, "victims": 2}), state),
			"The car hits a parked car and flips over.",
			"and theirs is the same crash said flatter")
	equal(ChaseText.describe(Event.new(Event.CHASE_CAR_CRASHED,
			{"friendly": false, "manner": 1, "victims": 2}), state),
			"The car spins out and crashes."
			+ " Everyone inside is peeled off against the pavement.",
			"and only a spin-out says what became of the people in it")
	equal(ChaseText.describe(Event.new(Event.CHASE_PRISONER_KILLED,
			{"creature": 2, "manner": 1}), state),
			"Bo's lifeless body smashes through the windshield.",
			"and how somebody in it died is its own table")
	equal(ChaseText.describe(Event.new(Event.CHASE_CAUGHT,
			{"creature": 2, "by": &"CREATURE_DEATHSQUAD", "fatal": true}),
			state),
			"Bo is seized, thrown to the ground, and shot in the head!",
			"a death squad does not arrest anybody")
	equal(ChaseText.describe(Event.new(Event.CHASE_CAUGHT,
			{"creature": 2, "by": &"CREATURE_COP", "fatal": false,
			"tazed": false}), state),
			"Bo is seized, pushed to the ground, and handcuffed!",
			"and a Liberal police force only arrests them")
	equal(ChaseText.describe(Event.new(Event.CHASE_DODGED,
			{"manner": 3, "bold": false}), state),
			"You make obscene gestures at the pursuers!",
			"a squad only just holding on jeers instead of weaving")
	equal(ChaseText.describe(Event.new(Event.CHASE_DODGED,
			{"manner": 3, "bold": true}), state),
			"You boldly weave through oncoming traffic!",
			"and one that is winning weaves")
	equal(ChaseText.describe(Event.new(Event.CHASE_ENDED, {"escaped": true}),
			state), "It looks like you've lost them!",
			"and a chase ends either way")


## Two people with names, so the lines read as lines.
func _room() -> GameState:
	var state := GameState.new()
	var ada := state.add_creature(Creature.new())
	ada.name = "Ada"
	var bo := state.add_creature(Creature.new())
	bo.name = "Bo"
	return state


## An event of [param type] with every field the adapters look at, so a
## missing line is a missing line rather than a missing field.
func _sample(type: StringName) -> Event:
	return Event.new(type, {
		"creature": 2, "attacker": 1, "target": 2, "carrier": 1, "holder": 1,
		"medic": 1, "by": &"CREATURE_COP", "for": 2, "weapon": &"WEAPON_KNIFE",
		"part": &"head", "damage": 5, "wound": Wound.CUT, "organ": &"liver",
		"kind": &"argues_with", "manner": 1, "obstacle": &"crowd",
		"victims": 2, "friendly": true, "escaped": false, "turns": 2,
		"amount": 3, "crawling": false, "trapped": true, "fatal": true,
		"sneak": false, "vehicle": 1, "base": 1, "cause": &"wounds",
	})


## Every `Event.X` the combat and chase systems mention.
func _emitted() -> Array[String]:
	var found: Array[String] = []
	for directory in COMBAT_DIRS:
		for file in DirAccess.get_files_at(directory):
			if not file.ends_with(".gd"):
				continue
			var source := FileAccess.get_file_as_string("%s/%s" % [directory, file])
			for name in _mentions(source):
				if not found.has(name):
					found.append(name)
	check(found.size() > 20, "found the events, got %d" % found.size())
	return found


## The names after `Event.` in [param source], skipping the constructor.
func _mentions(source: String) -> Array[String]:
	var names: Array[String] = []
	var expression := RegEx.new()
	expression.compile("Event\\.([A-Z][A-Z_0-9]*)")
	for match in expression.search_all(source):
		var name := match.get_string(1)
		if not names.has(name):
			names.append(name)
	return names
