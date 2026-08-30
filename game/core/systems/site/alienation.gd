class_name Alienation
extends RefCounted
## How the bystanders take what the squad just did.
##
## Ports alienationcheck() from src/sitemode/stealth.cpp. Anybody neutral who
## saw it turns Conservative; if a Liberal saw the squad hurt one of their own,
## everybody in the room does.

## Nobody is alienated during a siege — the people in the building already
## know whose side they are on.
const NO_ONE := 0
const THE_MASSES := 1
const EVERYONE := 2


## Runs the check after something the squad should not have done.
##
## [param mistake] is whether the squad hurt somebody on their own side, which
## is what turns a Liberal witness against them. Returns the events.
##
## The original picks witnesses one at a time at random and throws each away,
## which reads as though the choice matters — it does not, since it works
## through all of them either way. The rolls happen regardless, one per
## witness, so they are made here too.
static func check(state: GameState, rng: Rng, mistake: bool) -> Array[Event]:
	var events: Array[Event] = []
	var siege: Siege = state.sieges.get(state.site.location)
	if siege != null and siege.active:
		return events

	var witnesses: Array[Creature] = []
	for person: Creature in Encounters.living(state):
		# A prisoner is glad to see the place attacked, whatever it costs them.
		if person.name == "Prisoner":
			continue
		if person.alignment == &"moderate" \
				or (person.alignment == &"liberal" and mistake):
			witnesses.append(person)
	if witnesses.is_empty():
		return events

	var alienated := false
	var alienated_everyone := false
	while not witnesses.is_empty():
		var chosen: Creature = witnesses[rng.below(witnesses.size())]
		witnesses.erase(chosen)
		if chosen.alignment == &"liberal":
			alienated_everyone = true
		else:
			alienated = true

	var was := state.site.alienated
	if alienated_everyone:
		state.site.alienated = EVERYONE
	elif alienated and state.site.alienated != EVERYONE:
		state.site.alienated = THE_MASSES
	if state.site.alienated <= was:
		return events

	state.site.alarm = true
	for person: Creature in Encounters.all(state):
		if person.alignment == &"conservative":
			continue
		if person.alignment == &"moderate" or alienated_everyone:
			Alignment.conservatise(person)
	events.append(Event.new(Event.SITE_ALIENATED,
			{"level": state.site.alienated}))
	return events
