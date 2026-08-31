class_name SiteBroadcast
extends RefCounted
## Taking over a studio.
##
## Ports radio_broadcast() and news_broadcast() from
## src/sitemode/miscactions.cpp, and the two specials that reach them in
## mapspecials.cpp. The squad talks for an hour about whichever issue comes to
## mind; how well it goes is the sum of what everybody present knows, averaged
## across them and topped up with a quarter of the total, so a large squad of
## specialists beats one polymath.
##
## The two studios are not the same show. Radio pays out five times what
## television does on the issue itself, and television is the only one of the
## two where flying the Squad's colours still helps — the line is commented out
## on the radio side and live on the other, and both are kept as they are.

## What a famous hostage is worth before anybody hears them speak.
const FAME_BONUS := 10

## What the whole squad learns from an hour of it.
const LESSON := 50

## The floor a show has to clear before the room forgives the squad, and
## before security stops coming.
const FORGIVEN := 40
const RADIO_SAFE := 90
const NEWS_SAFE := 85

## A television show so bad that nobody investigates it.
const NEWS_TOO_BAD := 25

## How many guards turn up when it went badly.
const GUARDS_BASE := 2
const GUARDS_SPREAD := 8

## What the Squad's own standing gains either way.
const FAME := 10

## Colours are worth half again as much on television.
const COLOURS_NUMERATOR := 3
const COLOURS_DENOMINATOR := 2


## An hour of AM radio. Returns [code]{aired, power, events}[/code].
static func radio(state: GameState, rng: Rng, squad: Squad,
		catalog: Catalog) -> Dictionary:
	return _broadcast(state, rng, squad, catalog, false)


## An hour of cable news.
static func news(state: GameState, rng: Rng, squad: Squad,
		catalog: Catalog) -> Dictionary:
	return _broadcast(state, rng, squad, catalog, true)


static func _broadcast(state: GameState, rng: Rng, squad: Squad,
		catalog: Catalog, television: bool) -> Dictionary:
	var events: Array[Event] = []
	state.site.alarm = true
	for id in state.site.encounter_ids:
		var person: Creature = state.creatures.get(id)
		if person != null and person.alive \
				and person.alignment == &"conservative":
			# Somebody in the room to object is enough to stop it.
			return {"aired": false, "power": 0, "events": events}

	events.append_array(CrimeRules.charge_squad(state, &"disturbance"))
	var subject := Ids.VIEWS[rng.below(Ids.VIEWS.size())]

	var power := 0
	var present := 0
	for member: Creature in state.squad_members(squad):
		if not member.alive:
			continue
		present += 1
		power += _contribution(member)
		TrainRules.train(member, &"persuasion", LESSON)
	if television and squad.stance == &"battlecolors":
		power = power * COLOURS_NUMERATOR / COLOURS_DENOMINATOR
	var bonus := power / 4
	if present > 1:
		power /= present
	power += bonus

	events.append(OpinionChangeRules.change(state, &"liberalcrimesquad", FAME))
	if television:
		events.append(OpinionChangeRules.change(state,
				&"liberalcrimesquadpos", (power - 50) / 10))
		if subject != &"liberalcrimesquad":
			events.append(OpinionChangeRules.change(state, subject,
					(power - 50) / 5, 1))
		else:
			events.append(OpinionChangeRules.change(state, subject, power / 10))
	else:
		events.append(OpinionChangeRules.change(state,
				&"liberalcrimesquadpos", (power - 50) / 2))
		if subject != &"liberalcrimesquad":
			events.append(OpinionChangeRules.change(state, subject,
					(power - 50) / 2, 1))
		else:
			events.append(OpinionChangeRules.change(state, subject, power / 2))

	power += _hostages(state, rng, squad, television, events)

	if state.site.alienated >= 1 and power >= FORGIVEN:
		state.site.alienated = 0
	events.append(Event.new(Event.BROADCAST_AIRED, {
		"television": television, "subject": subject, "power": power,
	}))

	# A bad show brings security. Television has a floor as well as a ceiling:
	# a show nobody could take seriously is not worth investigating.
	var poor := power < NEWS_SAFE and power >= NEWS_TOO_BAD if television \
			else power < RADIO_SAFE
	if poor:
		PrisonerRescue.fill_the_room(state, rng,
				rng.below(GUARDS_SPREAD) + GUARDS_BASE, catalog,
				&"CREATURE_SECURITYGUARD")
	return {"aired": true, "power": power, "events": events}


## What one Liberal brings to the show: three attributes and five skills, of
## which only persuasion is one anybody would list on a résumé.
static func _contribution(member: Creature) -> int:
	var total := AttributeRules.effective(member, &"intelligence", true) \
			+ AttributeRules.effective(member, &"heart", true) \
			+ AttributeRules.effective(member, &"charisma", true)
	for skill: StringName in [&"music", &"religion", &"science", &"business",
			&"persuasion"]:
		total += member.skills.get_value(skill)
	return total


## A famous hostage put in front of the microphone. Only the right kind of
## celebrity counts, and only a living one.
##
## The two shows disagree about how the hostage's segment lands: the radio caps
## the issue at eighty and the television does not, and the two swap which of
## the branches marks the change as one the public noticed. Both kept.
static func _hostages(state: GameState, rng: Rng, squad: Squad,
		television: bool, events: Array[Event]) -> int:
	var wanted := &"CREATURE_NEWSANCHOR" if television \
			else &"CREATURE_RADIOPERSONALITY"
	var gained := 0
	for member: Creature in state.squad_members(squad):
		var hostage: Creature = state.creatures.get(member.prisoner_id)
		if hostage == null or not hostage.alive or hostage.type != wanted:
			continue
		var subject := Ids.VIEWS[rng.below(Ids.VIEWS.size())]
		var power := FAME_BONUS \
				+ AttributeRules.effective(hostage, &"intelligence", true) \
				+ AttributeRules.effective(hostage, &"heart", true) \
				+ AttributeRules.effective(hostage, &"charisma", true) \
				+ hostage.skills.get_value(&"persuasion")
		if television:
			if subject != &"liberalcrimesquad":
				events.append(OpinionChangeRules.change(state, subject,
						(power - FAME_BONUS) / 2))
			else:
				events.append(OpinionChangeRules.change(state, subject,
						power / 2, 1))
		else:
			if subject != &"liberalcrimesquad":
				events.append(OpinionChangeRules.change(state, subject,
						(power - FAME_BONUS) / 2, 1, 80))
			else:
				events.append(OpinionChangeRules.change(state, subject,
						power / 2))
		gained += power
	return gained
