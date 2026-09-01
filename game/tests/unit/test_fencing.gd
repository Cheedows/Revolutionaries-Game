extends TestCase
## Going through the stores one thing at a time.
##
## `Shopping.sell_chosen` was ported and called by nothing: a fence would take
## every weapon in the house or none of them, and the one incriminating thing
## could not be got rid of on its own. The Intent for it was declared and never
## raised either.

var _catalog: Catalog


func test_the_counter_offers_to_go_through_the_stores() -> void:
	var session := _a_fence()
	var opened: Variant = _open(session)
	check(opened is PendingIntent, "the counter asked something")
	var labels := _labels((opened as PendingIntent).intent)
	check(labels.has("Go through the stores"),
			"and offered to go through the stores, got %s" % [labels])
	_close(session)


func test_one_thing_can_be_sold_on_its_own() -> void:
	var session := _a_fence()
	var home := _home(session)
	var before := home.ground_loot.size()
	var funds := session.state.ledger.funds

	var counter: PendingIntent = _open(session)
	var picking: Variant = counter.resume.call(ShopVisit.PICK)
	check(picking is PendingIntent, "the stores opened")
	var intent := (picking as PendingIntent).intent
	equal(intent.type, Intent.CHOOSE_ITEMS_TO_FENCE, "one thing at a time")
	check(not intent.options.is_empty(), "with something in them")

	(picking as PendingIntent).resume.call(intent.options[0]["id"])
	equal(home.ground_loot.size(), before - 1, "one thing went")
	check(session.state.ledger.funds > funds, "and was paid for")
	_close(session)


func test_walking_away_leaves_the_stores_alone() -> void:
	var session := _a_fence()
	var home := _home(session)
	var before := home.ground_loot.size()
	var counter: PendingIntent = _open(session)
	var picking: PendingIntent = counter.resume.call(ShopVisit.PICK)
	picking.resume.call(null)
	equal(home.ground_loot.size(), before, "nothing was sold")
	_close(session)


## A squad standing in a pawnshop with things to sell at home.
func _a_fence() -> Session:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()
	var session := Session.new(31)
	Commands.start_new_game(session, PackedInt32Array(),
			{&"win_condition": &"elite_liberal", &"field_skill_rate": &"fast"})
	session.drain_events()
	var home := _home(session)
	for kind in [&"LOOT_CELLPHONE", &"LOOT_COMPUTER", &"LOOT_ART"]:
		home.ground_loot.append(Loot.new(kind))
	return session


func _home(session: Session) -> Location:
	var founder: Creature = session.state.members()[0]
	return session.state.locations.get(founder.base)


## Opens the pawnshop's counter.
func _open(session: Session) -> Variant:
	var squad := session.state.active_squad()
	var shop: Location = null
	for site: Location in session.state.locations.values():
		if site.type == &"business_pawnshop":
			shop = site
			break
	if shop == null:
		fail("the city has no pawnshop")
		return null
	return ShopVisit.open(session.state, session.rng, squad, shop, _catalog)


func _close(session: Session) -> void:
	session.state.site.location = -1


func _labels(intent: Intent) -> Array[String]:
	var found: Array[String] = []
	for option: Dictionary in intent.options:
		found.append(String(option["label"]))
	return found
