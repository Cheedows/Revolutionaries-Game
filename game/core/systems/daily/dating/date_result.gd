class_name DateResult
extends RefCounted
## How an evening out turned out.
##
## Ports dateresult() from src/daily/date.cpp, which every date and every
## holiday funnels through: the Liberal's charm against the other person's
## judgement. Winning by enough converts them outright; winning by a little
## chips away at their good sense; losing ends it, and losing while wanted can
## end it in a police ambush.

## What the evening came to.
const MEET_TOMORROW := &"meet_tomorrow"
const BREAK_UP := &"break_up"
const JOINED := &"joined"
const ARRESTED := &"arrested"

## Judgement above this is worn down a point at a time rather than letting
## anything slip.
const GUARDED_WISDOM := 3

## Someone wanted by the police is given away one evening in fifty — or half
## the time, if the person they are seeing carries a badge.
const INFORMER_ODDS := 50
const BADGE_ODDS := 2

## Standing that makes the ambush survivable.
const CONFIDENT_JUICE := 50

## What losing badly to a Conservative teaches: their subjects, at twenty
## points a level of difference.
const LESSON_FACTOR := 20


## Settles the evening between [param dater] and [param date].
##
## [param charm] and [param guard] are the two rolls, which the ordinary date
## and the week away build differently — the comparison between them is all
## this needs. Returns [code]{outcome, events}[/code]; the date is taken off
## [param plan] unless they are being seen again tomorrow.
static func settle(state: GameState, rng: Rng, plan: DatePlan,
		dater: Creature, date: Creature, charm: int, guard: int,
		catalog: Catalog) -> Dictionary:
	var events: Array[Event] = []
	if charm > guard:
		return _won(state, rng, plan, dater, date, charm - guard, events)
	if charm == guard:
		# They had fun but left early, for a reason the original rolls for and
		# then reads out.
		rng.below(4)
		return {"outcome": MEET_TOMORROW, "events": events}
	return _lost(state, rng, plan, dater, date, charm, guard, catalog, events)


## The Liberal was the more persuasive one.
static func _won(state: GameState, rng: Rng, plan: DatePlan, dater: Creature,
		date: Creature, margin: int, events: Array[Event]) -> Dictionary:
	if Relationships.slots_left(state, dater) <= 0:
		# Charming, and one person too many. They part amicably.
		events.append(Event.new(Event.DATE_ENDED,
				{"creature": dater.id, "date": date.id, "reason": &"juggling"}))
		_drop(plan, date)
		return {"outcome": BREAK_UP, "events": events}

	# Winning by a wide enough margin against poor enough judgement takes them
	# altogether. The margin is halved and rolled against their real wisdom,
	# augmentations and all.
	if rng.below(margin / 2) > AttributeRules.effective(date, &"wisdom", true):
		return _converted(state, plan, dater, date, events)

	_wear_down(state, rng, dater, date, events)
	events.append(Event.new(Event.DATE_CONTINUES,
			{"creature": dater.id, "date": date.id}))
	return {"outcome": MEET_TOMORROW, "events": events}


## They give up everything and come home.
static func _converted(state: GameState, plan: DatePlan, dater: Creature,
		date: Creature, events: Array[Event]) -> Dictionary:
	var work: Location = state.locations.get(date.work_location)
	if work != null:
		work.mapped = true
		work.hidden = false

	date.love_slave = true
	date.hire_id = dater.id
	# The original asks whether they come home or stay where they work as a
	# sleeper; coming home is the answer with no rolls in it, and the sleeper
	# half is the recruitment system's prompt, reused.
	date.location = dater.location
	date.base = dater.base
	Alignment.liberalize(date, false)
	date.join_days = 0
	state.recruits += 1
	_drop(plan, date)
	events.append(Event.new(Event.DATE_JOINED,
			{"creature": dater.id, "date": date.id}))
	return {"outcome": JOINED, "events": events}


## A good evening that changed nothing much: one point off their judgement, or
## a word about where they work.
##
## The original's chain is an else-if, so a Conservative with any judgement
## left never lets anything about their workplace slip.
static func _wear_down(state: GameState, rng: Rng, dater: Creature,
		date: Creature, events: Array[Event]) -> void:
	var wisdom := AttributeRules.effective(date, &"wisdom", false)
	if date.alignment == &"conservative" and wisdom > GUARDED_WISDOM:
		date.attributes.adjust(&"wisdom", -1)
		date.attributes.adjust(&"heart", 1)
		events.append(Event.new(Event.DATE_WARMED,
				{"creature": dater.id, "date": date.id}))
		return
	if wisdom > GUARDED_WISDOM:
		date.attributes.adjust(&"wisdom", -1)
		return
	var work: Location = state.locations.get(date.work_location)
	if work == null or work.mapped or not rng.one_in(wisdom):
		return
	work.mapped = true
	work.hidden = false
	events.append(Event.new(Event.DATE_TALKED,
			{"creature": dater.id, "date": date.id, "location": work.id}))


## The other person was not persuaded.
static func _lost(state: GameState, rng: Rng, plan: DatePlan, dater: Creature,
		date: Creature, charm: int, guard: int, catalog: Catalog,
		events: Array[Event]) -> Dictionary:
	# Losing badly to a Conservative is an education in itself.
	if date.alignment == &"conservative" and charm < guard / 2:
		dater.attributes.adjust(&"wisdom", 1)
		for skill: StringName in [&"religion", &"science", &"business"]:
			var gap := date.skills.get_value(skill) - dater.skills.get_value(skill)
			if gap > 0:
				TrainRules.train(dater, skill, LESSON_FACTOR * gap)
		events.append(Event.new(Event.DATE_CURSED,
				{"creature": dater.id, "date": date.id}))

	if CrimeRules.is_criminal(dater) and _informed(rng, date):
		events.append(Event.new(Event.DATE_INFORMED,
				{"creature": dater.id, "date": date.id}))
		# Three times in four for somebody with nothing to their name; half
		# the time for somebody the movement respects.
		var caught := rng.below(2) != 0 if dater.juice < CONFIDENT_JUICE else false
		if not caught:
			caught = rng.below(2) != 0
		if caught:
			events.append_array(Capture.capture(state, dater, catalog))
			_drop(plan, date)
			return {"outcome": ARRESTED, "events": events}
	else:
		# The other kind of disaster: being caught juggling.
		if Relationships.love_slaves(state, dater) > 0:
			rng.below(2)

	events.append(Event.new(Event.DATE_ENDED,
			{"creature": dater.id, "date": date.id, "reason": &"over"}))
	_drop(plan, date)
	return {"outcome": BREAK_UP, "events": events}


## Whether the evening ends with the police waiting outside. The second roll is
## made whether or not the person carries a badge — the original rolls first
## and checks after.
static func _informed(rng: Rng, date: Creature) -> bool:
	if rng.one_in(INFORMER_ODDS):
		return true
	return rng.below(BADGE_ODDS) != 0 and CreatureCondition.kidnap_resistant(date)


static func _drop(plan: DatePlan, date: Creature) -> void:
	for index in plan.date_ids.size():
		if plan.date_ids[index] == date.id:
			plan.date_ids.remove_at(index)
			return
