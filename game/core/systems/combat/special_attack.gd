class_name SpecialAttack
extends RefCounted
## Talking somebody round instead of hitting them.
##
## Ports specialattack() from src/combat/fight.cpp. Some people do not fight:
## a judge argues, a CEO offers you a job, a radio host talks over you, and
## anybody with an instrument plays at you. It is still an attack — it stuns,
## and if it lands hard enough it changes somebody's mind: one of your own is
## taken off the squad and handed to the other side, and a Conservative comes
## over to yours.
##
## The lines themselves are the UI's business; the choice of line is a draw, so
## the index is rolled here and reported.

## How many lines each kind of speaker has, from the tables in fight.cpp.
## Rolled for even when nobody is listening, because the roll is part of the
## sequence.
const LINES := {
	&"judge": 4, &"science": 3, &"politician": 12, &"ceo_conservative": 10,
	&"ceo_other": 5, &"media": 5, &"military": 5, &"police": 7, &"music": 5,
}

## Every four points the argument wins by is a turn spent reeling.
const STUN_PER_POINT := 4

## Somebody with standing loses it rather than their convictions. The two
## sides disagree about how much standing that takes and how much is left, by
## one point each — the original writes the two branches separately.
const CONVICTION := 100
const CONVICTION_COST := 50

## A wisdom roll this wide decides whether an argument teaches or converts.
const DOUBT := 15


## Resolves [param attacker] arguing with [param target].
static func resolve(state: GameState, rng: Rng, attacker: Creature,
		target: Creature, context: Dictionary) -> Array[Event]:
	var catalog: Catalog = context.get(&"catalog")
	var events: Array[Event] = []

	# A Liberal argues from the heart; everybody else from the head.
	var from_heart := attacker.alignment == &"liberal"
	var attack := CheckRules.attribute_roll(rng, attacker,
			&"heart" if from_heart else &"wisdom")
	attack += AttributeRules.effective(target,
			&"heart" if from_heart else &"wisdom")

	var argument := _argue(state, rng, attacker, target, catalog)
	# A song stands on its own: the opening roll is thrown away rather than
	# added to, which is why a bad musician cannot argue their way through.
	attack = argument["attack"] if argument.get("replaces", false) \
			else attack + argument["attack"]
	var resist: int = argument["resist"]

	events.append(Event.new(Event.SPECIAL_ATTACK_MADE, {
		"attacker": attacker.id, "target": target.id,
		"kind": argument["kind"], "line": argument["line"],
	}))

	events.append_array(settle(state, rng, attacker, target, attack, resist,
			catalog))
	return events


## What an argument that landed does to the person it landed on.
##
## Nothing gets through to an animal, a tank, or somebody already broken; an
## argument between allies is just conversation; and one that does not beat the
## reply does nothing at all.
static func settle(state: GameState, rng: Rng, attacker: Creature,
		target: Creature, attack: int, resist: int,
		catalog: Catalog) -> Array[Event]:
	var events: Array[Event] = []
	if target.animal_gloss == &"tank" \
			or (target.animal_gloss == &"animal"
					and state.law.get_value(&"animalresearch") != 2) \
			or (Encounters.is_enemy(attacker) and target.brainwashed):
		return events
	if attacker.alignment == target.alignment or attack <= resist:
		return events

	target.body.stunned += (attack - resist) / STUN_PER_POINT
	events.append(Event.new(Event.CREATURE_STUNNED,
			{"creature": target.id, "turns": target.body.stunned}))

	if Encounters.is_enemy(attacker):
		events.append_array(_talked_away(state, rng, attacker, target,
				catalog))
	else:
		events.append_array(_won_over(state, rng, target, catalog))
	return events


## One of the squad losing an argument to a Conservative.
##
## Standing carries them through the first few; after that the argument either
## teaches them something or takes them. Somebody kept by love rather than
## conviction cannot be argued away at all.
static func _talked_away(state: GameState, rng: Rng, attacker: Creature,
		target: Creature, catalog: Catalog) -> Array[Event]:
	var events: Array[Event] = []
	if target.juice > CONVICTION:
		JuiceRules.add(state, target, -CONVICTION_COST, CONVICTION)
		return events
	var wisdom := AttributeRules.effective(target, &"wisdom", true)
	if rng.below(DOUBT) > wisdom \
			or wisdom < AttributeRules.effective(target, &"heart", true):
		target.attributes.set_value(&"wisdom",
				target.attributes.get_value(&"wisdom") + 1)
		return events
	if target.alignment == &"liberal" and target.love_slave:
		return events

	target.body.stunned = 0
	events.append_array(Capture.free_hostage(state, target, catalog))

	# They walk over to the other side of the room. The original copies them
	# into the encounter roster and kills the pool entry, which is how they
	# leave the squad for good.
	var defector: Creature = target.copy()
	if Encounters.is_enemy(attacker):
		Alignment.conservatise(defector)
	defector.cannot_bluff = 2
	defector.squad_id = 0
	state.add_creature(defector)
	state.site.encounter_ids.append(defector.id)

	_leave_the_squad(state, target)
	events.append(Event.new(Event.CREATURE_CONVERTED,
			{"creature": target.id, "became": defector.id, "by": attacker.id}))
	return events


