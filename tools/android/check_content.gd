extends SceneTree
## Run against the exported APK's assets, never the editor project.

func _initialize() -> void:
	var session := Commands.roll_a_game(6161)
	var failed := false
	for kind: StringName in Catalog.DIRECTORIES:
		var count := session.catalog.idnames(kind).size()
		print("Packaged ", kind, ": ", count)
		if count == 0:
			failed = true
	var state := session.state
	var squad := state.active_squad()
	for kind: StringName in ShopVisit.SHOPS:
		var place := Location.new()
		place.type = kind
		var result: Variant = ShopVisit.open(state, session.rng, squad, place, session.catalog)
		if not result is PendingIntent:
			push_error("Packaged shop failed: " + String(kind))
			failed = true
	var apartment := Location.new()
	apartment.id = state.locations.size() + 100
	apartment.type = &"residential_apartment"
	state.locations[apartment.id] = apartment
	SiteEntry.enter(state, squad, apartment, session.catalog, session.rng)
	var turn: PendingIntent = SiteLoop.turn(state, session.rng, squad, session.catalog)
	turn.resume.call(SiteLoop.WAIT)
	if state.site.encounter_ids.is_empty():
		push_error("Packaged apartment produces no people after waiting")
		failed = true
	print("Packaged shops and apartment encounter: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
