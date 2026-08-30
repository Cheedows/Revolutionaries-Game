class_name ArrestChase
extends RefCounted
## Police turning up while a Liberal is out on the street.
##
## Ports attemptarrest() and checkforarrest() from src/daily/activities.cpp. An
## arrest is not an arrest yet: it is a foot chase against whoever came, run
## with a squad of one.

## How bad the police think the offence is, which is what the response is
## scaled to.
const SEVERITY := 5


## Whether the police notice [param liberal], and the chase if they do.
##
## The noticing itself is [method ArrestRules.check]; what this adds is what
## the original does next, which is not a note in a file but a foot chase.
## Returns null when nothing happened.
static func check(state: GameState, rng: Rng, liberal: Creature,
		doing: StringName, catalog: Catalog,
		events: Array[Event]) -> Variant:
	if not ArrestRules.check(rng, liberal, doing, events):
		return null
	if String(events[events.size() - 1].data.get("charge", "")) == "disturbance":
		CrimeRules.charge(state, liberal, &"disturbance")
	return attempt(state, rng, liberal, catalog)


## The police are here. Raises the response and runs the chase.
##
## The squad is fictitious — one person, made for the chase and thrown away
## afterwards — which is what the original does so a lone Liberal can be
## chased without disturbing the real squads.
static func attempt(state: GameState, rng: Rng, liberal: Creature,
		catalog: Catalog) -> Variant:
	var here: Location = state.locations.get(liberal.location)
	Chasers.raise(state, rng, &"", here, SEVERITY, catalog)

	var squad := Squad.new()
	state.add_squad(squad)
	squad.member_ids.append(liberal.id)
	var was := liberal.squad_id
	liberal.squad_id = squad.id

	var district := here.parent if here != null else -1
	var result: Variant = ChaseLoop.run(state, rng, squad, district, false, catalog)
	return _dissolve(state, squad, liberal, was, result)


## Puts the Liberal back where they were and takes the temporary squad away.
##
## A chase can ask several questions, so this has to wrap every answer too.
static func _dissolve(state: GameState, squad: Squad, liberal: Creature,
		was: int, result: Variant) -> Variant:
	if result is PendingIntent:
		var asked: PendingIntent = result
		return PendingIntent.new(asked.intent,
				func(answer: Variant) -> Variant:
					return _dissolve(state, squad, liberal, was,
							asked.resume.call(answer)),
				asked.events)
	# Somebody who got away rejoins whatever they were part of; somebody who
	# was taken has already been moved, and stays where they are.
	if liberal.squad_id == squad.id:
		liberal.squad_id = was
	state.squads.erase(squad.id)
	return result
