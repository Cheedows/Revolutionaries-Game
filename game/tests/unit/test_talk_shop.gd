extends TestCase
## Diffs the conversations that are not a fight against the original.
##
## The guard dog, the thing in the tank, giving up a room, renting one — paid
## for, refused or extorted — and the bank teller, robbed quietly or at
## gunpoint. Against three squad sizes, three grades of kindness and
## persuasion, an armed Liberal in the room or none, a place that pays for
## security or not, funds enough for the rent or not, and a Squad the news has
## heard of or not.
##
## Compared on draw counts, the branch taken, the tenancy and everything that
## goes with it, the money, the alarm and its clock, the crime sheet, who is in
## the room and whose side they are on, what the squad walked out with, and
## where everybody who lived there ended up.

const PROBE := "res://tests/golden/probes/talk_shop.jsonl.gz"

const DOG := 0
const MONSTER := 1
const CANCEL := 2
const RENT := 3
const TELLER := 4

## Ids the probe assigns by hand start here; anything below was spawned during
## the sample and cannot be matched by id.
const PROBE_ID := 900000

var _catalog: Catalog


func test_the_conversations_go_the_same_way() -> void:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()

	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return
	for sample: Dictionary in samples:
		if not _talk_matches(sample):
			return


func _talk_matches(sample: Dictionary) -> bool:
	var chase: Object = (load("res://tests/unit/test_chase.gd") as GDScript).new()
	var state := _world(sample)
	var rng: Rng = chase._rng_at(sample)
	var where := "scenario %s which=%s choice=%s crowd=%s heart=%s armed=%s secure=%s rich=%s cherry=%s" \
			% [sample["scenario"], sample["which"], sample["choice"],
			sample["crowd"], sample["heart"], sample["armed"],
			sample["secure"], sample["rich"], sample["cherry"]]

	var squad := Squad.new()
	squad.id = 1
	state.squads[squad.id] = squad
	state.active_squad_id = squad.id
	var members: Array[Creature] = []
	for entry: Dictionary in sample["squad"]:
		var member := _restore(state, chase, entry)
		member.squad_id = squad.id
		squad.member_ids.append(member.id)
		members.append(member)
	var resident := _restore(state, chase, sample["resident"])
	var listener: Creature = null
	for entry: Dictionary in sample["room"]:
		var person := _restore(state, chase, entry)
		state.site.encounter_ids.append(person.id)
		if listener == null:
			listener = person

	NewsQueue.open(state, &"squad_site", int(sample["site"]), 0)

	var choice := int(sample["choice"])
	match int(sample["which"]):
		DOG:
			AnimalTalk.to_dog(state, rng, squad, listener)
		MONSTER:
			AnimalTalk.to_monster(state, rng, squad, listener)
		CANCEL:
			LandlordTalk.cancel(state)
		RENT:
			var offer := LandlordTalk.offer(state, rng, members[0], listener,
					_catalog)
			# A squad that cannot afford the rent has that option greyed out,
			# and the original simply ignores the keystroke.
			if choice != LandlordTalk.ACCEPT \
					or bool(offer.intent.options[0]["enabled"]):
				offer.resume.call(choice)
		_:
			var counter := BankTellerTalk.approach(state, rng, members[0],
					listener, _catalog)
			counter.resume.call(choice)

	if rng.draws != int(sample["draws"]):
		return _diverged(where, "draws", sample["draws"], rng.draws)
	if not _place_matches(where, sample, state):
		return false
	if not _room_matches(where, sample, state):
		return false
	return _people_match(where, sample, state, members, resident)


## The building: the tenancy, what is left in it, and what is going on.
func _place_matches(where: String, sample: Dictionary,
		state: GameState) -> bool:
	var site: Location = state.locations.get(int(sample["site"]))
	if site.renting != int(sample["renting"]):
		return _diverged(where, "the tenancy", sample["renting"], site.renting)
	if site.new_rental != (int(sample["newrental"]) != 0):
		return _diverged(where, "a new tenancy", sample["newrental"],
				site.new_rental)
	if site.compound_walls != int(sample["walls"]) \
			or site.compound_stores != int(sample["stores"]) \
			or site.front_business != int(sample["front"]):
		return _diverged(where, "what was built here",
				[sample["walls"], sample["stores"], sample["front"]],
				[site.compound_walls, site.compound_stores,
				site.front_business])
	if site.ground_loot.size() != int(sample["site_loot"]):
		return _diverged(where, "what is left here", sample["site_loot"],
				site.ground_loot.size())
	var shelter: Location = state.locations.get(int(sample["shelter"]))
	if shelter != null \
			and shelter.ground_loot.size() != int(sample["shelter_loot"]):
		return _diverged(where, "what reached the shelter",
				sample["shelter_loot"], shelter.ground_loot.size())

	var siege: Siege = state.sieges.get(site.id)
	var located: int = siege.time_until_located if siege != null else -1
	if located != int(sample["located"]):
		return _diverged(where, "how long before the police",
				sample["located"], located)
	if state.ledger.funds != int(sample["funds_after"]):
		return _diverged(where, "funds", sample["funds_after"],
				state.ledger.funds)
	if state.site.alarm != (int(sample["alarm"]) != 0):
		return _diverged(where, "alarm", sample["alarm"], state.site.alarm)
	if state.site.alarm_timer != int(sample["alarmtimer"]):
		return _diverged(where, "alarm clock", sample["alarmtimer"],
				state.site.alarm_timer)
	if state.site.alienated != int(sample["alienate"]):
		return _diverged(where, "alienation", sample["alienate"],
				state.site.alienated)
	if state.site.crime_level != int(sample["crime"]):
		return _diverged(where, "how bad the visit got", sample["crime"],
				state.site.crime_level)

	var crimes: Array = sample["crimes"]
	if state.current_story.crimes.size() != crimes.size():
		return _diverged(where, "crimes recorded", crimes.size(),
				state.current_story.crimes.size())
	for slot in crimes.size():
		if state.current_story.crimes[slot] != int(crimes[slot]):
			return _diverged(where, "crime %d" % slot,
					Ids.CRIMES[int(crimes[slot])],
					Ids.CRIMES[state.current_story.crimes[slot]])
	return true


