extends TestCase
## Diffs losing an argument against the original.
##
## The tail of specialattack(): what happens when a debate lands hard enough
## to change somebody's mind. Both directions — a Conservative talking one of
## the squad away, and the squad talking a Conservative round — against three
## grades of standing, three of heart, three of wisdom, an argument that fails
## and two that land, six special cases (an animal, a tank, somebody
## brainwashed, somebody kept by love, and an arguer on the same side), animal
## research banned or not, and a target holding a hostage or not.
##
## Compared on draw counts, which branch was taken, the target's side, their
## standing, heart and wisdom, whether they are still standing and still in the
## squad, whether they are marked as converted, their infiltration, who is left
## holding whom, and how many people are in the room and in the squad.

const PROBE := "res://tests/golden/probes/convert.jsonl.gz"

## What the probe reports for each branch.
const NOTHING_GETS_THROUGH := 1
const SAME_SIDE := 2
const UNCONVINCING := 3
const STANDING_HELD := 4
const LEARNED_WISDOM := 5
const KEPT_BY_LOVE := 6
const WALKED_AWAY := 7
const STANDING_HELD_LIBERAL := 8
const LEARNED_HEART := 9
const CAME_OVER := 10

var _catalog: Catalog


func test_losing_an_argument_goes_the_same_way() -> void:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()

	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return
	for sample: Dictionary in samples:
		if not _argument_matches(sample):
			return


func _argument_matches(sample: Dictionary) -> bool:
	var chase: Object = (load("res://tests/unit/test_chase.gd") as GDScript).new()
	var state := _world(sample)
	var rng: Rng = chase._rng_at(sample)
	var where := "scenario %s enemy=%s juice=%s heart=%s wisdom=%s margin=%s quirk=%s freed=%s holding=%s" \
			% [sample["scenario"], sample["enemy"], sample["juice"],
			sample["heart"], sample["wisdom"], sample["margin"],
			sample["quirk"], sample["freed"], sample["holding"]]

	var squad := Squad.new()
	squad.id = 1
	state.squads[squad.id] = squad
	state.active_squad_id = squad.id

	var target := _restore(state, chase, sample["target"])
	target.squad_id = squad.id
	squad.member_ids.append(target.id)
	var quirk := int(sample["quirk"])
	target.brainwashed = quirk == 3
	target.love_slave = quirk == 4
	var filler := found_squad(state, 860001)
	filler.squad_id = squad.id
	squad.member_ids.append(filler.id)

	if sample["held"] != null:
		var held := _restore(state, chase, sample["held"])
		held.squad_id = 0
		target.prisoner_id = held.id

	var arguer := _restore(state, chase, sample["arguer"])
	if int(sample["enemy"]) != 0:
		state.site.encounter_ids.append(arguer.id)
	else:
		arguer.squad_id = squad.id
		squad.member_ids.append(arguer.id)

	var events := SpecialAttack.settle(state, rng, arguer, target,
			int(sample["attack"]), int(sample["resist"]), _catalog)

	if rng.draws != int(sample["draws"]):
		return _diverged(where, "draws", sample["draws"], rng.draws)
	if Alignment.value_of(target.alignment) != int(sample["align"]):
		return _diverged(where, "whose side they are on", sample["align"],
				target.alignment)
	if target.juice != int(sample["juice_after"]):
		return _diverged(where, "standing", sample["juice_after"],
				target.juice)
	if target.attributes.get_value(&"heart") != int(sample["heart_after"]) \
			or target.attributes.get_value(&"wisdom") \
					!= int(sample["wisdom_after"]):
		return _diverged(where, "heart and wisdom",
				[sample["heart_after"], sample["wisdom_after"]],
				[target.attributes.get_value(&"heart"),
				target.attributes.get_value(&"wisdom")])
	if target.body.stunned != int(sample["stunned"]):
		return _diverged(where, "how long they are reeling", sample["stunned"],
				target.body.stunned)
	if target.alive != (int(sample["alive"]) != 0):
		return _diverged(where, "still standing", sample["alive"],
				target.alive)
	if target.location != int(sample["location"]):
		return _diverged(where, "where they are", sample["location"],
				target.location)
	if (target.squad_id != 0) != (int(sample["squadid"]) != -1):
		return _diverged(where, "still in the squad", sample["squadid"],
				target.squad_id)
	if target.converted != (int(sample["converted"]) != 0):
		return _diverged(where, "marked as converted", sample["converted"],
				target.converted)
	if target.cannot_bluff != int(sample["cantbluff"]):
		return _diverged(where, "whether they can be bluffed",
				sample["cantbluff"], target.cannot_bluff)
	if (target.prisoner_id != 0) != (int(sample["prisoner"]) != 0):
		return _diverged(where, "still holding somebody", sample["prisoner"],
				target.prisoner_id)
	if state.site.encounter_ids.size() != int(sample["encounters"]):
		return _diverged(where, "who is in the room", sample["encounters"],
				state.site.encounter_ids.size())
	if state.squad_members(squad).size() != int(sample["squadsize"]):
		return _diverged(where, "how big the squad is", sample["squadsize"],
				state.squad_members(squad).size())
	# The original casts to int, which truncates; matching that matters
	# because infiltration is compared against a d100 after being scaled.
	var infiltration := int(SinglePrecision.of(
			SinglePrecision.of(target.infiltration) * 1000000.0))
	if infiltration != int(sample["infiltration"]):
		return _diverged(where, "infiltration", sample["infiltration"],
				infiltration)

	# A defector leaves a copy of themselves standing on the other side. The
	# room's total is compared above; what matters here is that the copy is
	# the one that appears, on the arguer's side and unwilling to talk.
	if int(sample["outcome"]) == WALKED_AWAY:
		var copy_id := 0
		for event: Event in events:
			if event.type == Event.CREATURE_CONVERTED \
					and event.data.has("became"):
				copy_id = int(event.data["became"])
		if copy_id == 0:
			return _diverged(where, "the defection being reported", true,
					false)
		var copy: Creature = state.creatures.get(copy_id)
		if copy == null \
				or not Array(state.site.encounter_ids).has(copy_id):
			return _diverged(where, "the defector standing in the room",
					copy_id, Array(state.site.encounter_ids))
		if copy.alignment != &"conservative" or copy.cannot_bluff != 2:
			return _diverged(where, "which side the defector is on",
					["conservative", 2], [copy.alignment, copy.cannot_bluff])
	return true


func _restore(state: GameState, chase: Object, entry: Dictionary) -> Creature:
	var person: Creature = chase._person(state, {}, entry)
	state.creatures.erase(person.id)
	person.id = int(entry["id"])
	state.creatures[person.id] = person
	return person


func _diverged(where: String, field: String, expected: Variant,
		actual: Variant) -> bool:
	fail("%s: %s expected %s, got %s" % [where, field, expected, actual])
	return false


func _world(sample: Dictionary) -> GameState:
	var state := GameState.new()
	state.endgame_state = &"none"
	state.field_skill_rate = &"classic"
	state.mode = &"site"
	WorldBuilder.build(state, Rng.new(int(sample["world_seed"])), false)
	var laws: Array = sample["law"]
	for index in laws.size():
		state.law.values[index] = int(laws[index])

	var site: Location = state.locations.get(int(sample["site"]))
	state.site.location = site.id
	state.site.type = site.type
	state.site.alarm = false
	state.site.x = 3
	state.site.y = 3
	state.site.z = 0
	state.site.map = LevelMap.new()
	state.site.map.fill(0)
	return state
