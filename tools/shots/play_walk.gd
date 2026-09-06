extends RefCounted
## Production navigation for the rendered layout gate. Every menu step is a tap.

static func press(tree: SceneTree, play: PlayScreen, said: String) -> void:
	var session: Session = play.get("_session")
	var button: Button
	match said:
		"response":
			await UiDriver.tap(tree, answer(play.get_child(0)._dialog, SiteTalk.DISTURBING))
			return
		"inventory":
			await UiDriver.tap(tree, answer(play.get_child(0)._dialog, SiteActionDialog.INVENTORY))
			return
		"people":
			for i in 8:
				if not session.state.site.encounter_ids.is_empty():
					break
				await UiDriver.tap(tree, answer(play.get_child(0)._dialog, SiteLoop.WAIT))
			return
		"conversation":
			await UiDriver.tap(tree, play.get_child(0)._people._list.get_child(0))
			return
		"goods":
			await UiDriver.tap(tree, answer(play.get_child(0)._dialog, "in:0"))
			return
		"travel":
			button = UiDriver.button(play, "Choose destination")
		"dossier":
			button = UiDriver.button(play, "Look")
		"surgery":
			button = UiDriver.button(play, "Augmentation")
		"activity":
			button = UiDriver.button(play, ActivityText.of(session.state.members()[0].activity))
		"vehicles":
			button = UiDriver.button(play, "Choosing the Right Liberal Vehicle")
		"pawn", "department", "site", "hospital":
			await _visit(tree, play, said)
			return
		"trial", "appointment":
			var person := session.state.members()[0]
			var candidate := session.state.add_creature(Creature.new())
			candidate.name = "Morgan"
			candidate.alignment = &"liberal"
			candidate.location = person.base
			person.crimes_suspected.fill(2)
			var intent := Intent.new(Intent.CHOOSE_DEFENSE, Trial._options(session.state, null),
					{"creature": person.id}, false)
			if said == "appointment":
				intent = Intent.new(Intent.CONFIRM_RECRUIT, RecruitQueue._approaches(true, true),
						{"creature": person.id, "recruit": candidate.id,
						"profession": "Teacher", "eagerness": 4}, false)
			session.ask(PendingIntent.new(intent, func(_id: Variant) -> Variant:
				return [] as Array[Event]))
			await UiDriver.settle(tree)
			return
		"decision":
			var intent := Intent.new(Intent.CHOOSE_BASE_ACTION,
					[{"id": &"visit", "label": "Take a look inside"}] as Array[Dictionary], {}, true)
			session.ask(PendingIntent.new(intent, func(_id: Variant) -> Variant:
				return [] as Array[Event]))
			await UiDriver.settle(tree)
			return
		"ending":
			session.state.endgame_state = &"won"
			await UiDriver.settle(tree)
			return
		"site_fight":
			await press(tree, play, "people")
			session.state.site.alarm = true
			await UiDriver.tap(tree, answer((play.get_child(0) as SiteScreen)._dialog, SiteLoop.RELOAD))
			await UiDriver.settle(tree)
			return
		"combat":
			var enemy := session.state.add_creature(Creature.new())
			enemy.name = "An armed guard"
			enemy.alignment = &"conservative"
			enemy.weapon = Weapon.new(&"WEAPON_SEMIPISTOL_9MM")
			session.state.site.encounter_ids.append(enemy.id)
			var intent := Intent.new(Intent.CHOOSE_ATTACK_TARGET,
					[{"id": enemy.id, "label": enemy.name}] as Array[Dictionary], {}, false)
			session.ask(PendingIntent.new(intent, func(_id: Variant) -> Variant:
				return [] as Array[Event]))
			await UiDriver.settle(tree)
			return
		_:
			var home := play.get_child(0) as SafehouseScreen
			if home != null:
				button = home._buttons.get(StringName(said))
	assert(button != null, "No visible production control for " + said)
	if button != null:
		await UiDriver.tap(tree, button)


static func _visit(tree: SceneTree, play: PlayScreen, kind: String) -> void:
	var session: Session = play.get("_session")
	var site := _site(session, kind)
	assert(site != null, "The fixture has a " + kind + " destination")
	if site == null:
		return
	if kind == "hospital":
		var member: Creature = session.state.squad_members(session.state.active_squad())[0]
		member.body.blood = 20
		member.body.add_wound(&"arm_left", Wound.SHOT | Wound.BLEEDING)
	await press(tree, play, "travel")
	var path: Array[int] = []
	var here := site
	while here != null:
		path.push_front(here.id)
		here = session.state.locations.get(here.parent)
	for id: int in path:
		var destination := play.get_child(0) as DestinationScreen
		assert(destination != null, "Travel opened the destination page")
		if destination == null:
			return
		var dialog: IntentDialog = destination.get("_dialog")
		var button: Button = answer(dialog, id)
		assert(button != null, "The destination is offered")
		if button == null:
			return
		await UiDriver.tap(tree, button)
	var home := play.get_child(0) as SafehouseScreen
	assert(home != null, "The travel order returned home")
	if home != null:
		await UiDriver.tap(tree, home._wait_button)


static func answer(dialog: IntentDialog, id: Variant) -> Button:
	var ids: Dictionary = dialog.get("_ids")
	for button: Button in ids:
		if DialogKeys.same(ids[button], id):
			return button
	return null


static func _site(session: Session, kind: String) -> Location:
	var squad := session.state.active_squad()
	for site: Location in session.state.locations.values():
		if kind == "department" and site.type == &"business_deptstore":
			return site
		if kind == "pawn" and site.type == &"business_pawnshop":
			return site
		if kind == "hospital" and site.type == &"hospital_clinic":
			return site
		if kind != "site" or site.hidden or site.closed > 0:
			continue
		if Destination.has_children(session.state, site) or ShopVisit.SHOPS.has(site.type):
			continue
		if site.type in [&"hospital_clinic", &"hospital_university"] or Renting.is_ours(site.renting):
			continue
		if String(site.type).begins_with("city_"):
			continue
		if Destination.can_go(session.state, squad, site):
			return site
	return null


static func add_patient(session: Session) -> void:
	var surgeon: Creature = session.state.members()[0]
	var patient := session.state.add_creature(Creature.new())
	patient.name = "A second member"
	patient.enlisted = true
	patient.alignment = &"liberal"
	patient.age = 30
	patient.location = surgeon.location
	patient.base = surgeon.base
