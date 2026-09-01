class_name Creature
extends RefCounted
## One person: a recruit, an enemy, a hostage, a politician.
##
## Mirrors the Creature class in src/creature/creature.h, minus its display and
## input members. Everything here is state; anything that decides something
## (rolls, checks, training curves) is a system in core/systems/creature/.

var id: int = 0

## Code name shown to the player, and the birth name behind it.
var name: String = ""
var proper_name: String = ""

## Idname of the creature type in data/creatures/.
var type: StringName = &""

## &"liberal", &"moderate" or &"conservative".
var alignment: StringName = &"conservative"

## The original tracks two genders per creature: how Liberals read them and how
## Conservatives do, which can differ.
var gender_liberal: StringName = &"neutral"
var gender_conservative: StringName = &"neutral"

var age: int = 0
var birthday_month: int = 1
var birthday_day: int = 1

var alive: bool = true
var exists: bool = true

var attributes := Attributes.new()
var skills := Skills.new()
var body := Body.new()

## Reputation and pull. Drives attribute bonuses and recruitment.
var juice: int = 0
var money: int = 0
var income: int = 0

## How convincingly the creature passes as a member of its cover profession.
var infiltration: float = 0.0

## Id of the squad this creature belongs to, or 0 for none.
var squad_id: int = 0

## Where the creature is, and where it works, as location ids.
var location: int = -1
var work_location: int = -1
var base: int = -1

## How much attention the police are paying.
var heat: int = 0

## Crimes the authorities suspect, per entry in [constant Ids.LAW_FLAGS].
## Note this is a different list from the laws themselves: a crime is a thing
## you can be charged with, a law is a policy the country holds.
var crimes_suspected: PackedInt32Array = PackedInt32Array()

## Whether this is an animal rather than a person. The original tracks it
## because animals are exempt from a few human rules — nobody arrests a dog for
## indecency — and because they are described differently.
var animal: bool = false

## A special attack the creature can make instead of a normal one, or &"" for
## none — a tank's cannon, a mosquito's proboscis.
var special_attack: StringName = &""

## Whether the authorities would deport rather than charge this person.
var illegal_alien: bool = false

## The rest of the original's CREATUREFLAG_ bits, as named fields. They are
## independent states rather than a bitmask because nothing in the port reads
## them as a set.
## Whether this creature has been given a name yet. The original names a
## Conservative only when the player has reason to know them.
var named: bool = false

var wheelchair: bool = false
var just_escaped: bool = false
var missing: bool = false
var kidnapped: bool = false
var sleeper: bool = false
var love_slave: bool = false
var brainwashed: bool = false
var converted: bool = false

## Id of the person this one is dragging along, or 0 for nobody. A hostage or
## a body makes a squad conspicuous in every sense.
var prisoner_id: int = 0

## &"none", &"animal" or &"tank". The original folds tanks into the same field,
## since a tank is another thing that is not a person and is armored by nature.
var animal_gloss: StringName = &"none"

## Current assignment, from [constant Ids.ACTIVITIES].
var activity: StringName = &"none"

## The issue of the mural this creature is part-way through, or &"" for none.
## The original keeps it in the activity's spare argument.
var mural: StringName = &""

## The garment a tailor is working on making, when their assignment is to sew.
## The original keeps it in the activity's spare argument.
var making: StringName = &""

## The kind of person a recruiter is asking around for. Also the activity's
## spare argument in the original.
var recruiting: StringName = &""

## What has been done to this creature, while they are somebody's hostage.
var interrogation: Interrogation = null

## The hostage somebody is looking after, when that is their assignment.
var tending_id: int = 0

## Days spent laying low, in hospital, in court, or dating.
var hiding: int = 0
var clinic: int = 0
var dating: int = 0
var sentence: int = 0
var confessions: int = 0
var death_penalty: int = 0

## Id of whoever recruited this creature, or -1. Reputation trickles up it.
var recruiter_id: int = -1

## The car this creature reaches for when a squad needs one, and whether they
## take the wheel. Set when they steal one and nothing else is theirs.
var preferred_car_id: int = -1
var prefers_driving: bool = false

## The car this creature is in during a chase, or 0 for on foot, and whether
## they are the one driving it.
var vehicle_id: int = 0
var is_driver: bool = false

## Set when a fight found this creature too hurt to act, so the next check does
## not have to roll for it again.
var forced_incapacitated: bool = false

## Counts down the turns this creature will not listen to a cover story: set
## when they are attacked, so nobody talks their way out of a fight they
## started.
var cannot_bluff: int = 0

## Whether this creature is in the organisation.
##
## The original has two lists, `pool` and `encounter`, and being in the LCS is
## being in the first one. The port keeps everybody in one dictionary, so
## membership has to be a flag; [member join_days] served as one for a long
## time, but it is a day counter that starts at zero on the day somebody
## joins, so a new recruit read as a stranger until the following morning.
var enlisted: bool = false

## Which hire this creature is, or -1 for the founder. The founder takes half
## damage and gets shielded, which is what this is read for.
var hire_id: int = -1

## Recruitment meetings this Liberal has booked. Past a handful they start
## turning up to the wrong ones.
var meetings: int = 0

## Days since joining, and since dying.
var join_days: int = 0
var death_days: int = 0

var weapon: Weapon = null
var armor: Armor = null
var clips: Array[Clip] = []

## More of whatever is being thrown. A stack of knives is one in the hand and
## the rest here; throwing the one in the hand brings the next up.
var spare_throwables: Array[Weapon] = []
var carried: Array[Item] = []

## What has been fitted where: the augment's idname by body part, from
## [constant Augmentation.SLOTS]. The original keeps five slots and lets each
## hold one thing, which is what a dictionary of them is.
var augmentations: Dictionary = {}


func _init() -> void:
	crimes_suspected.resize(Ids.LAW_FLAGS.size())


## The type's idname with its CREATURE_ prefix dropped, which is how the
## generated tables key it.
func type_key() -> StringName:
	return StringName(String(type).to_lower().trim_prefix("creature_"))


func is_armed() -> bool:
	return weapon != null


func is_naked() -> bool:
	return armor == null


## Whether this creature belongs to the player's organisation.
func is_member() -> bool:
	return enlisted or squad_id != 0 or join_days > 0

## A separate person with the same everything.
##
## The original copies a creature by assignment in several places — the
## conversation that turns a stranger into a recruit is one — and a shallow
## copy would leave the two sharing a body and a wardrobe, so everything
## mutable is copied with them.
func copy() -> Creature:
	var twin: Creature = duplicate_shallow()
	twin.attributes = attributes.duplicate_attributes()
	twin.skills = skills.duplicate_skills()
	twin.body = body.duplicate_body()
	twin.crimes_suspected = crimes_suspected.duplicate()
	twin.weapon = weapon.duplicate_item() if weapon != null else null
	twin.armor = armor.duplicate_item() if armor != null else null
	twin.clips = []
	for clip: Clip in clips:
		twin.clips.append(clip.duplicate_item())
	twin.spare_throwables = []
	for spare: Weapon in spare_throwables:
		twin.spare_throwables.append(spare.duplicate_item())
	twin.carried = []
	for item: Item in carried:
		twin.carried.append(item.duplicate_item())
	twin.augmentations = augmentations.duplicate()
	return twin


## Every plain field, copied one by one. The sub-objects are replaced by
## [method copy]; this only exists to keep that method short.
func duplicate_shallow() -> Creature:
	var twin := Creature.new()
	for entry: Dictionary in get_property_list():
		if int(entry["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		twin.set(entry["name"], get(entry["name"]))
	return twin
