extends TestCase

func test_siege_defense_starts_and_retains_site_turns() -> void:
	var s := Commands.roll_a_game(6161)
	var home: Location = s.state.locations[s.state.members()[0].base]
	var siege := Siege.new()
	siege.active = true
	siege.underway = true
	s.state.sieges[home.id] = siege
	Commands.answer_siege(s, home)
	check(s.is_waiting(), "defense has a playable decision")
	if not s.is_waiting():
		return
	equal(s.pending().intent.type, Intent.CHOOSE_SITE_MOVE, "defense starts site controls")
	s.answer(SiteLoop.WAIT)
	check(s.is_waiting(), "defense continues after an action")

func test_hospital_decline_returns_squad_home() -> void:
	var s := Commands.roll_a_game(6161)
	var member: Creature = s.state.squad_members(s.state.active_squad())[0]
	var home := member.base
	member.body.blood = 50
	var hospital: Location
	for place: Location in s.state.locations.values():
		if place.type == &"hospital_clinic":
			hospital = place
			break
	s.state.active_squad().travel_destination = hospital.id
	Commands.advance_day(s, false)
	equal(s.pending().intent.options[0].note, "2 months", "treatment is measured in months")
	s.answer(0)
	equal(member.location, home, "declining admission returns the member home")
	equal(s.state.active_squad().location, home, "squad address returns home")
	equal(member.clinic, 0, "declining does not admit the member")

func _site(seed_value: int) -> Session:
	var s := Commands.roll_a_game(seed_value)
	var site: Location
	for place: Location in s.state.locations.values():
		if place.type == &"business_juicebar":
			site = place
			break
	SiteEntry.enter(s.state,s.state.active_squad(),site,s.catalog,s.rng)
	s.state.site.map = LevelMap.new()
	s.state.site.map.fill(0)
	s.state.site.x = 10
	s.state.site.y = 10
	return s

func test_site_actions_advance_bodies_and_attack_once() -> void:
	var s := _site(6161)
	var member: Creature = s.state.squad_members(s.state.active_squad())[0]
	member.body.blood = 70
	member.body.add_wound(&"arm_left",Wound.SHOT | Wound.BLEEDING)
	s.submit(SiteLoop.turn(s.state,s.rng,s.state.active_squad(),s.catalog))
	s.answer(SiteLoop.WAIT)
	equal(member.body.blood, 69, "Wait advances bleeding exactly once")
	CombatAdvance.everyone(s.state,s.rng,s.state.active_squad(),{&"mode": &"site",&"catalog":s.catalog})
	equal(member.body.blood, 68, "the next body tick still advances bleeding")
	s = _site(42)
	member = s.state.squad_members(s.state.active_squad())[0]
	member.body.blood = 1000
	var enemy := s.state.add_creature(Creature.new())
	enemy.type = &"CREATURE_COP"
	enemy.alignment = &"conservative"
	enemy.juice = 1000
	enemy.body.blood = 1000
	enemy.attributes.set_value(&"heart",20)
	enemy.attributes.set_value(&"wisdom",20)
	enemy.weapon = Weapon.new(&"WEAPON_NIGHTSTICK")
	s.state.site.encounter_ids.append(enemy.id)
	s.state.site.alarm = true
	s.submit(SiteLoop.turn(s.state,s.rng,s.state.active_squad(),s.catalog))
	s.answer(SiteLoop.FIGHT)
	var attacks := 0
	for event in s.drain_events():
		if event.type == Event.ATTACK_MADE and event.data.get("attacker") == enemy.id:
			attacks += 1
	equal(attacks, 1, "one Attack permits one enemy retaliation")
	equal(s.state.site.encounter_timer, 1, "Attack advances the encounter timer once")


func test_hospital_admission_keeps_patient_and_returns_others() -> void:
	var s := Commands.roll_a_game(6161)
	var squad := s.state.active_squad()
	var patient := s.state.squad_members(squad)[0]
	var other := s.state.add_creature(Creature.new())
	other.alignment = &"liberal"
	other.base = patient.base
	other.location = patient.base
	other.squad_id = squad.id
	squad.member_ids.append(other.id)
	patient.body.blood = 50
	var hospital: Location
	for place: Location in s.state.locations.values():
		if place.type == &"hospital_clinic":
			hospital = place
			break
	squad.travel_destination = hospital.id
	s.submit(SquadTurn.run(s.state, s.rng, s.catalog))
	s.answer(patient.id)
	equal(patient.location, hospital.id, "admitted patient stays in hospital")
	equal(patient.clinic, 2, "patient receives two months of treatment")
	equal(other.location, other.base, "non-patient returns home")

func test_movement_pickup_and_reload_advance_bleeding() -> void:
	for action in [SiteLoop.MOVE_RIGHT, SiteLoop.TAKE, SiteLoop.RELOAD]:
		var s := _site(6161)
		var member := s.state.squad_members(s.state.active_squad())[0]
		member.body.blood = 70
		member.body.add_wound(&"arm_left", Wound.SHOT | Wound.BLEEDING)
		s.state.site.ground_loot.append(Loot.new(&"LOOT_CELLPHONE"))
		s.submit(SiteLoop.turn(s.state, s.rng, s.state.active_squad(), s.catalog))
		s.answer(action)
		equal(member.body.blood, 69, "site action %d advances bleeding once" % action)
