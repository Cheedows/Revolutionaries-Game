class_name BlendingIn
extends RefCounted
## Getting through a building without anybody deciding to do something about it.
##
## Ports disguisecheck() from src/sitemode/stealth.cpp: once per turn, one
## Conservative at a time looks the squad over. The squad first tries not to be
## seen at all, and once seen tries to look like it belongs.

## Lessons in the field, by training rate: sneaking successfully, and passing
## for staff. The hard rate teaches neither, and instead teaches only on a near
## miss — which is what the +1 in the checks below is testing for.
const SNEAK_LESSON := {&"fast": 40, &"classic": 10, &"hard": 0}
const PASS_LESSON := {&"fast": 50, &"classic": 10, &"hard": 0}
const NEAR_MISS_LESSON := 10


## One turn of not being noticed.
##
## [param timer] is how long the squad has been inside; every turn past the
## first makes both checks harder. Returns the events.
static func check(state: GameState, rng: Rng, squad: Squad, timer: int,
		catalog: Catalog) -> Array[Event]:
	var events: Array[Event] = []
	var members := state.squad_members(squad)
	if members.is_empty():
		return events

	# The original counts the first turn as free by decrementing first.
	var pressure := timer - 1
	var weapon := Suspicion.UNREMARKABLE
	var anybody_naked := false
	for member: Creature in members:
		if member.armor == null and member.animal_gloss != &"animal":
			anybody_naked = true
		weapon = maxi(weapon, Suspicion.weapon_looks(state, member, catalog))

	# With nothing to hide, nothing is checked — unless the place expects a
	# uniform or the squad is somewhere it should not be.
	if state.site.alarm_timer == -1 and weapon < Suspicion.IN_CHARACTER \
			and not anybody_naked:
		if not Suspicion.uniformed_site(state.site.type) and not _restricted(state):
			return events

	var watchers: Array[Creature] = []
	for person: Creature in Encounters.living(state):
		if person.type != &"CREATURE_PRISONER" and Encounters.is_enemy(person):
			watchers.append(person)
	if watchers.is_empty():
		return events

	return _run_the_gauntlet(state, rng, squad, members, watchers, pressure,
			weapon, catalog)


## Each watcher in turn, until one of them is not satisfied.
static func _run_the_gauntlet(state: GameState, rng: Rng, squad: Squad,
		members: Array[Creature], watchers: Array[Creature], pressure: int,
		weapon: int, catalog: Catalog) -> Array[Event]:
	var events: Array[Event] = []
	var spotted := false
	var noticed := false
	var fumbled: Creature = null
	var watcher: Creature = null

	while not watchers.is_empty():
		watcher = watchers[rng.below(watchers.size())]
		watchers.erase(watcher)

		var tiers: Array = Suspicion.WATCHFULNESS.get(watcher.type,
				[Difficulty.VERY_EASY, Difficulty.VERY_EASY])
		var to_sneak: int = tiers[0]
		var to_pass: int = tiers[1]
		if state.site.alarm_timer == 1:
			to_sneak += Suspicion.NEARLY_CAUGHT
			to_pass += Suspicion.NEARLY_CAUGHT
		elif state.site.alarm_timer > 1:
			to_sneak += Suspicion.SUSPECTED
			to_pass += Suspicion.SUSPECTED
		to_sneak += (members.size() - 1) * Suspicion.PER_COMPANION

		for member: Creature in members:
			if not spotted:
				var sneak := CheckRules.skill_roll(rng, member, &"stealth",
						{&"catalog": catalog}) - pressure
				_near_miss(state, member, &"stealth", sneak, to_sneak)
				if sneak < to_sneak:
					spotted = true
			if not spotted:
				continue

			# A visible weapon is not something anybody can act casual about.
			if Suspicion.weapon_looks(state, member, catalog) == Suspicion.TROUBLE:
				noticed = true
				break
			# Disguise reads how well the outfit belongs here, which is not
			# something the roll can work out for itself.
			var pass_roll := CheckRules.skill_roll(rng, member, &"disguise",
					{&"catalog": catalog,
					&"disguise": Disguise.rating(state, member, catalog)}) \
					- pressure
			_near_miss(state, member, &"disguise", pass_roll, to_pass)
			if pass_roll < to_pass:
				if pass_roll < 0:
					fumbled = member
				noticed = true
				break
		if noticed:
			break

	events.append_array(_feedback(state, rng, members, spotted, noticed,
			fumbled, pressure, catalog))
	if not noticed:
		return events
	return events + _reaction(state, rng, watcher, weapon)


