extends TestCase
## The skill readout: the decimal, the cap, and which ones are about to go up.
##
## The arithmetic is the original's, from displaycreaturestats() in
## src/common/commondisplay.cpp:
##
##     addstr_f("%2d.", get_skill(s));
##     if(get_skill_ip(s) < 100 + 10 * get_skill(s))
##        ... (get_skill_ip(s) * 100) / (100 + (10 * get_skill(s)))
##     else addstr("99+");
##
## Integer division throughout, and the fraction is how far the bank has got
## toward the next level rather than a hundredth of a level.


func test_the_decimal_is_the_originals_arithmetic() -> void:
	# Level 0 needs 100, so a bank of 42 is 42 per cent of the way.
	equal(SkillText.reading(0, 0), "0.00", "nothing banked")
	equal(SkillText.reading(0, 42), "0.42", "toward the first level")
	# Level 3 needs 130, so 42 of it is 32 per cent — not 42.
	equal(SkillText.reading(3, 42), "3.32", "the bar gets longer as it goes")
	equal(SkillText.reading(3, 129), "3.99", "and the last of it is 99")
	# Over the line and waiting for the day to turn.
	equal(SkillText.reading(3, 130), "3.99+", "banked enough to go up")
	equal(SkillText.reading(3, 400), "3.99+", "and more than enough")
	# Integer division, floor, exactly as the C does it.
	equal(SkillText.reading(1, 109), "1.99", "109 of 110 is 99 per cent")
	equal(SkillText.reading(1, 1), "1.00", "and one of 110 is none of it")


func test_a_skill_is_capped_by_the_attribute_that_governs_it() -> void:
	var who := _somebody()
	who.attributes.set_value(&"agility", 5)
	who.attributes.set_value(&"intelligence", 11)
	var found := {}
	for row: Dictionary in SkillText.rows(who):
		found[row["name"]] = row
	# Martial arts is governed by agility, law by intelligence.
	equal(String(found[StatText.skill(&"handtohand")]["cap"]), "5.00",
			"a physical skill is capped by agility")
	equal(String(found[StatText.skill(&"law")]["cap"]), "11.00",
			"and a studied one by intelligence")


func test_every_skill_is_listed_even_the_ones_at_nothing() -> void:
	var rows := SkillText.rows(_somebody())
	equal(rows.size(), Ids.SKILLS.size(),
			"the whole list, got %d" % rows.size())


func test_the_four_states_read_apart() -> void:
	var who := _somebody()
	who.attributes.set_value(&"agility", 4)
	var index := Ids.SKILLS.find(&"handtohand")

	who.skills.values[index] = 0
	who.skills.experience[index] = 0
	equal(_state_of(who, &"handtohand"), SkillText.NONE, "not started")

	who.skills.values[index] = 2
	equal(_state_of(who, &"handtohand"), SkillText.KNOWN, "under way")

	who.skills.experience[index] = 120
	equal(_state_of(who, &"handtohand"), SkillText.READY,
			"banked past the line")

	who.skills.values[index] = 4
	equal(_state_of(who, &"handtohand"), SkillText.MAXED,
			"at what agility allows")


func test_the_squad_line_knows_when_somebody_is_about_to_improve() -> void:
	var who := _somebody()
	who.attributes.set_value(&"agility", 9)
	check(not SkillText.any_ready([who]), "nobody is, to begin with")
	who.skills.experience[Ids.SKILLS.find(&"handtohand")] = 100
	check(SkillText.any_ready([who]), "and then somebody is")


## Which state the row for [param skill] is in.
func _state_of(who: Creature, skill: StringName) -> StringName:
	for row: Dictionary in SkillText.rows(who):
		if row["name"] == StatText.skill(skill):
			return row["state"]
	return &""


func _somebody() -> Creature:
	var who := Creature.new()
	who.age = 30
	for attribute: StringName in Ids.ATTRIBUTES:
		who.attributes.set_value(attribute, 5)
	return who
