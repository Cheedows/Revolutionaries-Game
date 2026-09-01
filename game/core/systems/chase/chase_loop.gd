class_name ChaseLoop
extends RefCounted
## Running a chase from start to finish, a round at a time.
##
## Ports the loop bodies of chasesequence() and footchase() from
## src/combat/chase.cpp: what the player is offered each round, and what each
## answer does. The original blocks on a keystroke here; this hands back a
## question and resumes with the answer.

## What the squad can do with a round.
const RUN_FOR_IT := &"run"
const FIGHT := &"fight"
const BAIL_OUT := &"bail"
const GIVE_UP := &"give_up"
const SWERVE := &"swerve"
const PLOW_ON := &"plow"


## Starts a chase and runs it to its end. Returns events or a [PendingIntent].
##
## [param in_cars] is a car chase rather than a foot chase. The chase is over
## when nobody is left following, when the squad is wiped out, or when they
## surrender.
static func run(state: GameState, rng: Rng, squad: Squad, location: int,
		in_cars: bool, catalog: Catalog) -> Variant:
	var opened: Dictionary = ChaseTurn.begin(state, squad, location, in_cars)
	if bool(opened["over"]):
		ChaseTurn.dismiss_chasers(state)
		state.chase.clear()
		return opened["events"] as Array[Event]
	return _round(state, rng, squad, catalog, opened["events"] as Array[Event])


## Asks what the squad does about this round.
static func _round(state: GameState, rng: Rng, squad: Squad, catalog: Catalog,
		events: Array[Event]) -> Variant:
	if _finished(state, squad):
		return events + _ending(state, rng, squad)

	var obstacle: StringName = Ids.CHASE_OBSTACLES[state.chase.obstacle] \
			if state.chase.obstacle != -1 else &""
	return PendingIntent.new(
			Intent.new(Intent.CHOOSE_CHASE_ACTION, _actions(state, obstacle), {
				"in_cars": ChaseTurn.in_cars(state),
				"obstacle": obstacle,
				"can_pull_over": state.chase.can_pull_over,
				"chasers": state.site.encounter_ids.size(),
			}),
			func(choice: StringName) -> Variant:
				return _act(state, rng, squad, catalog, choice, events),
			events)


## What the squad can do about this round.
##
## An obstacle in the road replaces the usual choice with the two ways past it,
## which is how the original draws it: swerve, or keep going.
static func _actions(state: GameState, obstacle: StringName) -> Array[Dictionary]:
	if obstacle != &"":
		return [
			{"id": SWERVE, "label": "Swerve!", "enabled": true},
			{"id": PLOW_ON, "label": "Keep going!", "enabled": true},
		]
	var options: Array[Dictionary] = [
		{"id": RUN_FOR_IT, "label": "Try to lose them!", "enabled": true},
		{"id": FIGHT, "label": "Fight!", "enabled": true},
	]
	if ChaseTurn.in_cars(state):
		options.append({"id": BAIL_OUT, "label": "Bail out and run!",
				"enabled": true})
	options.append({"id": GIVE_UP, "label": "Pull over",
			"enabled": state.chase.can_pull_over})
	return options


## Carries out the squad's choice, then comes back for the next round.
static func _act(state: GameState, rng: Rng, squad: Squad, catalog: Catalog,
		choice: StringName, events: Array[Event]) -> Variant:
	var so_far: Array[Event] = []

	if state.chase.obstacle != -1:
		var met: Dictionary = ChaseTurn.take_obstacle(state, rng, squad,
				choice == SWERVE, catalog)
		so_far.append_array(met["events"] as Array[Event])
		if bool(met["over"]):
			return events + so_far + ChaseTurn.wipe_out(state, squad)
		if bool(met["fight"]):
			so_far.append_array(_exchange(state, rng, squad, catalog))
		so_far.append_array(_advance(state, rng, squad, catalog))
		return _round(state, rng, squad, catalog, events + so_far)

	match choice:
		GIVE_UP:
			if state.chase.can_pull_over:
				return events + ChaseTurn.give_up(state, squad, catalog)
			return _round(state, rng, squad, catalog, events)
		BAIL_OUT:
			ChaseTurn.bail_out(state, squad)
			return _round(state, rng, squad, catalog, events)
		FIGHT:
			so_far.append_array(_exchange(state, rng, squad, catalog))
		_:
			so_far.append_array(ChaseTurn.evade(state, rng, squad, catalog))
			# Running for it does not stop the other side shooting back.
			so_far.append_array(EnemyRound.attack(state, rng, squad,
					_context(state, squad, catalog)))

	so_far.append_array(_advance(state, rng, squad, catalog))
	return _round(state, rng, squad, catalog, events + so_far)


## A round of shooting. The squad goes first when it chose to fight.
static func _exchange(state: GameState, rng: Rng, squad: Squad,
		catalog: Catalog) -> Array[Event]:
	var context := _context(state, squad, catalog)
	var events := SquadRound.attack(state, rng, squad, context)
	events.append_array(EnemyRound.attack(state, rng, squad, context))
	return events


static func _advance(state: GameState, rng: Rng, squad: Squad,
		catalog: Catalog) -> Array[Event]:
	var events := CombatAdvance.everyone(state, rng, squad,
			_context(state, squad, catalog))
	if ChaseTurn.in_cars(state):
		var driving: Dictionary = Driving.update(state, rng, squad, catalog)
		events.append_array(driving["events"] as Array[Event])
		# A squad that lost its car carries on running.
		if bool(driving["over"]):
			ChaseTurn.bail_out(state, squad)
	return events


## Whether there is anything left to decide.
static func _finished(state: GameState, squad: Squad) -> bool:
	return _alive(state, squad) == 0 or ChaseTurn.has_escaped(state, squad)


## How the chase ended.
static func _ending(state: GameState, rng: Rng, squad: Squad) -> Array[Event]:
	if _alive(state, squad) == 0:
		return ChaseTurn.wipe_out(state, squad)
	return ChaseTurn.escape(state)


static func _alive(state: GameState, squad: Squad) -> int:
	var standing := 0
	for member: Creature in state.squad_members(squad):
		if member.alive:
			standing += 1
	return standing


static func _context(state: GameState, squad: Squad,
		catalog: Catalog) -> Dictionary:
	return {
		&"catalog": catalog, &"squad": squad,
		&"mode": &"chase_car" if ChaseTurn.in_cars(state) else &"chase_foot",
	}
