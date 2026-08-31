class_name AnimalTalk
extends RefCounted
## Talking to the dog, and to whatever is in the tank.
##
## Ports heyMisterDog() and heyMisterMonster() from src/sitemode/talk.cpp.
## Neither is a negotiation: whoever in the squad has the biggest heart does
## the talking, and if that is big enough the animal comes over. Nothing else
## about the squad matters, and the animal gets no say.

## The heart it takes to be understood by something that does not speak.
const KINDNESS := 15

## How many things there are to say, either way.
const LINES := 11


## Somebody talks to the guard dogs. Returns the events.
static func to_dog(state: GameState, rng: Rng, squad: Squad,
		listener: Creature) -> Array[Event]:
	return _speak(state, rng, squad, listener, &"CREATURE_GUARDDOG")


## Somebody talks to whatever came out of the laboratory.
static func to_monster(state: GameState, rng: Rng, squad: Squad,
		listener: Creature) -> Array[Event]:
	return _speak(state, rng, squad, listener, &"CREATURE_GENETIC")


## **Original quirk, reproduced.** The kindest Liberal is found by comparing
## everybody against whoever is in the first slot, alive or not — a corpse with
## a large heart still does the talking, and a squad whose first slot is empty
## crashes the original outright. Here an empty squad simply says nothing.
##
## The animal that is won over is not the one spoken to but every animal of its
## kind in the room, which is how one kind word frees a whole kennel.
static func _speak(state: GameState, rng: Rng, squad: Squad,
		listener: Creature, kind: StringName) -> Array[Event]:
	var events: Array[Event] = []
	var members := state.squad_members(squad)
	if members.is_empty():
		return events

	var kindest := members[0]
	for member: Creature in members:
		if AttributeRules.effective(member, &"heart", true) \
				> AttributeRules.effective(kindest, &"heart", true):
			kindest = member

	var understood := AttributeRules.effective(kindest, &"heart", true) \
			>= KINDNESS
	if not understood:
		listener.cannot_bluff = 1
	# Which of the eleven things is said, either way.
	rng.below(LINES)

	if understood:
		for id in state.site.encounter_ids:
			var beast: Creature = state.creatures.get(id)
			if beast != null and beast.type == kind:
				beast.alignment = &"liberal"
	events.append(Event.new(Event.ANIMAL_ADDRESSED, {
		"creature": listener.id, "by": kindest.id, "won_over": understood,
	}))
	return events
