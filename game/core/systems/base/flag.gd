class_name FlagPole
extends RefCounted
## The flag outside a safehouse: buying one, and setting fire to it.
##
## Ports the 'p' case of `basemode()` from src/basemode/basemode.cpp. Flying a
## flag is what a Conservative neighbourhood judges a house by, so it hides the
## squad; burning it is a crime where the law says so, and a statement worth
## making where the police are already at the door.

## What a flag costs.
const PRICE := 20

## What burning one is worth to the country, by how illegal it is. Each entry
## is the standing gained and the free-speech ground made, with the share of
## the country that can be moved.
const PUBLICITY := [
	{&"squad": 1, &"speech": 1, &"cap": 30},
	{&"squad": 1, &"speech": 1, &"cap": 50},
	{&"squad": 5, &"speech": 2, &"cap": 70},
	{&"squad": 15, &"speech": 5, &"cap": 90},
]


## Whether the squad can put one up: the money, no siege, and somewhere to
## put it.
static func can_buy(state: GameState, site: Location) -> bool:
	return site != null and not site.has_flag \
			and state.ledger.funds >= PRICE and not _besieged(state, site)


## Buys a flag for [param site].
static func buy(state: GameState, site: Location) -> Array[Event]:
	if not can_buy(state, site):
		return [] as Array[Event]
	state.ledger.subtract(PRICE, &"compound")
	site.has_flag = true
	state.stats[&"flags_bought"] = int(state.stats.get(&"flags_bought", 0)) + 1
	return [Event.new(Event.FLAG_RAISED, {"location": site.id})] as Array[Event]


## Burns the flag at [param site].
##
## **Original quirk, reproduced.** The flag comes down at two places: the one
## being managed and the squad's own base. They are usually the same place, and
## when they are not, both lose their flag for the one that was burnt.
static func burn(state: GameState, site: Location, squad: Squad) -> Array[Event]:
	if site == null or not site.has_flag:
		return [] as Array[Event]
	var events: Array[Event] = []
	state.stats[&"flags_burnt"] = int(state.stats.get(&"flags_burnt", 0)) + 1
	var legal := state.law.get_value(&"flagburning") >= Alignment.LIBERAL

	site.has_flag = false
	if not legal:
		events.append_array(CrimeRules.charge_everyone(state, &"burnflag",
				site.id))
	var base := _base_of(state, squad)
	if base != null and base.id != site.id:
		base.has_flag = false
		if not legal:
			events.append_array(CrimeRules.charge_everyone(state, &"burnflag",
					base.id))

	# Burning one with the police outside is the only time anybody is watching.
	if _besieged(state, site):
		events.append_array(_publicity(state))
	events.append(Event.new(Event.FLAG_BURNED, {"location": site.id}))
	return events


## What the country makes of it, which is more the less it is allowed.
static func _publicity(state: GameState) -> Array[Event]:
	var events: Array[Event] = []
	var law := state.law.get_value(&"flagburning")
	for step in PUBLICITY.size():
		# The original writes these as a ladder of separate ifs, each on a
		# tighter law than the last, so a ban earns every rung of it.
		if step > 0 and law > Alignment.LIBERAL - step:
			break
		var rung: Dictionary = PUBLICITY[step]
		events.append(OpinionChangeRules.change(state, &"liberalcrimesquad",
				int(rung[&"squad"])))
		events.append(OpinionChangeRules.change(state, &"freespeech",
				int(rung[&"speech"]), 1, int(rung[&"cap"])))
	return events


static func _besieged(state: GameState, site: Location) -> bool:
	var siege: Siege = state.sieges.get(site.id)
	return siege != null and siege.active


static func _base_of(state: GameState, squad: Squad) -> Location:
	if squad == null or squad.member_ids.is_empty():
		return null
	var leader: Creature = state.creatures.get(squad.member_ids[0])
	if leader == null:
		return null
	return state.locations.get(leader.base)
