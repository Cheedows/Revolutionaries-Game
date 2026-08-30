class_name LocationNames
extends RefCounted
## Naming the places in a city.
##
## Ports the naming half of initlocation() from src/locations/locations.cpp.
## The word lists are in LocationNameTables.
##
## Names are not decoration here: several depend on how Conservative the country
## has become — a police station becomes a Death Squad HQ, a prison becomes a
## Forced Labor Camp with a cheerful name — and the rolls they take are part of
## the generator sequence, so getting them wrong shifts everything after.
##
## Where the original loops until a name is unique, so does this: a city with
## two identical addresses would confuse the player and the original guards
## against it.


## Names [param location] according to the current law.
static func apply(state: GameState, rng: Rng, location: Location) -> void:
	var type := location.type

	if LocationNameTables.FIXED.has(type):
		_rename(location, LocationNameTables.FIXED[type])
		return

	if LocationNameTables.LAW_RENAMED.has(type):
		var rule: Array = LocationNameTables.LAW_RENAMED[type]
		var renamed := true
		for condition: Array in rule[0]:
			if state.law.get_value(condition[0]) != condition[1]:
				renamed = false
		_rename(location, rule[1] if renamed else rule[2])
		return

	if LocationNameTables.TWO_WORD.has(type):
		var words: Array = LocationNameTables.TWO_WORD[type]
		location.name = "%s %s%s" % [Roll.pick(rng, words[0]), Roll.pick(rng, words[1]), words[2]]
		location.short_name = words[3]
		return

	match type:
		&"government_firestation":
			# A country with no free speech does not hide who burns the books.
			var burning := state.law.get_value(&"freespeech") == -2
			_rename(location, ["Fireman HQ", "Fireman HQ"] if burning
					else ["Fire Station", "Fire Station"])
			location.hidden = not burning
		&"government_prison":
			_name_prison(state, rng, location)
		&"government_armybase":
			if state.law.get_value(&"military") == -2:
				_rename(location, ["Ministry of Peace", "Minipax"])
			else:
				location.name = "%s Army Base" % _surname(rng)
				location.short_name = "Army Base"
		&"business_pawnshop":
			var owner := _surname(rng)
			location.name = "%s's Pawnshop" % owner \
					if state.law.get_value(&"guncontrol") == Alignment.ELITE_LIBERAL \
					else "%s Pawn & Gun" % owner
			location.short_name = "Pawnshop"
		&"industry_warehouse":
			_name_until_unique(state, location, func():
				var entry: Array = Roll.pick(rng, LocationNameTables.WAREHOUSE)
				location.name = "Abandoned %s" % entry[0]
				location.short_name = entry[1])
		&"industry_polluter":
			_rename(location, Roll.pick(rng, LocationNameTables.POLLUTER))
		&"residential_apartment_upscale":
			_name_until_unique(state, location, func():
				var owner := _surname(rng)
				location.name = "%s Condominiums" % owner
				location.short_name = "%s Condos" % owner)
		&"residential_apartment":
			_name_until_unique(state, location, func():
				var owner := _surname(rng)
				location.name = "%s Apartments" % owner
				location.short_name = "%s Apts" % owner)
		&"residential_tenement":
			_name_until_unique(state, location, func():
				# A short street name, so the whole address fits the screen.
				var street := _surname(rng)
				while street.length() > 7:
					street = _surname(rng)
				location.name = "%s St. Housing Projects" % street
				location.short_name = "Projects")
		&"laboratory_genetic":
			location.name = "%s Genetics" % _surname(rng)
			location.short_name = "Genetics Lab"
		&"laboratory_cosmetics":
			location.name = "%s Cosmetics" % _surname(rng)
			location.short_name = "Cosmetics Lab"
		&"business_cardealership":
			location.name = "%s's Used Cars" % NamingRules.full_name(
					rng, Gender.WHITE_MALE_PATRIARCH)
			location.short_name = "Used Cars"
		&"business_deptstore":
			location.name = "%s's Department Store" % _surname(rng)
			location.short_name = "Dept. Store"
		&"industry_sweatshop":
			location.name = "%s Garment Makers" % _surname(rng)
			location.short_name = "Sweatshop"
		&"business_crackhouse":
			_name_until_unique(state, location, func(): _name_drug_house(state, rng, location))
		&"business_cigarbar":
			location.name = "The %s Gentlemen's Club" % _surname(rng)
			location.short_name = "Cigar Bar"
		&"outdoor_publicpark":
			location.name = "%s Park" % _surname(rng)
			location.short_name = "Park"


static func _name_prison(state: GameState, rng: Rng, location: Location) -> void:
	if state.law.get_value(&"prisons") != -2:
		location.name = "%s Prison" % _surname(rng)
		location.short_name = "Prison"
		return
	# Newspeak: a labour camp with a pleasant name.
	location.name = "%s %s Forced Labor Camp" % [
		Roll.pick(rng, LocationNameTables.JOYCAMP_FIRST),
		Roll.pick(rng, LocationNameTables.JOYCAMP_SECOND),
	]
	location.short_name = "Joycamp"


static func _name_drug_house(state: GameState, rng: Rng, location: Location) -> void:
	var street := _surname(rng)
	if state.law.get_value(&"drugs") == 2:
		var entry: Array = Roll.pick(rng, LocationNameTables.LEGAL_DRUG_HOUSE)
		location.name = "%s St. %s" % [street, entry[0]]
		location.short_name = entry[1]
	else:
		location.name = "%s St. Crack House" % street
		location.short_name = "Crack House"


## Rolls a name until no other place shares it.
static func _name_until_unique(state: GameState, location: Location,
		generate: Callable) -> void:
	while true:
		generate.call()
		if not _is_duplicate(state, location):
			return


## Whether another location already carries this name. Shelters are exempt in
## the original: a city may have several.
static func _is_duplicate(state: GameState, location: Location) -> bool:
	if location.type == &"residential_shelter":
		return false
	for other: Location in state.locations.values():
		if other != location and other.name == location.name:
			return true
	return false


static func _surname(rng: Rng) -> String:
	return NamingRules.last_name(rng, true)


static func _rename(location: Location, names: Array) -> void:
	location.name = names[0]
	location.short_name = names[1]