## A Conservative losing an argument to the squad. Standing holds them for a
## while, then their heart grows, and then they come over.
static func _won_over(state: GameState, rng: Rng, target: Creature,
		catalog: Catalog) -> Array[Event]:
	var events: Array[Event] = []
	if target.juice >= CONVICTION:
		JuiceRules.add(state, target, -CONVICTION_COST, CONVICTION - 1)
		return events
	var moved := CheckRules.attribute_check(rng, target, &"heart",
			Difficulty.AVERAGE)
	var heart := AttributeRules.effective(target, &"heart", true)
	if not moved or heart < AttributeRules.effective(target, &"wisdom", true):
		target.attributes.set_value(&"heart",
				target.attributes.get_value(&"heart") + 1)
		return events

	target.body.stunned = 0
	Alignment.liberalize(target)
	UniqueCreatures.converted(state, rng, target, catalog)
	target.infiltration = SinglePrecision.of(target.infiltration / 2.0)
	target.converted = true
	target.cannot_bluff = 0
	events.append(Event.new(Event.CREATURE_CONVERTED,
			{"creature": target.id}))
	return events


## The defector is dead as far as the Squad is concerned.
##
## They come off the roster and are marked dead, but the original never clears
## their squad id — only the copy that walked across the room gets one — so
## neither does this.
static func _leave_the_squad(state: GameState, target: Creature) -> void:
	target.alive = false
	target.body.blood = 0
	target.location = -1
	var squad := state.active_squad()
	if squad == null:
		return
	var index := Array(squad.member_ids).find(target.id)
	if index != -1:
		squad.member_ids.remove_at(index)


## Which argument is made, what it is worth, and what the target has to say
## back. The kind is the speaker's, not the weapon's.
static func _argue(state: GameState, rng: Rng, attacker: Creature,
		target: Creature, catalog: Catalog) -> Dictionary:
	var listening_with: StringName = &"heart" if target.alignment == &"liberal" \
			else &"wisdom"

	match attacker.type_key():
		&"judge_conservative", &"judge_liberal":
			return _debate(rng, attacker, target, &"judge", &"law", listening_with)
		&"scientist_eminent":
			return _debate(rng, attacker, target, &"science", &"science",
					listening_with)
		&"politician":
			return _debate(rng, attacker, target, &"politician", &"law",
					listening_with)
		&"corporate_ceo":
			var kind: StringName = &"ceo_conservative" \
					if attacker.alignment == &"conservative" else &"ceo_other"
			return _debate(rng, attacker, target, kind, &"business", listening_with)
		&"radiopersonality", &"newsanchor":
			return _charm(rng, attacker, target, &"media", listening_with)
		&"militaryofficer":
			return _charm(rng, attacker, target, &"military", listening_with)
		&"cop":
			if _is_enemy(attacker):
				var line := rng.below(LINES[&"police"])
				var resist := CheckRules.attribute_roll(rng, target, &"heart")
				var attack := CheckRules.skill_roll(rng, attacker, &"persuasion")
				return {"kind": &"police", "line": line, "attack": attack,
						"resist": resist}
	return _play(state, rng, attacker, target, listening_with, catalog)


## An argument from expertise: they know the subject, and so might you.
static func _debate(rng: Rng, attacker: Creature, target: Creature,
		kind: StringName, subject: StringName,
		listening_with: StringName) -> Dictionary:
	var line := rng.below(LINES[kind])
	var resist := CheckRules.skill_roll(rng, target, subject)
	resist += CheckRules.attribute_roll(rng, target, listening_with)
	var attack := CheckRules.skill_roll(rng, attacker, subject)
	return {"kind": kind, "line": line, "attack": attack, "resist": resist}


## An argument from presence rather than knowledge.
static func _charm(rng: Rng, attacker: Creature, target: Creature,
		kind: StringName, listening_with: StringName) -> Dictionary:
	var line := rng.below(LINES[kind])
	var resist := CheckRules.attribute_roll(rng, target, listening_with)
	var attack := CheckRules.attribute_roll(rng, attacker, &"charisma")
	return {"kind": kind, "line": line, "attack": attack, "resist": resist}


## A song, which replaces the opening roll rather than adding to it.
static func _play(state: GameState, rng: Rng, attacker: Creature,
		target: Creature, listening_with: StringName,
		catalog: Catalog) -> Dictionary:
	if not is_musical(attacker, catalog) and attacker.type_key() != &"cop":
		return {"kind": &"none", "line": 0, "attack": 0, "resist": 0}

	var line := rng.below(LINES[&"music"])
	var attack := CheckRules.skill_roll(rng, attacker, &"music")
	var resist := CheckRules.attribute_roll(rng, target, listening_with)
	# Playing to a tough crowd teaches more than playing to an easy one.
	TrainRules.train(attacker, &"music",
			rng.below(resist) + 1 if resist > 0 else 1)
	return {"kind": &"music", "line": line, "attack": attack, "resist": resist,
			"replaces": true}


## Whether this creature would rather play than fight.
static func is_musical(creature: Creature, catalog: Catalog) -> bool:
	if creature.weapon == null:
		return false
	var type: WeaponType = catalog.get_entry(&"weapon", creature.weapon.type)
	return type != null and type.musical_attack


## Whether this creature is on the other side.
static func _is_enemy(creature: Creature) -> bool:
	return not creature.is_member()
