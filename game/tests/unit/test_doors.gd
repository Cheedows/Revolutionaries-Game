extends TestCase
## Walking into doors.
##
## Built on a hand-made two-square site rather than a recorded one: what a door
## does depends on flags the generated plans rarely combine, and a fixture puts
## every combination within reach. The rules themselves come from open_door(),
## unlock() and bash() in the original.


func test_a_plain_door_just_opens() -> void:
	var fixture := _fixture(Tables.SITE_BLOCKS[&"door"])
	var events: Variant = _bump(fixture)
	equal(_types(events), ["door_opened"], "an unlocked door opens on a bump")
	check(not _is_still_a_door(fixture), "and stops being a door")


func test_a_vault_door_does_not_budge() -> void:
	var fixture := _fixture(Tables.SITE_BLOCKS[&"door"] | Tables.SITE_BLOCKS[&"metal"])
	var events: Variant = _bump(fixture)
	equal(_types(events), ["door_impenetrable"], "a vault door is not bumped open")
	check(_is_still_a_door(fixture), "and stays shut")


func test_an_alarmed_door_asks_first() -> void:
	var fixture := _fixture(Tables.SITE_BLOCKS[&"door"] | Tables.SITE_BLOCKS[&"alarmed"])
	var asked: Variant = _bump(fixture)
	check(asked is PendingIntent, "an alarmed door asks before it is opened")
	var question: PendingIntent = asked
	equal(question.intent.type, Intent.CONFIRM_NOISY_DOOR, "the question asked")

	# Declining leaves it alone.
	equal(_types(question.resume.call(false)), [], "saying no does nothing")
	check(_is_still_a_door(fixture), "and the door is still shut")

	# An emergency exit approached from the public side reads as locked from
	# the other side, so agreeing to the noise only gets you the next question.
	var forcing: Variant = question.resume.call(true)
	check(forcing is PendingIntent, "and then offers to force it")
	equal(forcing.intent.type, Intent.CONFIRM_FORCE_DOOR, "the second question")


func test_a_locked_door_is_picked_by_whoever_can() -> void:
	var fixture := _fixture(Tables.SITE_BLOCKS[&"door"] | Tables.SITE_BLOCKS[&"locked"])
	var member: Creature = fixture["member"]
	member.skills.set_value(&"security", 20)

	var asked: Variant = _bump(fixture)
	check(asked is PendingIntent, "a locked door asks whether to pick it")
	var question: PendingIntent = asked
	equal(question.intent.type, Intent.CONFIRM_PICK_LOCK, "the question asked")
	equal(_types(question.events), ["door_locked"], "and reports what it found")
	check(fixture["state"].site.map.get_flag(1, 0, 0) & Tables.SITE_BLOCKS[&"klock"],
			"trying the handle is enough to learn the door is locked")

	var events: Array[Event] = question.resume.call(true)
	equal(_types(events), ["door_unlocked"], "a locksmith opens it")
	check(not (fixture["state"].site.map.get_flag(1, 0, 0)
			& Tables.SITE_BLOCKS[&"locked"]), "and the lock is off")
	equal(_recorded(fixture), [&"unlockeddoor"] as Array[StringName],
			"picking a lock is a crime")
	equal(fixture["state"].site.alarm_timer, Doors.GRACE_PICKED,
			"and starts the clock on being noticed")


func test_a_locked_door_is_kicked_when_nobody_can_pick_it() -> void:
	var fixture := _fixture(Tables.SITE_BLOCKS[&"door"] | Tables.SITE_BLOCKS[&"locked"])
	# A crowbar removes the roll entirely, which is what makes the outcome of
	# this test something other than a coin flip.
	var member: Creature = fixture["member"]
	member.weapon = Weapon.new()
	member.weapon.type = &"WEAPON_CROWBAR"

	var asked: Variant = _bump(fixture)
	check(asked is PendingIntent, "with no lockpick the squad is asked to force it")
	var question: PendingIntent = asked
	equal(question.intent.type, Intent.CONFIRM_FORCE_DOOR, "the question asked")

	var events: Array[Event] = question.resume.call(true)
	equal(_types(events), ["door_opened"], "and a crowbar gets through")
	equal(fixture["state"].site.alarm_timer, Doors.GRACE_CROWBAR,
			"a crowbar is quiet enough to buy time")
	check(not _is_still_a_door(fixture), "leaving a doorway")
	equal(_recorded(fixture), [&"brokedowndoor"] as Array[StringName],
			"breaking a door is a crime")
	equal(fixture["state"].site.crime_level, 1, "and makes the visit worse")


func test_a_botched_pick_wrecks_the_lock() -> void:
	var fixture := _fixture(Tables.SITE_BLOCKS[&"door"] | Tables.SITE_BLOCKS[&"locked"])
	var member: Creature = fixture["member"]
	member.skills.set_value(&"security", 1)
	# A guard's door against a beginner: the roll cannot be won.
	fixture["state"].site.type = &"government_prison"

	var question: PendingIntent = _bump(fixture)
	var events: Array[Event] = question.resume.call(true)
	equal(_types(events), ["door_jammed"], "the lock defeats them")
	check(fixture["state"].site.map.get_flag(1, 0, 0) & Tables.SITE_BLOCKS[&"clock"],
			"and is wrecked for good")


## A site two squares wide: the squad on the left, the door on the right.
## What the story about this raid says the squad has done so far.
func _recorded(fixture: Dictionary) -> Array[StringName]:
	var state: GameState = fixture["state"]
	var done: Array[StringName] = []
	for index in state.current_story.crimes:
		done.append(Ids.CRIMES[index])
	return done


func _fixture(door_flags: int) -> Dictionary:
	var state := GameState.new()
	var squad := Squad.new()
	squad.id = 1
	state.squads[squad.id] = squad

	var member := Creature.new()
	member.id = 1
	member.alive = true
	state.creatures[member.id] = member
	squad.member_ids.append(member.id)

	var map := LevelMap.new()
	map.fill(0)
	map.set_flag(1, 0, 0, door_flags)
	state.site.map = map
	state.site.type = &"business_bank"
	# What a squad does inside is written onto the story about the raid.
	NewsQueue.open(state, &"squad_site", 1)
	state.site.x = 0
	state.site.y = 0
	state.site.z = 0

	var catalog := Catalog.new()
	catalog.load_all()
	return {"state": state, "squad": squad, "member": member,
			"catalog": catalog, "rng": Rng.new(4242)}


func _bump(fixture: Dictionary) -> Variant:
	# Stepping right walks the squad into the door, which is how the original
	# opens one: there is no separate "open" key.
	return SiteMovement.step(fixture["state"], fixture["squad"], Vector2i(1, 0),
			fixture["catalog"], fixture["rng"])


func _is_still_a_door(fixture: Dictionary) -> bool:
	return (fixture["state"].site.map.get_flag(1, 0, 0)
			& Tables.SITE_BLOCKS[&"door"]) != 0


func _types(events: Variant) -> Array:
	var names := []
	for event: Event in events:
		names.append(String(event.type))
	return names
