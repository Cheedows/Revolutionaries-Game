class_name LandlordTalk
extends RefCounted
## Renting a room, and giving one up.
##
## Ports heyIWantToRentARoom() and heyIWantToCancelMyRoom() from
## src/sitemode/talk.cpp. A landlord will take money, and — for a Liberal with
## a way with words and a friend with a gun — rather less than money.

## The three answers to a rent offer.
const ACCEPT := 0
const REFUSE := 1
const THREATEN := 2

## What each kind of place asks for a month.
const RENT: Dictionary = {
	&"residential_apartment": 650,
	&"residential_apartment_upscale": 1500,
}
const DEFAULT_RENT := 200

## How hard the landlord is to frighten, and what makes them easier: a Squad
## the news has heard of, and somebody standing behind you holding something.
const INTIMIDATION := Difficulty.FORMIDABLE
const UNKNOWN_PENALTY := 6
const UNARMED_PENALTY := 6

## The rent a landlord charges somebody they have decided to evict. It is not
## a number anybody is meant to pay.
const EVICTION_RENT := 10000000

## How long a frightened landlord takes to bring the police.
const POLICE_DELAY := 2


## The landlord offers a room. Returns a [PendingIntent].
static func offer(state: GameState, rng: Rng, speaker: Creature, listener: Creature,
		catalog: Catalog) -> PendingIntent:
	var rent := int(RENT.get(state.site.type, DEFAULT_RENT))
	var options: Array[Dictionary] = [
		{"id": ACCEPT, "label": "Pay the rent.", "cost": rent,
				"enabled": state.ledger.funds >= rent},
		{"id": REFUSE, "label": "Think it over.", "enabled": true},
		{"id": THREATEN, "label": "Threaten the landlord.", "enabled": true},
	]
	return PendingIntent.new(
			Intent.new(Intent.CHOOSE_DIALOGUE, options,
					{"creature": speaker.id, "landlord": listener.id,
					"rent": rent}, false),
			func(answer: Variant) -> Array[Event]:
				return _answer(state, rng, speaker, listener, rent,
						int(answer), catalog),
			[] as Array[Event])


static func _answer(state: GameState, rng: Rng, speaker: Creature,
		listener: Creature, rent: int, choice: int,
		catalog: Catalog) -> Array[Event]:
	if choice == REFUSE:
		return []
	if choice == ACCEPT:
		state.ledger.subtract(rent, &"rent")
		_move_in(state, rent)
		return [Event.new(Event.ROOM_RENTED,
				{"location": state.site.location, "rent": rent})]
	return _threaten(state, rng, speaker, listener, catalog)


## Leaning on the landlord. A Liberal who nearly manages it gets the room and a
## charge sheet; one who manages it outright gets the room for nothing.
static func _threaten(state: GameState, rng: Rng, speaker: Creature,
		listener: Creature, catalog: Catalog) -> Array[Event]:
	var events: Array[Event] = []
	var backup := TalkBackup.armed(state, catalog)

	var roll := CheckRules.skill_roll(rng, speaker, &"persuasion")
	var difficulty := INTIMIDATION
	if int(state.stats.get(&"newscherrybusted", 0)) == 0:
		difficulty += UNKNOWN_PENALTY
	if backup == null:
		difficulty += UNARMED_PENALTY

	if roll < difficulty - 1:
		listener.cannot_bluff = 1
		events.append(Event.new(Event.ROOM_REFUSED,
				{"location": state.site.location}))
		return events

	var rent := 0
	if roll < difficulty:
		# They agree, and then they go to the police, and next month the rent
		# is a number nobody could pay.
		events.append_array(CrimeRules.charge_squad(state, &"extortion"))
		var siege: Siege = state.sieges.get(state.site.location)
		if siege == null:
			siege = Siege.new()
			state.sieges[state.site.location] = siege
		siege.time_until_located = POLICE_DELAY
		rent = EVICTION_RENT
	_move_in(state, rent)
	events.append(Event.new(Event.ROOM_RENTED,
			{"location": state.site.location, "rent": rent,
			"threatened": true}))
	return events


## The squad takes the place as its own.
static func _move_in(state: GameState, rent: int) -> void:
	var site: Location = state.locations.get(state.site.location)
	if site == null:
		return
	site.renting = rent
	site.rented_by = Renting.name_of(rent)
	site.new_rental = true
	var squad := state.active_squad()
	if squad == null:
		return
	for member: Creature in state.squad_members(squad):
		member.base = site.id


## Giving the room up. Everybody there moves to the shelter and everything in
## it goes with them; money in the pile is banked rather than carried.
static func cancel(state: GameState) -> Array[Event]:
	var site: Location = state.locations.get(state.site.location)
	if site == null:
		return []
	site.renting = Renting.NOBODY
	site.rented_by = Renting.name_of(site.renting)

	var shelter := WorldLookup.homeless_shelter(state, site)
	var refuge: int = shelter.id if shelter != null else -1
	for person: Creature in state.creatures.values():
		if person.location == site.id:
			person.location = refuge
		if person.base == site.id:
			person.base = refuge
	if shelter != null:
		stow(state, shelter, site.ground_loot)

	site.compound_walls = 0
	site.compound_stores = 0
	site.front_business = -1
	return [Event.new(Event.ROOM_GIVEN_UP,
			{"location": site.id, "moved_to": refuge})]


## Empties [param pile] into [param place]. Ports Location::getloot(): cash is
## banked rather than shelved, and the pile is left empty either way.
static func stow(state: GameState, place: Location, pile: Array[Item]) -> void:
	for index in range(pile.size() - 1, -1, -1):
		var item: Item = pile[index]
		if item is Money:
			state.ledger.add(item.count, &"thievery")
		else:
			place.ground_loot.append(item)
	pile.clear()
