class_name CombatSurrender
extends RefCounted
## Putting your hands up.
##
## Ports the surrender branch of talkInCombat() in src/sitemode/talk.cpp. Only
## the police and people like them take a surrender; everybody the squad is
## carrying stolen goods for is charged, once per stolen thing, and then the
## whole squad is arrested.

## Gives the squad up. Returns the events.
static func give_up(state: GameState, speaker: Creature,
		catalog: Catalog) -> Array[Event]:
	var events: Array[Event] = [Event.new(Event.SQUAD_SURRENDERED,
			{"creature": speaker.id})]
	var squad := state.active_squad()
	if squad == null:
		return events

	# Every piece of loot in the bag is a separate count of theft, and each of
	# them is booked against every member — the original charges the whole
	# squad the whole tally.
	var stolen := 0
	for item: Item in squad.haul:
		if item is Loot:
			stolen += 1

	var flag := Ids.LAW_FLAGS.find(&"theft")
	for member: Creature in state.squad_members(squad):
		member.crimes_suspected[flag] += stolen
		events.append_array(Capture.capture(state, member, catalog))
	squad.member_ids.clear()

	var siege: Siege = state.sieges.get(state.site.location)
	if siege != null:
		siege.active = false
	return events
