class_name EnemyRound
extends RefCounted
## The other side's half of a round of combat.
##
## Ports enemyattack() from src/combat/fight.cpp. Everybody on the roster acts
## in order: first deciding whether to run, then picking somebody to hit. Most
## of the function is the decision to run, because most people in a building
## are not there to fight.

## Blood below which anybody Conservative runs regardless of nerve, and the
## standing that stops them.
const PANIC_BLOOD := 45
const PANIC_JUICE := 200

## An unarmed bystander facing an armed squad runs unless they roll better
## than this window against their own injuries.
const NERVE_BASE := 70
const NERVE_SPREAD := 61

## Fire drives people out: a spreading fire counts double against this.
const FIRE_ODDS := 5
const FIRE_THRESHOLD := 3

## How often a shot at the squad hits the hostage they are dragging instead,
## and how often it hits a bystander.
const HOSTAGE_ODDS := 2
const BYSTANDER_ODDS := 10

## Turns of not listening to a cover story, set on anybody in a fight.
const CANNOT_BLUFF := 2

## How many ways the original has of saying somebody left. Only ever a phrase,
## but the choice is a draw.
const CRAWLING_LINES := 9
const RUNNING_LINES := 7

## What dropping a notable body adds to the story.
const NOTABLE_CRIME := 30


## One round of the other side attacking. Returns the events.
static func attack(state: GameState, rng: Rng, squad: Squad,
		context: Dictionary) -> Array[Event]:
	var events: Array[Event] = []
	var mode: StringName = context.get(&"mode", &"site")
	var armed := false
	for member: Creature in state.squad_members(squad):
		if member.is_armed():
			armed = true

	for person: Creature in Encounters.all(state):
		if not person.alive:
			continue
		# A bouncer in a building that has woken up stops being neutral.
		if state.site.alarm and person.type == &"CREATURE_BOUNCER" \
				and person.alignment != &"liberal":
			Alignment.conservatise(person)
		if Encounters.is_enemy(person):
			person.cannot_bluff = CANNOT_BLUFF

		if mode != &"chase_car" and _would_run(state, rng, person, armed, mode):
			# A tank or an animal has the impulse and no way to act on it.
			if person.animal_gloss == &"none":
				if not Incapacitation.check(rng, person):
					var crawling := _crawls(person)
					events.append(Event.new(Event.ENEMY_FLED, {
						"creature": person.id, "crawling": crawling,
						"manner": rng.below(CRAWLING_LINES if crawling
								else RUNNING_LINES),
					}))
					Encounters.remove(state, person)
				continue

		events.append_array(_swing(state, rng, squad, person, context))
	return events


## Whether [param person] would rather be somewhere else.
##
## Three ways out: not being here to fight — either not an enemy at all, or an
## unarmed Conservative with no standing who loses their nerve — having lost
## more than half their blood, or the room being on fire when putting fires out
## is not their job. Somebody the squad has won round stays regardless of the
## first.
##
## The conditions are written out one at a time rather than as one expression
## because two of them roll, and the original stops evaluating as soon as it
## has its answer: a bystander never rolls for nerve, and nobody already
## running rolls against the fire.
static func _would_run(state: GameState, rng: Rng, person: Creature,
		armed: bool, mode: StringName) -> bool:
	if not person.converted:
		if not Encounters.is_enemy(person):
			return true
		if person.juice == 0 and not person.is_armed() and armed \
				and person.body.blood < NERVE_BASE + rng.below(NERVE_SPREAD):
			return true
	if person.body.blood < PANIC_BLOOD and person.juice < PANIC_JUICE:
		return true

	var fire := _fire_at_squad(state) if mode == &"site" else 0
	return fire * rng.below(FIRE_ODDS) >= FIRE_THRESHOLD \
			and person.type != &"CREATURE_FIREFIGHTER"


## How badly the square the squad is standing on is alight: 0, 1 for a fire
## just caught or dying down, 2 for one at its height.
static func _fire_at_squad(state: GameState) -> int:
	if state.site.map == null:
		return 0
	var flags := state.site.map.get_flag(state.site.x, state.site.y, state.site.z)
	if (flags & (int(Tables.SITE_BLOCKS[&"fire_start"])
			| int(Tables.SITE_BLOCKS[&"fire_end"]))) != 0:
		return 1
	if (flags & int(Tables.SITE_BLOCKS[&"fire_peak"])) != 0:
		return 2
	return 0


## Whether they leave on their hands and knees rather than their feet.
static func _crawls(person: Creature) -> bool:
	return person.body.is_severed(&"leg_right") \
			or person.body.is_severed(&"leg_left") \
			or person.body.blood < PANIC_BLOOD


## One person's swing, including the two ways it can go astray.
static func _swing(state: GameState, rng: Rng, squad: Squad, person: Creature,
		context: Dictionary) -> Array[Event]:
	var events: Array[Event] = []
	var targets: Array[Creature] = []
	var bystanders: Array[Creature] = []

	if Encounters.is_enemy(person):
		for member: Creature in state.squad_members(squad):
			if member.alive:
				targets.append(member)
	else:
		# Somebody the squad brought round fights the Conservatives instead.
		for other: Creature in Encounters.living(state):
			if other.alignment == &"conservative":
				targets.append(other)
	for other: Creature in Encounters.living(state):
		if not Encounters.is_enemy(other):
			bystanders.append(other)
	if targets.is_empty():
		return events

	var target: Creature = targets[rng.below(targets.size())]

	# Nobody shoots wildly with somebody famous in the room, unless the room is
	# so full that there is nowhere for anybody to stand.
	var careful := Encounters.NOTABLE.has(person.type) \
			and not Encounters.is_full(state)
	if not careful:
		if Encounters.is_enemy(person) and target.prisoner_id != 0 \
				and rng.one_in(HOSTAGE_ODDS):
			return _hit_the_hostage(state, rng, target, person, context)
		if rng.one_in(BYSTANDER_ODDS) and not bystanders.is_empty():
			target = bystanders[rng.below(bystanders.size())]
			# Shooting somebody the squad converted is the shooter's own
			# mistake, not the squad's.
			var made := context.duplicate()
			made[&"mistake"] = not target.converted
			events.append_array(AttackRules.resolve(state, rng, person, target, made))
			if not target.alive:
				Encounters.remove(state, target, true)
			return events

	var made := context.duplicate()
	made[&"mistake"] = false
	events.append_array(AttackRules.resolve(state, rng, person, target, made))
	return events


## A shot meant for a Liberal that hits the person they are dragging.
static func _hit_the_hostage(state: GameState, rng: Rng, holder: Creature,
		shooter: Creature, context: Dictionary) -> Array[Event]:
	var events: Array[Event] = []
	var hostage: Creature = state.creatures.get(holder.prisoner_id)
	if hostage == null:
		return events
	var made := context.duplicate()
	made[&"mistake"] = true
	events.append_array(AttackRules.resolve(state, rng, shooter, hostage, made))

	if hostage.alive or hostage.squad_id != 0:
		return events
	# A dead hostage is dropped where they fall; a famous one is a far worse
	# thing to have done.
	events.append(Event.new(Event.BODY_DROPPED,
			{"creature": hostage.id, "holder": holder.id}))
	if Encounters.NOTABLE_DEAD.has(hostage.type):
		state.site.crime_level += NOTABLE_CRIME
	Encounters.make_loot(state, hostage)
	hostage.exists = false
	holder.prisoner_id = 0
	return events
