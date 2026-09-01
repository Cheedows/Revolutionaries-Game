extends TestCase
## Hands the squad its gear and checks it went where it should.
##
## The original's equip screen is a grid of letters; the rules under it are
## what matters — that ammunition needs a gun that takes it, that dressing
## somebody takes off what they had on, that a stack of knives goes behind the
## one in the hand, and that a pile is always squashed back together.

var _catalog: Catalog


func _load() -> void:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()


func test_a_pile_is_squashed_and_sorted() -> void:
	_load()
	var pile: Array[Item] = [
		Clip.new(&"CLIP_9", 2), Weapon.new(&"WEAPON_SEMIPISTOL_9MM"),
		Clip.new(&"CLIP_9", 3), Armor.new(&"ARMOR_CLOTHES"),
	]
	LootPile.consolidate(pile, _catalog)
	equal(pile.size(), 3, "the two boxes of ammunition became one")
	equal(String(pile[0].item_class()), "weapon", "weapons come first")
	equal(String(pile[1].item_class()), "armor", "then what is worn")
	equal(String(pile[2].item_class()), "clip", "then what it is loaded with")
	equal(pile[2].count, 5, "and the count is the two counts")


func test_a_gun_and_its_ammunition() -> void:
	_load()
	var state := GameState.new()
	var member := state.add_creature(Creature.new())
	var pile: Array[Item] = [Clip.new(&"CLIP_9", 4)]

	equal(Equipping.give(member, pile[0], pile, _catalog),
			"Can't carry ammo without a gun.", "ammunition needs a gun")

	var gun := Weapon.new(&"WEAPON_SEMIPISTOL_9MM")
	pile.append(gun)
	equal(Equipping.give(member, gun, pile, _catalog), "", "the gun goes over")
	equal(member.weapon.type, &"WEAPON_SEMIPISTOL_9MM", "and is in their hand")

	var clip: Item = pile[0]
	equal(Equipping.give(member, clip, pile, _catalog), "", "and now the ammo")
	equal(EquipmentRules.count_clips(member), 1, "one box of it")
	equal(clip.count, 3, "and three left in the pile")


func test_dressing_somebody_takes_off_what_they_had_on() -> void:
	_load()
	var member := Creature.new()
	var pile: Array[Item] = [Armor.new(&"ARMOR_CLOTHES"),
			Armor.new(&"ARMOR_TRENCHCOAT")]
	equal(Equipping.give(member, pile[0], pile, _catalog), "", "clothes on")
	var coat: Item = pile[0]
	equal(Equipping.give(member, coat, pile, _catalog), "", "then a coat")
	equal(member.armor.type, &"ARMOR_TRENCHCOAT", "the coat is what they wear")
	var back := false
	for item: Item in pile:
		if item.type == &"ARMOR_CLOTHES":
			back = true
	check(back, "and the clothes are back in the pile")


func test_a_broken_neck_cannot_be_handed_anything() -> void:
	_load()
	var member := Creature.new()
	member.body.set_special(&"neck", 0)
	var pile: Array[Item] = [Weapon.new(&"WEAPON_SEMIPISTOL_9MM")]
	equal(Equipping.give(member, pile[0], pile, _catalog),
			"They cannot hold it.", "nothing to hold it with")
	check(member.weapon == null, "so they are still empty handed")


func test_stripping_and_disarming() -> void:
	_load()
	var member := Creature.new()
	var pile: Array[Item] = []
	member.armor = Armor.new(&"ARMOR_CLOTHES")
	member.weapon = Weapon.new(&"WEAPON_SEMIPISTOL_9MM")
	member.clips.append(Clip.new(&"CLIP_9", 2))

	Equipping.disarm(member, pile, _catalog)
	check(member.weapon == null and member.clips.is_empty(),
			"the gun and the ammunition are down")
	equal(pile.size(), 2, "and both are in the pile")

	Equipping.strip(member, pile, _catalog)
	check(member.armor == null, "and now the clothes too")


func test_things_move_between_the_squad_and_the_safehouse() -> void:
	_load()
	var squad: Array[Item] = [Clip.new(&"CLIP_9", 5)]
	var house: Array[Item] = []
	Equipping.move(squad, house, {0: 2}, _catalog)
	equal(house.size(), 1, "two boxes were stashed")
	equal(house[0].count, 2, "as one stack of two")
	equal(squad[0].count, 3, "and three are still with the squad")

	Equipping.move(squad, house, {0: 3}, _catalog)
	check(squad.is_empty(), "the rest goes too")
	equal(house[0].count, 5, "and the two stacks became one")


func test_the_commands_refuse_somebody_who_is_not_there() -> void:
	_load()
	var session := Session.new(1)
	var stranger := session.state.add_creature(Creature.new())
	equal(KitCommands.equip(session, stranger, Weapon.new(&"WEAPON_SEMIPISTOL_9MM")),
			"They are not with the squad.", "the squad is who this is for")


func test_a_tailor_is_told_what_to_sew() -> void:
	_load()
	var state := GameState.new()
	check(AssignmentChoice.needs_more(&"make_armor"), "sewing needs a garment")
	check(not AssignmentChoice.needs_more(&"donations"),
			"and soliciting does not")

	var choices := AssignmentChoice.garments(state, _catalog)
	check(choices.size() > 3, "there are things to make, got %d" % choices.size())
	for garment: StringName in choices:
		var type: ArmorType = _catalog.get_entry(&"armor", garment)
		check(type.make_difficulty > 0, "%s can actually be made" % garment)
		check(not type.deathsquad_legality,
				"%s is not the death squad's own" % garment)

	var tailor := Creature.new()
	AssignmentChoice.choose(tailor, &"make_armor", choices[0])
	equal(tailor.making, choices[0], "and they know what to work on")


func test_the_death_squad_uniform_needs_a_death_squad() -> void:
	_load()
	var state := GameState.new()
	state.law.values[Ids.LAWS.find(&"policebehavior")] = Law.ARCH_CONSERVATIVE
	state.law.values[Ids.LAWS.find(&"deathpenalty")] = Law.ARCH_CONSERVATIVE
	var harsh := AssignmentChoice.garments(state, _catalog)
	var mild := AssignmentChoice.garments(GameState.new(), _catalog)
	check(harsh.size() > mild.size(),
			"a country with death squads has one more uniform to sew")
