class_name OrganDamage
extends RefCounted
## What a bad wound takes out from the inside.
##
## Ports the special-wound switches from attack() in src/combat/fight.cpp. A
## wound to the head or body picks one organ at random and, if the wound was
## bad enough of the right kind, takes it — and caps the victim's blood at
## whatever surviving without it is worth.
##
## Nothing here rolls to decide whether an organ is lost: the roll chooses
## which organ is at risk, and the damage decides the rest. A creature can take
## a dozen head wounds and lose nothing if the die keeps naming teeth it has
## already lost.

## What the head roll can name, in the original's order.
const HEAD_TABLE: Array[StringName] = [
	&"face", &"teeth", &"righteye", &"lefteye", &"tongue", &"nose", &"neck",
]

## And the body roll.
const BODY_TABLE: Array[StringName] = [
	&"upperspine", &"lowerspine", &"rightlung", &"leftlung", &"heart",
	&"liver", &"stomach", &"rightkidney", &"leftkidney", &"spleen", &"ribs",
]

## Blood a creature is left with after losing each organ.
const BLOOD_AFTER := {
	&"face": 20, &"righteye": 50, &"lefteye": 50, &"tongue": 50, &"nose": 50,
	&"neck": 20, &"upperspine": 20, &"lowerspine": 20, &"rightlung": 20,
	&"leftlung": 20, &"heart": 3, &"liver": 50, &"stomach": 50,
	&"rightkidney": 50, &"leftkidney": 50, &"spleen": 50,
}

## Teeth and ribs come away several at a time.
const TOOTH_COUNT := 32
const RIB_COUNT := 10


## Applies the organ damage a wound to [param part] might do.
##
## Returns what was lost, as a list of names, for whatever wants to describe it.
static func apply(rng: Rng, target: Creature, part: StringName, damage: int,
		damage_type: int) -> Array[StringName]:
	# What counts as bad enough, by what kind of wound it was.
	var heavy := damage >= 12 and (damage_type
			& (Wound.SHOT | Wound.BURNED | Wound.TORN | Wound.CUT)) != 0
	var poke := damage >= 10 and (damage_type
			& (Wound.SHOT | Wound.TORN | Wound.CUT)) != 0
	var breaks := damage >= 50 and (damage_type
			& (Wound.BRUISED | Wound.SHOT | Wound.TORN | Wound.CUT)) != 0

	var lost: Array[StringName] = []
	if part == &"head":
		_head(rng, target, heavy, breaks, lost)
	if part == &"body":
		_body(rng, target, poke, breaks, lost)
	return lost


static func _head(rng: Rng, target: Creature, heavy: bool, breaks: bool,
		lost: Array[StringName]) -> void:
	var organ: StringName = HEAD_TABLE[rng.below(HEAD_TABLE.size())]
	match organ:
		&"face":
			# The whole face at once, if any of it is still there.
			if not heavy:
				return
			if not (target.body.has_special(&"righteye")
					or target.body.has_special(&"lefteye")
					or target.body.has_special(&"nose")):
				return
			target.body.set_special(&"righteye", 0)
			target.body.set_special(&"lefteye", 0)
			target.body.set_special(&"nose", 0)
			lost.append(&"face")
			_bleed_to(target, BLOOD_AFTER[&"face"])
		&"teeth":
			if target.body.get_special(&"teeth") <= 0:
				return
			var knocked := mini(rng.below(TOOTH_COUNT) + 1,
					target.body.get_special(&"teeth"))
			target.body.set_special(&"teeth",
					target.body.get_special(&"teeth") - knocked)
			lost.append(&"teeth")
		&"neck":
			_take(target, organ, breaks, lost)
		_:
			_take(target, organ, heavy, lost)


static func _body(rng: Rng, target: Creature, poke: bool, breaks: bool,
		lost: Array[StringName]) -> void:
	var organ: StringName = BODY_TABLE[rng.below(BODY_TABLE.size())]
	match organ:
		&"upperspine", &"lowerspine":
			_take(target, organ, breaks, lost)
		&"ribs":
			if target.body.get_special(&"ribs") <= 0 or not breaks:
				return
			var broken := mini(rng.below(RIB_COUNT) + 1,
					target.body.get_special(&"ribs"))
			target.body.set_special(&"ribs",
					target.body.get_special(&"ribs") - broken)
			lost.append(&"ribs")
		_:
			_take(target, organ, poke, lost)


## Takes [param organ] if it is still there and the wound was bad enough.
static func _take(target: Creature, organ: StringName, bad_enough: bool,
		lost: Array[StringName]) -> void:
	if not bad_enough or not target.body.has_special(organ):
		return
	target.body.set_special(organ, 0)
	lost.append(organ)
	_bleed_to(target, BLOOD_AFTER[organ])


## Caps blood at what surviving the loss leaves, never raising it.
static func _bleed_to(target: Creature, ceiling: int) -> void:
	if target.body.blood > ceiling:
		target.body.blood = ceiling
