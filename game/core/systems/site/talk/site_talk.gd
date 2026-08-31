class_name SiteTalk
extends RefCounted
## Who the squad ends up talking to, and about what.
##
## Ports talk() and talkToGeneric() from src/sitemode/talk.cpp: the dispatch
## that decides whether an approach is a conversation, a negotiation at
## gunpoint or a bark, and the menu of things a Liberal can open with.

## The things anybody can be asked.
const DISTURBING := 0
const FLIRT := 1
const NOTHING := 2
const BUSINESS := 3

## The sites where somebody who sells guns will actually sell you one.
const GUN_SITES: Array[StringName] = [
	&"outdoor_bunker", &"business_crackhouse", &"business_barandgrill",
	&"business_armsdealer", &"residential_tenement",
	&"residential_bombshelter", &"residential_shelter",
]

## The uniforms nobody sells a gun to.
const POLICE_UNIFORMS: Array[StringName] = [
	&"ARMOR_POLICEUNIFORM", &"ARMOR_POLICEARMOR", &"ARMOR_SWATARMOR",
]


## [param speaker] approaches [param listener]. Returns either the events of a
## conversation that needs no input, or a [PendingIntent].
static func talk(state: GameState, rng: Rng, squad: Squad, speaker: Creature,
		listener: Creature, catalog: Catalog) -> Variant:
	if listener.type == &"CREATURE_GUARDDOG" \
			and listener.alignment != &"liberal":
		return AnimalTalk.to_dog(state, rng, squad, listener)
	if listener.type == &"CREATURE_GENETIC" \
			and listener.alignment != &"liberal":
		return AnimalTalk.to_monster(state, rng, squad, listener)

	var siege: Siege = state.sieges.get(state.site.location)
	var under_siege: bool = siege != null and siege.active
	if (state.site.alarm or under_siege) and Encounters.is_enemy(listener):
		return CombatTalk.begin(state, rng, speaker, listener, catalog)
	return generic(state, rng, speaker, listener, catalog)


## The ordinary menu: say something disturbing, try a line, walk away, or —
## depending on who they are — do business.
static func generic(state: GameState, rng: Rng, speaker: Creature,
		listener: Creature, catalog: Catalog) -> PendingIntent:
	var site: Location = state.locations.get(state.site.location)
	var business := _business(state, listener, site)
	var options: Array[Dictionary] = [
		{"id": DISTURBING, "label": "Say something disturbing.",
				"enabled": true},
		{"id": FLIRT, "label": "Try a line.",
				"enabled": Flirting.can_date(listener, speaker)},
		{"id": NOTHING, "label": "Say nothing.", "enabled": true},
	]
	if business != &"":
		options.append({"id": BUSINESS, "label": String(business),
				"enabled": true})
	return PendingIntent.new(
			Intent.new(Intent.CHOOSE_DIALOGUE, options,
					{"creature": speaker.id, "target": listener.id,
					"business": business}, false),
			func(answer: Variant) -> Variant:
				return _answer(state, rng, speaker, listener, business,
						int(answer), catalog),
			[] as Array[Event])


## What this particular person can do for the squad, if anything.
static func _business(state: GameState, listener: Creature,
		site: Location) -> StringName:
	if listener.type == &"CREATURE_LANDLORD":
		if site != null and site.renting == Renting.NOBODY:
			return &"rent_a_room"
		if site != null and Renting.is_rented(site.renting):
			return &"cancel_the_room"
		return &""
	if listener.type == &"CREATURE_GANGMEMBER" \
			or listener.type == &"CREATURE_MERC":
		return &"buy_a_gun"
	if listener.type == &"CREATURE_BANK_TELLER":
		return &"bank_business"
	return &""


static func _answer(state: GameState, rng: Rng, speaker: Creature,
		listener: Creature, business: StringName, choice: int,
		catalog: Catalog) -> Variant:
	match choice:
		DISTURBING:
			var talked := Persuasion.approach(state, rng, speaker, listener)
			return talked["events"]
		FLIRT:
			var tried := Flirting.approach(state, rng, speaker, listener)
			return tried["events"]
		NOTHING:
			return [] as Array[Event]
	match business:
		&"rent_a_room":
			return LandlordTalk.offer(state, rng, speaker, listener, catalog)
		&"cancel_the_room":
			return LandlordTalk.cancel(state)
		&"bank_business":
			return BankTellerTalk.approach(state, rng, speaker, listener,
					catalog)
		&"buy_a_gun":
			return buy_a_gun(state, speaker)
	return [] as Array[Event]


## Asking somebody on a street corner where to get a gun. Ports
## heyINeedAGun(): nobody sells to somebody with no clothes on, nobody sells to
## a uniform, nobody sells once the alarm has gone off, and nobody sells
## anywhere but the handful of places where that trade happens.
##
## The result is the arms dealer's own catalogue, opened where the squad
## stands.
static func buy_a_gun(state: GameState, speaker: Creature) -> Array[Event]:
	if speaker.is_naked() and speaker.animal_gloss != &"animal":
		return [Event.new(Event.GUN_SOUGHT, {"outcome": &"naked"})]

	var uniform := speaker.armor.type if speaker.armor != null else &""
	var deathsquad := uniform == &"ARMOR_DEATHSQUADUNIFORM" \
			and state.law.get_value(&"policebehavior") == -2 \
			and state.law.get_value(&"deathpenalty") == -2
	if POLICE_UNIFORMS.has(uniform) or deathsquad:
		return [Event.new(Event.GUN_SOUGHT, {"outcome": &"uniform"})]
	if state.site.alarm:
		return [Event.new(Event.GUN_SOUGHT, {"outcome": &"alarm"})]
	if not GUN_SITES.has(state.site.type):
		return [Event.new(Event.GUN_SOUGHT, {"outcome": &"wrong_place"})]
	return [Event.new(Event.GUN_SOUGHT,
			{"outcome": &"trading", "shop": &"armsdealer"})]
