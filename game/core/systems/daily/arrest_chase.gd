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
	if not noticed(state, rng, liberal, doing, events):
		return null
	return attempt(state, rng, liberal, catalog)


## Whether the police pick [param liberal] out, and the story it opens.
##
## Being caught with nothing on is a public disturbance and charged as one;
## being recognised is not a charge, only a story.
static func noticed(state: GameState, rng: Rng, liberal: Creature,
		doing: StringName, events: Array[Event]) -> bool:
	if not ArrestRules.check(rng, liberal, doing, events):
		return false
	if String(events[events.size() - 1].data.get("charge", "")) == "disturbance":
		NewsQueue.open(state, &"nudityarrest")
		CrimeRules.charge(state, liberal, &"disturbance")
	else:
		NewsQueue.open(state, &"wantedarrest")
	return true


## The police are here. Raises the response and runs the chase.
##
## The squad is fictitious — one person, made for the chase and thrown away
## afterwards — which is what the original does so a lone Liberal can be
## chased without disturbing the real squads.
static func attempt(state: GameState, rng: Rng, liberal: Creature,
		catalog: Catalog, severity: int = SEVERITY,
		car: Vehicle = null, scrub: bool = true) -> Variant:
	alert(state, rng, liberal, severity, catalog, scrub)

	var squad := Squad.new()
	state.add_squad(squad)
	squad.member_ids.append(liberal.id)
	var was := liberal.squad_id
	liberal.squad_id = squad.id
	# A thief who got the car started is chased in it rather than on foot.
	liberal.vehicle_id = car.id if car != null else 0
	liberal.is_driver = car != null

	var here: Location = state.locations.get(liberal.location)
	var district := here.parent if here != null else -1
	var result: Variant = ChaseLoop.run(state, rng, squad, district,
			car != null, catalog)
	return _dissolve(state, squad, liberal, was, result)


## Calls the police out, before anybody starts running.
##
## Whatever brought them opened a story; if nothing did, the arrest itself is
## the story. **Original quirk, reproduced:** the story is written after the
## response is raised, so a story opened here cannot influence who turns up.
static func alert(state: GameState, rng: Rng, liberal: Creature,
		severity: int, catalog: Catalog, scrub: bool = true) -> void:
	# **Original quirk, reproduced.** makecreature() puts everybody it builds
	# at `cursite`, and an arrest on the street never sets it — so the police
	# are made at whatever building the squad was in last, which is what
	# decides where each of them works.
	if not scrub:
		state.chase.enemy_cars.clear()
		state.chase.friendly_cars.clear()
	var from: Location = state.locations.get(state.site.location)
	Chasers.raise(state, rng, &"", from, severity, catalog)
	NewsQueue.open_if_idle(state, &"wantedarrest")
	# **Original quirk, reproduced.** attemptarrest() wipes the chase sequence
	# *after* calling the police out, so the cars they came in are thrown away
	# and a street arrest is always run down on foot. The car thief's own two
	# chases wipe it first instead, and keep theirs — hence [param scrub].
	if scrub:
		state.chase.enemy_cars.clear()
		state.chase.friendly_cars.clear()


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
