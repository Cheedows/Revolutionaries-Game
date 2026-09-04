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
	lines.append("Juice: %d  $%d  %s" % [creature.juice, creature.money,
			ConditionText.of(creature)])
	lines.append(ActivityText.of(creature.activity))

	var attributes: Array[String] = []
	for index in Ids.ATTRIBUTES.size():
		attributes.append("%s: %d" % [StatText.attribute(Ids.ATTRIBUTES[index]),
				creature.attributes.values[index]])
	lines.append(", ".join(attributes) + ".")

	var hurt := wounds(creature)
	lines.append("Body: %s" % (", ".join(hurt) if not hurt.is_empty()
			else "Liberal"))

	var crimes := charges(creature, state.law)
	if not crimes.is_empty():
		lines.append("%s  Heat: %d" % [", ".join(crimes), creature.heat])
	if not creature.augmentations.is_empty():
		var fitted: Array[String] = []
		for slot: StringName in creature.augmentations:
			fitted.append(String(creature.augmentations[slot]).to_lower())
		lines.append("Augmentation: %s" % ", ".join(fitted))
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


## What the state calls each thing it can charge somebody with, from the
## indictment the original reads out at trial in src/monthly/justice.cpp.
## Flag burning and hiring depend on the law, which is why they are not here.
const CHARGES := {
	&"treason": "treason", &"terrorism": "terrorism", &"murder": "murder",
	&"kidnapping": "kidnapping", &"bankrobbery": "bank robbery",
	&"arson": "arson", &"speech": "sedition", &"brownies": "drug dealing",
	&"escaped": "escaping prison", &"helpescape": "aiding a prison escape",
	&"jury": "jury tampering", &"racketeering": "racketeering",
	&"extortion": "extortion", &"armedassault": "felony assault",
	&"assault": "misdemeanor assault", &"cartheft": "grand theft auto",
	&"ccfraud": "credit card fraud", &"theft": "petty larceny",
	&"prostitution": "prostitution",
	&"commerce": "interference with interstate commerce",
	&"information": "unlawful access of an information system",
	&"burial": "unlawful burial", &"breaking": "breaking and entering",
	&"vandalism": "vandalism", &"resist": "resisting arrest",
	&"disturbance": "disturbing the peace",
	&"publicnudity": "indecent exposure", &"loitering": "loitering",
}


## What the authorities want them for, in the words of the indictment.
##
## The original counts repeats — "3 counts of arson" — and says it that way,
## so the port does too. Two charges are named by the law of the day, so they
## need the law: with none to hand they take the wording the original uses
## where the country is still Moderate.
static func charges(creature: Creature, law: Law = null) -> Array[String]:
	var wanted: Array[String] = []
	for index in Ids.LAW_FLAGS.size():
		var count := creature.crimes_suspected[index]
		if count <= 0:
			continue
		var flag: StringName = Ids.LAW_FLAGS[index]
		var named := String(CHARGES.get(flag, String(flag)))
		if flag == &"burnflag":
			# The original charges nothing at all once flag burning is legal.
			var burning := law.get_value(&"flagburning") if law != null else 0
			if burning > 0:
				continue
			named = "Flag Murder" if burning == -2 \
					else ("felony flag burning" if burning == -1
					else "flag burning")
		elif flag == &"hireillegal":
			var immigration := law.get_value(&"immigration") if law != null else 1
			if count > 1:
				named = "hiring illegal aliens" if immigration < 1 \
						else "hiring undocumented workers"
			else:
				named = "hiring an illegal alien" if immigration < 1 \
						else "hiring an undocumented worker"
		wanted.append(named if count == 1 or flag == &"hireillegal"
				else "%d counts of %s" % [count, named])
	return wanted


## What they have on them.
static func carrying(creature: Creature, catalog: Catalog) -> Array[String]:
	var lines: Array[String] = []
	lines.append("Weapon: %s" % (item_title(creature.weapon, catalog)
			if creature.weapon != null else "None"))
	lines.append("Clothes: %s" % (item_title(creature.armor, catalog)
			if creature.armor != null else "None"))
	if not creature.clips.is_empty():
		var ammunition: Array[String] = []
		for clip: Clip in creature.clips:
			ammunition.append(item_title(clip, catalog))
		lines.append("Ammunition: %s" % ", ".join(ammunition))
	if not creature.spare_throwables.is_empty():
		var spares: Array[String] = []
		for spare: Weapon in creature.spare_throwables:
			spares.append(item_title(spare, catalog))
		lines.append("Also: %s" % ", ".join(spares))
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
## The original asks this from reviewmode.cpp, in two lines.
static func release_warning() -> String:
	return "Do you want to permanently release this squad member from the LCS? " \
			+ "If the member has low heart they may go to the police."


## What the player is told before they have somebody killed.
##
## The original names the Liberal who would do it; the port asks on the record
## itself, where the boss is a line above.
static func execution_warning(boss: String) -> String:
	return "Confirm you want to have %s kill this squad member? " % boss \
			+ "Killing your squad members is Not a Liberal Act."
