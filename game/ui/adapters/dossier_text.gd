class_name DossierText
extends RefCounted
## What is known about one person, in words.
##
## Ports gettitle() from src/common/getnames.cpp and the record the original
## draws across its roster and equip screens. Nothing here decides anything:
## it reads state and says it.

## Where somebody stands, by how much pull they have and whose side they are
## on. From gettitle(); the bracketed forms are what the original prints where
## the country will not have the word.
const LIBERAL_RANKS: Array = [
	[-50, "Damn Worthless", "[Darn] Worthless"],
	[-10, "Society's Dregs", "Society's Dregs"],
	[0, "Punk", "Punk"],
	[10, "Civilian", "Civilian"],
	[50, "Activist", "Activist"],
	[100, "Socialist Threat", "Socialist Threat"],
	[200, "Revolutionary", "Revolutionary"],
	[500, "Urban Commando", "Urban Commando"],
	[1000, "Liberal Guardian", "Liberal Guardian"],
]
const LIBERAL_TOP := "Elite Liberal"

const MODERATE_RANKS: Array = [
	[-50, "Damn Worthless", "[Darn] Worthless"],
	[-10, "Society's Dregs", "Society's Dregs"],
	[0, "Non-Liberal Punk", "Non-Liberal Punk"],
	[10, "Non-Liberal", "Non-Liberal"],
	[50, "Hard Working", "Hard Working"],
	[100, "Respected", "Respected"],
	[200, "Upstanding Citizen", "Upstanding Citizen"],
	[500, "Great Person", "Great Person"],
	[1000, "Peacemaker", "Peacemaker"],
]
const MODERATE_TOP := "Peace Prize Winner"

const CONSERVATIVE_RANKS: Array = [
	[-50, "Damn Worthless", "[Darn] Worthless"],
	[-10, "Conservative Dregs", "Conservative Dregs"],
	[0, "Conservative Punk", "Conservative Punk"],
	[10, "Mindless Conservative", "Mindless Conservative"],
	[50, "Wrong-Thinker", "Wrong-Thinker"],
	[100, "Stubborn as Hell", "Stubborn as [Heck]"],
	[200, "Heartless Bastard", "Heartless [Jerk]"],
	[500, "Insane Vigilante", "Insane Vigilante"],
	[1000, "Arch-Conservative", "Arch-Conservative"],
]
const CONSERVATIVE_TOP := "Evil Incarnate"

## The wounds worth naming, worst first.
const WOUNDS: Array = [
	[Wound.NASTY_OFF, "torn off"], [Wound.CLEAN_OFF, "gone"],
	[Wound.SHOT, "shot"], [Wound.CUT, "cut"], [Wound.BURNED, "burned"],
	[Wound.TORN, "torn"], [Wound.BRUISED, "bruised"],
	[Wound.BLEEDING, "bleeding"],
]

## What each body part is called.
const PARTS := {
	&"head": "head", &"body": "chest", &"arm_right": "right arm",
	&"arm_left": "left arm", &"leg_right": "right leg", &"leg_left": "left leg",
}


## Somebody's rank, which the original calls their title.
##
## The bracketed forms need the law, which this does not have; a dossier is
## read at home, where the squad calls things what they are.
static func standing(creature: Creature) -> String:
	var ranks: Array = LIBERAL_RANKS
	var top := LIBERAL_TOP
	match Alignment.value_of(creature.alignment):
		Alignment.MODERATE:
			ranks = MODERATE_RANKS
			top = MODERATE_TOP
		Alignment.CONSERVATIVE, Alignment.ARCH_CONSERVATIVE:
			ranks = CONSERVATIVE_RANKS
			top = CONSERVATIVE_TOP
	for rank: Array in ranks:
		var threshold := int(rank[0])
		# The first two bands are "at or below"; the rest are "below".
		if threshold <= -10:
			if creature.juice <= threshold:
				return String(rank[1])
		elif creature.juice < threshold:
			return String(rank[1])
	return top


