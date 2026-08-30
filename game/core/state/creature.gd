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

## &"none", &"animal" or &"tank". The original folds tanks into the same field,
## since a tank is another thing that is not a person and is armored by nature.
var animal_gloss: StringName = &"none"

## Current assignment, from [constant Ids.ACTIVITIES].
var activity: StringName = &"none"

## Days spent laying low, in hospital, in court, or dating.
var hiding: int = 0
var clinic: int = 0
var dating: int = 0
var sentence: int = 0
var confessions: int = 0
var death_penalty: int = 0

## Id of whoever recruited this creature, or -1. Reputation trickles up it.
var recruiter_id: int = -1

## Days since joining, and since dying.
var join_days: int = 0
var death_days: int = 0

var weapon: Weapon = null
var armor: Armor = null
var clips: Array[Clip] = []
var carried: Array[Item] = []

## Installed augmentations, by augment idname.
var augmentations: Array[StringName] = []


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
	return squad_id != 0 or join_days > 0
