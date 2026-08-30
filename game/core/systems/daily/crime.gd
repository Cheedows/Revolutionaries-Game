class_name CrimeRules
extends RefCounted
## Being suspected of things, and the heat that brings.
##
## Ports criminalize(), criminalizeparty(), criminalizepool() and
## lawflagheat() from src/common/commonactions.cpp.
##
## Heat is not severity: assault carries none because the squad picks up too
## many assault charges for another to mean anything, while arson and drug
## dealing carry a great deal because the police pursue them hard. It decides
## how quickly a safehouse gets raided and how badly a trial goes.


## Books [param crime] against [param creature].
##
## Nothing is booked for self-defence against an extrajudicial raid, or for
## anything done to the Conservative Crime Squad — the state does not prosecute
## either.
static func charge(state: GameState, creature: Creature, crime: StringName) -> Event:
	if _is_unprosecuted(state):
		return Event.new(Event.MAJOR_EVENT,
				{"kind": &"crime_unprosecuted", "crime": crime})

	var index := Ids.LAW_FLAGS.find(crime)
	if index < 0:
		return Event.new(Event.MAJOR_EVENT, {"kind": &"unknown_crime", "crime": crime})

	creature.crimes_suspected[index] += 1
	creature.heat += heat_of(crime)
	return Event.new(Event.MAJOR_EVENT, {
		"kind": &"crime_suspected",
		"creature": creature.id,
		"crime": crime,
		"heat": creature.heat,
	})


## Books [param crime] against everyone in the active squad who is still alive.
static func charge_squad(state: GameState, crime: StringName) -> Array[Event]:
	var events: Array[Event] = []
	var squad := state.active_squad()
	if squad == null:
		return events
	for creature in state.squad_members(squad):
		if creature.alive:
			events.append(charge(state, creature, crime))
	return events


## Books [param crime] against everyone, or everyone at [param location].
static func charge_everyone(state: GameState, crime: StringName,
		location: int = -1, exclude: int = -1) -> Array[Event]:
	var events: Array[Event] = []
	for creature: Creature in state.creatures.values():
		if creature.id == exclude:
			continue
		if location != -1 and creature.location != location:
			continue
		events.append(charge(state, creature, crime))
	return events


## How hard the police pursue [param crime].
static func heat_of(crime: StringName) -> int:
	return Tables.CRIME_HEAT.get(crime, 0)


## Whether the state would decline to prosecute what is happening right now.
static func _is_unprosecuted(state: GameState) -> bool:
	if state.site.location == -1:
		return false
	var site: Location = state.locations.get(state.site.location)
	if site == null:
		return false
	var siege: Siege = state.sieges.get(site.id)
	if siege != null and siege.active:
		# Only a police siege is a lawful one; the rest are raids.
		return siege.attacker != &"police"
	return site.rented_by == &"ccs"