func _room_matches(where: String, sample: Dictionary,
		state: GameState) -> bool:
	var left: Array = sample["left"]
	var aligns: Array = sample["aligns"]
	var types: Array = sample["types"]
	if state.site.encounter_ids.size() != left.size():
		return _diverged(where, "who is in the room", left,
				Array(state.site.encounter_ids))
	for slot in left.size():
		var person: Creature = state.creatures.get(
				state.site.encounter_ids[slot])
		# Somebody the probe placed is matched by id; somebody the robbery
		# spawned is matched by what they are, since the two id counters have
		# nothing to do with each other.
		var placed := int(left[slot]) >= PROBE_ID
		if placed and state.site.encounter_ids[slot] != int(left[slot]):
			return _diverged(where, "who is standing in slot %d" % slot,
					left[slot], state.site.encounter_ids[slot])
		if not placed and person.type != Ids.CREATURE_TYPES[int(types[slot])]:
			return _diverged(where, "what is standing in slot %d" % slot,
					Ids.CREATURE_TYPES[int(types[slot])], person.type)
		if Alignment.value_of(person.alignment) != int(aligns[slot]):
			return _diverged(where, "whose side %d is on" % slot,
					aligns[slot], person.alignment)
	var listener: Creature = state.creatures.get(int(left[0])) \
			if not left.is_empty() else null
	if listener != null and listener.cannot_bluff != int(sample["cantbluff"]):
		return _diverged(where, "whether they can still be bluffed",
				sample["cantbluff"], listener.cannot_bluff)
	return true


func _people_match(where: String, sample: Dictionary, state: GameState,
		members: Array[Creature], resident: Creature) -> bool:
	var squad := state.active_squad()
	var cash := 0
	for item: Item in squad.haul:
		if item is Money:
			cash += item.count
	if cash != int(sample["cash"]):
		return _diverged(where, "money taken", sample["cash"], cash)

	var after: Array = sample["squad_after"]
	for index in after.size():
		var want: Dictionary = after[index]
		var member := members[index]
		var at := "%s liberal %d" % [where, index]
		if member.base != int(want["base"]) \
				or member.location != int(want["location"]):
			return _diverged(at, "where they live and stand",
					[want["base"], want["location"]],
					[member.base, member.location])
		var suspected: Array = want["suspected"]
		for flag in suspected.size():
			if member.crimes_suspected[flag] != int(suspected[flag]):
				return _diverged(at, "charge %s" % Ids.LAW_FLAGS[flag],
						suspected[flag], member.crimes_suspected[flag])

	var lodger: Dictionary = sample["resident_after"]
	if resident.base != int(lodger["base"]) \
			or resident.location != int(lodger["location"]):
		return _diverged(where, "where the lodger went",
				[lodger["base"], lodger["location"]],
				[resident.base, resident.location])
	return true


func _restore(state: GameState, chase: Object, entry: Dictionary) -> Creature:
	var person: Creature = chase._person(state, {}, entry)
	state.creatures.erase(person.id)
	person.id = int(entry["id"])
	state.creatures[person.id] = person
	return person


func _diverged(where: String, field: String, expected: Variant,
		actual: Variant) -> bool:
	fail("%s: %s expected %s, got %s" % [where, field, expected, actual])
	return false


func _world(sample: Dictionary) -> GameState:
	var state := GameState.new()
	state.endgame_state = &"none"
	state.field_skill_rate = &"classic"
	state.mode = &"site"
	WorldBuilder.build(state, Rng.new(int(sample["world_seed"])), false)
	var laws: Array = sample["law"]
	for index in laws.size():
		state.law.values[index] = int(laws[index])
	var attitude: Array = sample["attitude"]
	var interest: Array = sample["interest"]
	for index in attitude.size():
		state.opinion.attitude[index] = int(attitude[index])
		state.opinion.interest[index] = int(interest[index])
		state.opinion.background_influence[index] = 0
	state.stats[&"newscherrybusted"] = 2 if int(sample["cherry"]) != 0 else 0
	state.ledger.funds = int(sample["funds"])

	var which := int(sample["which"])
	var site: Location = state.locations.get(int(sample["site"]))
	site.type = &"business_bank" if which == TELLER \
			else (&"residential_apartment" if which >= CANCEL
			else &"corporate_headquarters")
	site.high_security = int(sample["secure"]) != 0
	site.renting = 500 if which == CANCEL else Renting.NOBODY
	site.rented_by = Renting.name_of(site.renting)
	site.compound_walls = int(Tables.COMPOUND[&"printingpress"])
	site.compound_stores = 1
	site.front_business = 0
	site.new_rental = false
	site.ground_loot.clear()
	var cash := Money.new()
	cash.count = 750
	site.ground_loot.append(cash)
	site.ground_loot.append(Loot.new(&"LOOT_CORPFILES"))

	state.site.location = site.id
	state.site.type = site.type
	state.site.alarm = false
	state.site.alarm_timer = -1
	state.site.crime_level = 0
	state.site.alienated = 0
	state.site.x = 3
	state.site.y = 3
	state.site.z = 0
	state.site.map = LevelMap.new()
	state.site.map.fill(0)
	return state
