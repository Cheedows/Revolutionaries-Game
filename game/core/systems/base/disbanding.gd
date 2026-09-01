class_name Disbanding
extends RefCounted
## Scattering the squad, and the years of being forgotten afterwards.
##
## Ports confirmdisband() from src/basemode/liberalagenda.cpp and the thinning
## in show_disbanding_screen() from src/basemode/basemode.cpp. Disbanding is
## not the end of the game: the squad goes into hiding, the player watches the
## country from a distance, and the shelter is always there to start again —
## but the longer it goes on, the fewer of them are still findable.

## The Liberal phrases the player has to type to confirm it. The list is
## presentation, but which one is asked for is a draw, so the choice is made
## here.
const PHRASES: Array[String] = [
	"Corporate Accountability", "Free Speech", "Gay Marriage",
	"Abortion Rights", "Separation Clause", "Racial Equality", "Gun Control",
	"Campaign Finance Reform", "Animal Rights", "Worker's Rights",
	"Police Responsibility", "Global Warming", "Immigration Reform",
	"Human Rights", "Woman's Suffrage", "Right To Privacy",
	"Medical Marijuana", "Flag Burning", "Life Imprisonment",
	"Conflict Resolution", "Radiation Poisoning", "Tax Bracket",
]

## Somebody in hiding for good, rather than for a stretch of days.
const INDEFINITELY := -1

## How fast the movement forgets: each year raises the standing somebody needs
## to still be worth finding by a hundred, up to a ceiling.
const FORGETTING_PER_YEAR := 100
const FORGETTING_CEILING := 1000

## After this long, there is nobody left to find at all.
const FORGOTTEN_AFTER := 50


## The phrase the player is asked to type. Costs the draw the original spends
## on picking it.
static func phrase(rng: Rng) -> String:
	return PHRASES[rng.below(PHRASES.size())]


## Scatters the squad. Hostages are simply gone; everybody else who is not a
## sleeper disappears into their own life.
static func disband(state: GameState) -> Array[Event]:
	var events: Array[Event] = []
	for creature: Creature in _ordered(state):
		if not creature.alive or creature.kidnapped or creature.missing:
			creature.exists = false
			continue
		if creature.sleeper:
			continue
		creature.squad_id = 0
		creature.hiding = INDEFINITELY
	clear_empty_squads(state)
	state.disbanded = true
	state.disband_year = state.calendar.year
	events.append(Event.new(Event.SQUAD_DISBANDED,
			{"year": state.calendar.year}))
	return events


## A month of being disbanded. Anybody the movement has forgotten — which is
## anybody without the standing to be remembered — is gone for good.
##
## Sleepers are exempt, and so is whoever founded the thing: the original tests
## for a recruiter, and the founder has none.
static func forget(state: GameState, rng: Rng) -> Array[Event]:
	var events: Array[Event] = []
	var forgotten := FORGETTING_PER_YEAR \
			* (state.calendar.year - state.disband_year + 1)
	for creature: Creature in _ordered(state):
		var threshold := mini(rng.below(forgotten), FORGETTING_CEILING)
		if creature.juice < threshold and creature.hire_id != -1 \
				and not creature.sleeper:
			Mortality.die(state, creature)
			events.append(Event.new(Event.CREATURE_LEFT,
					{"creature": creature.id, "reason": &"forgotten"}))
	return events


## Whether the disband has gone on so long that there is nothing to come back
## to.
static func is_forgotten(state: GameState) -> bool:
	return state.disbanded \
			and state.calendar.year - state.disband_year >= FORGOTTEN_AFTER


## Squads nobody is left in.
static func clear_empty_squads(state: GameState) -> void:
	for id: int in state.squads.keys():
		var squad: Squad = state.squads[id]
		var members := PackedInt32Array()
		for member_id in squad.member_ids:
			var member: Creature = state.creatures.get(member_id)
			if member != null and member.exists and member.alive \
					and member.squad_id == id:
				members.append(member_id)
		squad.member_ids = members
		if members.is_empty():
			state.squads.erase(id)


## The pool in the order the original walks it, which is backwards.
static func _ordered(state: GameState) -> Array[Creature]:
	var people: Array[Creature] = []
	for creature: Creature in state.creatures.values():
		if creature.exists and creature.is_member():
			people.append(creature)
	people.sort_custom(func(a: Creature, b: Creature) -> bool: return a.id > b.id)
	return people