## What the squad learns from a turn that went well.
static func _feedback(state: GameState, rng: Rng, members: Array[Creature],
		spotted: bool, noticed: bool, fumbled: Creature, pressure: int,
		catalog: Catalog) -> Array[Event]:
	var events: Array[Event] = []
	if not spotted:
		for member: Creature in members:
			TrainRules.train(member, &"stealth",
					int(SNEAK_LESSON[state.field_skill_rate]))
		if pressure == 0:
			events.append(Event.new(Event.SQUAD_UNSEEN))
		return events

	if fumbled == null:
		# Everybody in a convincing outfit learns from carrying it off.
		for member: Creature in members:
			if Disguise.rating(state, member, catalog) != 0:
				TrainRules.train(member, &"disguise",
						int(PASS_LESSON[state.field_skill_rate]))

	if fumbled != null and rng.below(2) != 0:
		events.append(Event.new(Event.SQUAD_FUMBLED, {"creature": fumbled.id,
				"manner": rng.below(Suspicion.FUMBLE_LINES)}))
	elif not noticed:
		events.append(Event.new(Event.SQUAD_ACTED_NATURAL))
	return events


## What the watcher does about it.
static func _reaction(state: GameState, rng: Rng, watcher: Creature,
		weapon: int) -> Array[Event]:
	var events: Array[Event] = []
	var quiet := state.site.alarm_timer != 0 and weapon < Suspicion.IN_CHARACTER \
			and watcher.type != &"CREATURE_GUARDDOG"

	if quiet:
		# Somebody in their own building finding a stranger in the back rooms
		# does not wonder about it.
		if Suspicion.HOMES.has(state.site.type) and _restricted(state):
			state.site.alarm = true
			events.append(Event.new(Event.SITE_ALARM_RAISED,
					{"creature": watcher.id, "cause": &"trespass"}))
			return events

		# Otherwise they start wondering, and how long that takes is what they
		# can work out for themselves.
		var patience := Suspicion.SUSPICION_BASE + rng.below(Suspicion.SUSPICION_SPAN) \
				- AttributeRules.effective(watcher, &"intelligence", true) \
				- AttributeRules.effective(watcher, &"wisdom", true)
		patience = maxi(patience, 1)
		if state.site.alarm_timer > patience or state.site.alarm_timer == -1:
			state.site.alarm_timer = patience
		else:
			# Being looked at again by somebody less sharp is reassuring: five
			# turns come off, and anything at five or under is forgotten
			# outright — both statements run, so a countdown of eight goes to
			# three and then to nothing in one step.
			if state.site.alarm_timer > Suspicion.REASSURANCE:
				state.site.alarm_timer -= Suspicion.REASSURANCE
			if state.site.alarm_timer <= Suspicion.REASSURANCE:
				state.site.alarm_timer = 0
		events.append(Event.new(Event.SQUAD_SUSPECTED,
				{"creature": watcher.id, "patience": state.site.alarm_timer}))
		return events

	state.site.alarm = true
	events.append(Event.new(Event.SITE_ALARM_RAISED, {"creature": watcher.id,
			"cause": &"weapons" if weapon != Suspicion.UNREMARKABLE
					else &"intolerance"}))
	return events


## The hard training rate teaches only when a check was missed by one.
static func _near_miss(state: GameState, member: Creature, skill: StringName,
		result: int, difficulty: int) -> void:
	if state.field_skill_rate == &"hard" and result + 1 == difficulty:
		TrainRules.train(member, skill, NEAR_MISS_LESSON)


static func _restricted(state: GameState) -> bool:
	if state.site.map == null:
		return false
	return (state.site.map.get_flag(state.site.x, state.site.y, state.site.z)
			& int(Tables.SITE_BLOCKS[&"restricted"])) != 0
