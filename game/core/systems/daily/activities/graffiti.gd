class_name GraffitiActivity
extends RefCounted
## A night out with a spray can.
##
## Ports doActivityGraffiti() from src/daily/activities.cpp. Most nights are a
## tag; occasionally a Liberal starts a mural, which takes several nights and
## is worth far more when it is finished — or nothing at all if the police
## interrupt it.

## What a can costs when there isn't one at the safehouse.
const SPRAYCAN_COST := 20

## The odds of being seen. The check that saves you from it is an average one.
const SPOTTED_ODDS := 10

## Being caught is a lesson in itself.
const CAUGHT_LESSON := 20

## A mural is finished one night in three, and started on a night in however
## many — fewer the better the artist, and never fewer than five.
const MURAL_FINISH_ODDS := 3
const MURAL_START_BASE := 30
const MURAL_START_PER_SKILL := 2
const MURAL_START_FLOOR := 5

## A finished mural's power is a third of the roll behind it.
const MURAL_POWER_DIVISOR := 3

## Standing for a finished mural, capped at twenty times its power.
const MURAL_JUICE_CAP := 20

## Practice at the easel, which tails off as the Liberal gets good.
const ART_LESSON_BASE := 10
const ART_LESSON_DIVISOR := 2
const ART_LESSON_FLOOR := 1
const TAG_LESSON_BASE := 4

## How far a night's work moves opinion of the organisation, and how much of
## the country can ever be moved by it.
const OWN_NAME_CAP := 65
const ISSUE_NAME_CAP := 85
const APPROVAL_ODDS_TAG := 8
const APPROVAL_ODDS_MURAL := 4

## No mural in progress.
const NO_MURAL := &""


## One Liberal's night.
##
## Returns the events, or a [PendingIntent] when the police turn up: being
## spotted is a foot chase, and the player runs it.
static func run(state: GameState, rng: Rng, artist: Creature,
		catalog: Catalog) -> Variant:
	var events := _find_a_can(state, artist, catalog)
	if artist.activity == &"none":
		return events

	var issue: StringName = &"liberalcrimesquad"
	var power := 1

	if rng.one_in(SPOTTED_ODDS) and not CheckRules.skill_check(rng, artist,
			&"streetsense", Difficulty.AVERAGE):
		events.append_array(_spotted(state, artist))
		# The police do not simply write it down: this is a foot chase. The
		# night's tail still runs afterwards, whatever became of the artist —
		# the wall keeps whatever was already on it.
		var chase: Variant = ArrestChase.attempt(state, rng, artist, catalog)
		return _after_the_police(state, rng, artist, issue, power, events, chase)
	elif artist.mural != NO_MURAL:
		power = 0
		if rng.one_in(MURAL_FINISH_ODDS):
			issue = artist.mural
			power = CheckRules.skill_roll(rng, artist, &"art") / MURAL_POWER_DIVISOR
			artist.mural = NO_MURAL
			JuiceRules.add(state, artist, power, power * MURAL_JUICE_CAP)
			events.append(OpinionChangeRules.change(state, issue, power))
			_practise(artist)
			events.append(Event.new(Event.GRAFFITI_MURAL_DONE,
					{"creature": artist.id, "issue": issue, "power": power}))
		else:
			_practise(artist)
			events.append(Event.new(Event.GRAFFITI_MURAL_WORKED,
					{"creature": artist.id}))
	elif rng.one_in(maxi(MURAL_START_BASE
			- artist.skills.get_value(&"art") * MURAL_START_PER_SKILL,
			MURAL_START_FLOOR)):
		issue = OpinionRules.random_issue(rng, state, false)
		artist.mural = issue
		power = 0
		_practise(artist)
		events.append(Event.new(Event.GRAFFITI_MURAL_STARTED,
				{"creature": artist.id, "issue": issue}))
	else:
		events.append(Event.new(Event.GRAFFITI_TAGGED, {"creature": artist.id}))

	return _finish_the_night(state, rng, artist, issue, power, events)


## Picks the night back up once the chase is over.
static func _after_the_police(state: GameState, rng: Rng, artist: Creature,
		issue: StringName, power: int, events: Array[Event],
		chase: Variant) -> Variant:
	if chase is PendingIntent:
		var asked: PendingIntent = chase
		return PendingIntent.new(asked.intent,
				func(answer: Variant) -> Variant:
					return _after_the_police(state, rng, artist, issue, power,
							events, asked.resume.call(answer)),
				events + asked.events)
	return _finish_the_night(state, rng, artist, issue, power,
			events + (chase as Array[Event]))