## The record: who they are, what they can do, and what is wrong with them.
static func record(creature: Creature, state: GameState,
		catalog: Catalog) -> Array[String]:
	var lines: Array[String] = []
	lines.append("%s, %d, %s." % [creature.proper_name if creature.proper_name
			!= "" else creature.name, creature.age,
			String(creature.alignment)])
	lines.append("Juice %d.  $%d in hand.  %d%% blood."
			% [creature.juice, creature.money, creature.body.blood])
	lines.append("Doing: %s." % ActivityText.of(creature.activity).to_lower())

	var attributes: Array[String] = []
	for index in Ids.ATTRIBUTES.size():
		attributes.append("%s %d" % [String(Ids.ATTRIBUTES[index]).capitalize(),
				creature.attributes.values[index]])
	lines.append(", ".join(attributes) + ".")

	var skills: Array[String] = []
	for index in Ids.SKILLS.size():
		if creature.skills.values[index] <= 0:
			continue
		skills.append("%s %d" % [String(Ids.SKILLS[index]).capitalize(),
				creature.skills.values[index]])
	lines.append("Skills: %s." % (", ".join(skills) if not skills.is_empty()
			else "none worth the name"))

	var hurt := wounds(creature)
	lines.append("Hurt: %s." % (", ".join(hurt) if not hurt.is_empty()
			else "nothing"))

	var crimes := charges(creature)
	if not crimes.is_empty():
		lines.append("Wanted for: %s.  Heat %d."
				% [", ".join(crimes), creature.heat])
	if not creature.augmentations.is_empty():
		var fitted: Array[String] = []
		for slot: StringName in creature.augmentations:
			fitted.append(String(creature.augmentations[slot]).to_lower())
		lines.append("Fitted with: %s." % ", ".join(fitted))
	return lines


## What is wrong with them, part by part.
static func wounds(creature: Creature) -> Array[String]:
	var hurt: Array[String] = []
	for index in Ids.BODY_PARTS.size():
		var flags := creature.body.wounds[index]
		if flags == 0:
			continue
		for entry: Array in WOUNDS:
			if flags & int(entry[0]) != 0:
				hurt.append("%s %s" % [PARTS.get(Ids.BODY_PARTS[index],
						String(Ids.BODY_PARTS[index])), entry[1]])
				break
	return hurt


## What the authorities want them for.
static func charges(creature: Creature) -> Array[String]:
	var wanted: Array[String] = []
	for index in Ids.LAW_FLAGS.size():
		if creature.crimes_suspected[index] > 0:
			wanted.append(String(Ids.LAW_FLAGS[index]).capitalize().to_lower())
	return wanted


## What they have on them.
static func carrying(creature: Creature, catalog: Catalog) -> Array[String]:
	var lines: Array[String] = []
	lines.append("Weapon: %s." % (item_title(creature.weapon, catalog)
			if creature.weapon != null else "nothing"))
	lines.append("Wearing: %s." % (item_title(creature.armor, catalog)
			if creature.armor != null else "nothing at all"))
	if not creature.clips.is_empty():
		var ammunition: Array[String] = []
		for clip: Clip in creature.clips:
			ammunition.append(item_title(clip, catalog))
		lines.append("Ammunition: %s." % ", ".join(ammunition))
	if not creature.spare_throwables.is_empty():
		var spares: Array[String] = []
		for spare: Weapon in creature.spare_throwables:
			spares.append(item_title(spare, catalog))
		lines.append("Also: %s." % ", ".join(spares))
	return lines


## One line for one thing, with however many of it there are.
static func item_title(item: Item, catalog: Catalog) -> String:
	if item == null:
		return "nothing"
	var name := String(item.type).trim_prefix("WEAPON_").trim_prefix("ARMOR_") \
			.trim_prefix("CLIP_").trim_prefix("LOOT_").replace("_", " ") \
			.capitalize()
	if catalog != null:
		var kind: StringName = item.item_class()
		var entry: Resource = catalog.get_entry(kind, item.type)
		if entry != null:
			var declared: Variant = entry.get(&"longname")
			if declared != null and String(declared) != "":
				name = String(declared)
	if item is Weapon and (item as Weapon).ammo > 0:
		name += " (%d)" % (item as Weapon).ammo
	if item.count > 1:
		name += " x%d" % item.count
	return name


## What the player is told before they let somebody go for good.
##
## Both halves of the original's warning: a released Liberal with more sense
## than heart may go to the police, and killing one is not a Liberal act.
static func discharge_warning() -> String:
	return "Releasing them is permanent, and if their heart is weak they " \
			+ "may go to the police. Killing your own is Not a Liberal Act."
