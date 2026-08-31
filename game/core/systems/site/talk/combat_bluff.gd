class_name CombatBluff
extends RefCounted
## Claiming to belong here.
##
## Ports the bluffing branch of talkInCombat() in src/sitemode/talk.cpp. What
## the Liberal says depends on what they are wearing and, under siege, on who
## is outside; the words are the UI's, but one of them can set the building on
## fire, so that stays here.

## How hard the story is to swallow, by how much sense the listener has.
const SHARP_WISDOM := 10

## One time in ten, a Liberal in fire gear waved through a fire crew's siege
## starts the fire they were supposed to be putting out.
const ARSON_ODDS := 10

## What an attempt teaches, by training rate.
const LESSON: Dictionary = {
	&"fast": 50, &"classic": 20, &"hard": 0,
}

## What a near miss teaches on the hard rate, where nothing else does.
const NEAR_MISS_LESSON := 20


## Tries the story on everybody in the room. Returns the events.
##
## Everybody is checked in turn and the first one who does not believe it ends
## the attempt — so a room of fools is only as convincing as its sharpest
## member, and one that empties out is fooled entirely.
static func attempt(state: GameState, rng: Rng, speaker: Creature,
		catalog: Catalog) -> Array[Event]:
	var events: Array[Event] = []
	var siege: Siege = state.sieges.get(state.site.location)
	if siege != null and siege.active:
		if siege.attacker == &"firemen":
			_maybe_arson(state, rng)

	var fooled := true
	var context := {&"disguise": Disguise.rating(state, speaker, catalog),
			&"catalog": catalog}
	var doubter: Creature = null
	for id in Array(state.site.encounter_ids):
		var person: Creature = state.creatures.get(id)
		if person == null or not person.alive \
				or not Encounters.is_enemy(person):
			continue
		var roll := CheckRules.skill_roll(rng, speaker, &"disguise", context)
		var needed := Difficulty.CHALLENGING \
				if AttributeRules.effective(person, &"wisdom", true) \
						> SHARP_WISDOM else Difficulty.AVERAGE
		fooled = roll >= needed
		if roll + 1 == needed and state.field_skill_rate == &"hard":
			TrainRules.train(speaker, &"disguise", NEAR_MISS_LESSON)
		if not fooled:
			doubter = person
			break

	TrainRules.train(speaker, &"disguise",
			int(LESSON.get(state.field_skill_rate, 0)))

	events.append(Event.new(Event.BLUFF_TRIED, {
		"creature": speaker.id, "fooled": fooled,
		"doubter": doubter.id if doubter != null else 0,
	}))
	if not fooled:
		return events

	# The room decides it has better things to do. The original walks the
	# roster backwards here, which is why nobody is missed.
	var roster := Array(state.site.encounter_ids)
	roster.reverse()
	for id in roster:
		var person: Creature = state.creatures.get(id)
		if person != null and person.alive and Encounters.is_enemy(person):
			Encounters.remove(state, person)
	return events


## A fire crew's own gear, worn past their cordon, occasionally does what the
## fire crew came to stop.
##
## **Original defect, reproduced.** The condition is a chain of ORs over four
## flags, so a square missing *any* one of them qualifies — which is every
## square that is not already burnt out and buried, rather than only the ones
## that are untouched.
static func _maybe_arson(state: GameState, rng: Rng) -> void:
	var map := state.site.map
	var flag := map.get_flag(state.site.x, state.site.y, state.site.z)
	var burnt := int(Tables.SITE_BLOCKS[&"fire_end"])
	var peak := int(Tables.SITE_BLOCKS[&"fire_peak"])
	var lit := int(Tables.SITE_BLOCKS[&"fire_start"])
	var debris := int(Tables.SITE_BLOCKS[&"debris"])
	var room := flag & burnt == 0 or flag & peak == 0 or flag & lit == 0 \
			or flag & debris == 0
	if room and rng.one_in(ARSON_ODDS):
		map.set_flag(state.site.x, state.site.y, state.site.z, flag | lit)