## The practice and the word that gets around, which happen either way.
static func _finish_the_night(state: GameState, rng: Rng, artist: Creature,
		issue: StringName, power: int, events: Array[Event]) -> Array[Event]:
	TrainRules.train(artist, &"art",
			maxi(TAG_LESSON_BASE - artist.skills.get_value(&"art"), 0))
	events.append_array(_word_gets_around(state, rng, issue, power))
	return events


## Whatever was sprayed, somebody saw the name on it.
##
## A plain tag says only that the squad exists; a mural about something says
## that and makes the something matter, and both are worth a little approval.
static func _word_gets_around(state: GameState, rng: Rng, issue: StringName,
		power: int) -> Array[Event]:
	var events: Array[Event] = []
	var own_name := issue == &"liberalcrimesquad"
	events.append(OpinionChangeRules.change(state, &"liberalcrimesquad",
			rng.below(2) + (0 if own_name else 1), 0,
			OWN_NAME_CAP if own_name else ISSUE_NAME_CAP))
	events.append(OpinionChangeRules.change(state, &"liberalcrimesquadpos",
			1 if rng.one_in(APPROVAL_ODDS_TAG if own_name
					else APPROVAL_ODDS_MURAL) else 0, 0, OWN_NAME_CAP))

	var index := Ids.VIEWS.find(issue)
	state.opinion.interest[index] += power
	if not own_name:
		state.opinion.background_influence[index] += power
	return events


## Making sure there is something to spray with.
##
## The safehouse is searched first, then twenty dollars is spent; a Liberal
## with neither has nothing to do tonight.
static func _find_a_can(state: GameState, artist: Creature,
		catalog: Catalog) -> Array[Event]:
	var events: Array[Event] = []
	if _can_spray(artist, catalog):
		return events

	var base: Location = state.locations.get(artist.base)
	if base != null:
		for index in base.ground_loot.size():
			var item: Item = base.ground_loot[index]
			if not (item is Weapon):
				continue
			var type: WeaponType = catalog.get_entry(&"weapon", item.type)
			if type == null or not type.graffiti:
				continue
			_hand_over(state, artist, item, base)
			base.ground_loot.remove_at(index)
			events.append(Event.new(Event.SPRAYCAN_TAKEN,
					{"creature": artist.id, "from_base": base.id}))
			return events

	if state.ledger.can_afford(SPRAYCAN_COST):
		state.ledger.subtract(SPRAYCAN_COST, &"shopping")
		var bought := Weapon.new()
		bought.type = &"WEAPON_SPRAYCAN"
		_hand_over(state, artist, bought, base)
		events.append(Event.new(Event.SPRAYCAN_BOUGHT, {"creature": artist.id}))
		return events

	artist.activity = &"none"
	events.append(Event.new(Event.SPRAYCAN_MISSING, {"creature": artist.id}))
	return events


## Whether what they are holding will write on a wall.
static func _can_spray(artist: Creature, catalog: Catalog) -> bool:
	if artist.weapon == null:
		return false
	var type: WeaponType = catalog.get_entry(&"weapon", artist.weapon.type)
	return type != null and type.graffiti


## Swaps what the Liberal was carrying for the can, leaving the old weapon at
## the safehouse.
static func _hand_over(state: GameState, artist: Creature, can: Item,
		base: Location) -> void:
	if artist.weapon != null and base != null:
		base.ground_loot.append(artist.weapon)
	var held := Weapon.new()
	held.type = can.type
	artist.weapon = held


## Caught in the act. A mural in progress is lost along with the night.
static func _spotted(state: GameState, artist: Creature) -> Array[Event]:
	var events: Array[Event] = []
	events.append(CrimeRules.charge(state, artist, &"vandalism"))
	TrainRules.train(artist, &"streetsense", CAUGHT_LESSON)
	var mural := artist.mural != NO_MURAL
	artist.mural = NO_MURAL
	events.append(Event.new(Event.GRAFFITI_SPOTTED,
			{"creature": artist.id, "mural": mural}))
	return events


## The practice a night on a mural is worth: more the worse the artist is.
static func _practise(artist: Creature) -> void:
	TrainRules.train(artist, &"art", maxi(ART_LESSON_BASE
			- artist.skills.get_value(&"art") / ART_LESSON_DIVISOR,
			ART_LESSON_FLOOR))
