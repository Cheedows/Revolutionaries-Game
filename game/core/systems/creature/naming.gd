class_name NamingRules
extends RefCounted
## Giving someone a name.
##
## Ports firstname(), lastname() and generate_name() from
## src/creature/creaturenames.cpp. The lists themselves are in data/names.gd,
## lifted from the same file.
##
## The selection is not a straight pick from one list: a male name is drawn from
## the male and gender-neutral lists *together*, so a gender-neutral name turns
## up in proportion to how many of them there are. Arch-Conservative last names
## work the same way in reverse — everyone can be given one, but an
## Arch-Conservative is limited to that list.


## Gives [param creature] a name of their own, if they have not got one.
##
## Ports Creature::namecreature(). Somebody already named keeps the name, and
## the roll does not happen — which is why the original guards it rather than
## naming twice.
static func name_creature(rng: Rng, creature: Creature) -> void:
	if creature.named:
		return
	creature.name = full_name(rng, Gender.value_of(creature.gender_liberal))
	creature.proper_name = creature.name
	creature.named = true


## A full name, "First Last".
static func full_name(rng: Rng, gender: int = Gender.NEUTRAL) -> String:
	var parts := first_and_last(rng, gender)
	return "%s %s" % [parts[0], parts[1]]


## A first and last name for the same person, never identical to each other.
static func first_and_last(rng: Rng, gender: int = Gender.NEUTRAL) -> Array:
	var first := ""
	var last := ""
	while true:
		first = first_name(rng, gender)
		last = last_name(rng, gender == Gender.WHITE_MALE_PATRIARCH)
		if first != last:
			break
	return [first, last]


## A first name suited to [param gender].
static func first_name(rng: Rng, gender: int) -> String:
	# An unspecified gender picks one, so the names stay balanced.
	if gender == Gender.NEUTRAL:
		gender = Gender.MALE if rng.below(2) != 0 else Gender.FEMALE

	if gender == Gender.WHITE_MALE_PATRIARCH:
		return Roll.pick(rng, Names.PATRIARCH_FIRST)

	if gender == Gender.MALE:
		var roll := rng.below(Names.MALE_FIRST.size() + Names.NEUTRAL_FIRST.size())
		if roll >= Names.NEUTRAL_FIRST.size():
			return Roll.pick(rng, Names.MALE_FIRST)
		return Roll.pick(rng, Names.NEUTRAL_FIRST)

	if gender == Gender.FEMALE:
		var roll := rng.below(Names.FEMALE_FIRST.size() + Names.NEUTRAL_FIRST.size())
		if roll >= Names.NEUTRAL_FIRST.size():
			return Roll.pick(rng, Names.FEMALE_FIRST)
		return Roll.pick(rng, Names.NEUTRAL_FIRST)

	# The original's fallback when the gender is none of the above.
	return "Errol"


## A last name. [param arch_conservative] restricts the draw to the names the
## original reserves for them.
static func last_name(rng: Rng, arch_conservative: bool) -> String:
	if not arch_conservative:
		# Anyone can be given an Arch-Conservative surname; the draw spans both
		# lists, so it happens in proportion to how many there are.
		var roll := rng.below(Names.REGULAR_LAST.size() + Names.ARCHCONSERVATIVE_LAST.size())
		arch_conservative = roll >= Names.REGULAR_LAST.size()

	if arch_conservative:
		return Roll.pick(rng, Names.ARCHCONSERVATIVE_LAST)
	return Roll.pick(rng, Names.REGULAR_LAST)


## A first, middle and last name. The middle is another first name half the
## time and a surname the other half.
static func long_name(rng: Rng, gender: int = Gender.NEUTRAL) -> Array:
	if gender == Gender.NEUTRAL:
		gender = Gender.MALE if rng.below(2) != 0 else Gender.FEMALE

	var first := ""
	var middle := ""
	var last := ""
	while true:
		first = first_name(rng, gender)
		if rng.below(2) != 0:
			# A quarter of the time the middle name crosses gender, unless the
			# person is a white male patriarch.
			var middle_gender := gender if gender == Gender.WHITE_MALE_PATRIARCH \
					or rng.below(2) != 0 else Gender.NEUTRAL
			middle = first_name(rng, middle_gender)
		else:
			middle = last_name(rng, gender == Gender.WHITE_MALE_PATRIARCH)
		last = last_name(rng, gender == Gender.WHITE_MALE_PATRIARCH)
		if not (first == middle and first == last and middle == last):
			break
	return [first, middle, last]
