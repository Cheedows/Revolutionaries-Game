class_name InterrogationBeating
extends RefCounted
## What a beating does to somebody who cannot take it.
##
## Ports the second half of the beating in tendhostage() from
## src/daily/interrogation.cpp: prayer, breaking, or simply getting the
## message — and then whether the body holds up at all.

## Judgement, heart and health are each worth three against being broken.
const RESILIENCE_FACTOR := 3

## Standing is lost outright; judgement goes a tenth of the beating at a time.
const WISDOM_DIVISOR := 10

## The odds of a broken hostage giving up their workplace.
const REVEAL_ODDS := 5

## The beating is a third as likely again to do lasting damage.
const LASTING_DIVISOR := 3


## The hostage failed to shrug it off.
static func take_it_badly(state: GameState, rng: Rng, hostage: Creature,
		session: Dictionary, force: int, events: Array[Event]) -> void:
	var plan := hostage.interrogation

	if CheckRules.skill_check(rng, hostage, &"religion", force):
		# They pray, and are no worse for it.
		rng.below(2)
	elif force > (AttributeRules.effective(hostage, &"wisdom", true)
			+ AttributeRules.effective(hostage, &"heart", true)
			+ AttributeRules.effective(hostage, &"health", true)) \
			* RESILIENCE_FACTOR:
		_broken(state, rng, hostage, session, force, events)
	else:
		# Getting the message: standing first, then judgement.
		if hostage.juice > 0:
			hostage.juice = maxi(hostage.juice - force, 0)
		if AttributeRules.effective(hostage, &"wisdom", false) > 1:
			hostage.attributes.set_value(&"wisdom", maxi(
					AttributeRules.effective(hostage, &"wisdom", false)
							- (force / WISDOM_DIVISOR + 1), 1))

	if not CheckRules.attribute_check(rng, hostage, &"health",
			force / LASTING_DIVISOR):
		if AttributeRules.effective(hostage, &"health", false) > 1:
			hostage.attributes.adjust(&"health", -1)
		else:
			hostage.attributes.set_value(&"health", 0)
			hostage.alive = false
			hostage.body.blood = 0


## Beaten past the point of holding anything back.
static func _broken(state: GameState, rng: Rng, hostage: Creature,
		session: Dictionary, force: int, events: Array[Event]) -> void:
	var plan := hostage.interrogation
	# Which way they break, and — on the drugs — what they break into.
	match rng.below(4):
		2:
			if plan.techniques[Interrogation.DRUGS]:
				rng.below(5)
		3:
			if plan.techniques[Interrogation.DRUGS]:
				rng.below(3)

	if AttributeRules.effective(hostage, &"heart", false) > 1:
		hostage.attributes.adjust(&"heart", -1)

	# Either their standing goes or their judgement does, and the original
	# tests the roll for truth rather than for zero.
	if rng.below(2) != 0 and hostage.juice > 0:
		hostage.juice = maxi(hostage.juice - force, 0)
	elif AttributeRules.effective(hostage, &"wisdom", false) > 1:
		hostage.attributes.set_value(&"wisdom", maxi(
				AttributeRules.effective(hostage, &"wisdom", false)
						- force / WISDOM_DIVISOR, 1))

	var work: Location = state.locations.get(hostage.work_location)
	if work != null and not work.mapped and rng.one_in(REVEAL_ODDS):
		work.mapped = true
		work.hidden = false
		events.append(Event.new(Event.DATE_TALKED, {
			"creature": session["lead"].id, "date": hostage.id,
			"location": work.id,
		}))
