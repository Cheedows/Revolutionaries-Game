class_name DeathText
extends RefCounted
## The last thing said about somebody.
##
## Ports the words of adddeathmessage() from src/combat/fight.cpp.
## [method Aftermath.manner_of_death] rolls which of these it is, because the
## roll has to match the original's; the words are presentation and live here.
##
## Which table the roll came from depends on what is left of them, exactly as
## the roll itself did.

## A head taken off: four ways, two of which read differently in a car.
const HEADLESS: Array[Array] = [
	["%s reaches once where there is no head, and falls.",
	"%s reaches once where there is no head, and slumps over."],
	["%s stands headless for a moment then crumples over.",
	"%s sits headless for a moment then crumples over."],
	["%s squirts %s out of the neck and runs down the hall.",
	"%s squirts %s out of the neck and falls to the side."],
	["%s sucks a last breath through the neck hole, then is quiet.",
	"%s sucks a last breath through the neck hole, then is quiet."],
]

## A body cut in half: two ways, and a car makes no difference.
const IN_PIECES: Array[String] = [
	"%s breaks into pieces.",
	"%s falls apart and is dead.",
]

## Everything else: eleven ways, the last of which is whatever they believed.
const QUIETLY: Array[String] = [
	"%s cries out one last time then is quiet.",
	"%s gasps a last breath and %s.",
	"%s murmurs quietly, breathing softly. Then all is silent.",
	"%s shouts \"FATHER!  Why have you forsaken me?\" and dies in a heap.",
	"%s cries silently for mother, breathing slowly, then not at all.",
	"%s breathes heavily, coughing up blood...  then is quiet.",
	"%s silently drifts away, and is gone.",
	"%s sweats profusely, murmurs something%s about Jesus, and dies.",
	"%s whines loudly, voice crackling, then curls into a ball, unmoving.",
	"%s shivers silently, whispering a prayer, then all is still.",
	"%s speaks these final words: %s",
]

## What a moderate and a Conservative say at the end. A Liberal says whatever
## the organisation's slogan is.
const MODERATE_LAST_WORDS := "\"A plague on both your houses...\""
const CONSERVATIVE_LAST_WORDS := "\"Better dead than liberal...\""


## The line for a death, or "" when the event does not carry a manner.
##
## [param in_a_car] is the chase: two of the headless lines are written for
## somebody sitting down.
static func describe(state: GameState, data: Dictionary,
		in_a_car: bool = false) -> String:
	if not data.has("manner"):
		return ""
	var victim: Creature = state.creatures.get(data.get("creature", 0))
	var who := victim.name if victim != null and victim.name != "" else "Someone"
	var index := maxi(int(data["manner"]), 0)

	if victim != null and victim.body.is_severed(&"head"):
		var line: Array = HEADLESS[index % HEADLESS.size()]
		var text: String = line[1 if in_a_car else 0]
		if text.count("%s") == 2:
			return text % [who, _blood(state)]
		return text % who
	if victim != null and victim.body.is_severed(&"body"):
		return IN_PIECES[index % IN_PIECES.size()] % who

	var text := QUIETLY[index % QUIETLY.size()]
	match index % QUIETLY.size():
		1:
			return text % [who, _mess(state)]
		7:
			return text % [who, " [good]" if _euphemised(state) else ""]
		10:
			return text % [who, _last_words(state, victim)]
	return text % who


## What the paper is allowed to call blood.
static func _blood(state: GameState) -> String:
	return "[red water]" if _euphemised(state) else "blood"


## And what it is allowed to call the rest.
static func _mess(state: GameState) -> String:
	return "[makes a mess]" if _euphemised(state) else "soils the floor"


## Whether free speech has fallen far enough that the words are cleaned up.
static func _euphemised(state: GameState) -> bool:
	return state.law.get_value(&"freespeech") == Law.ARCH_CONSERVATIVE


## The last thing they say, which depends on what they believed.
static func _last_words(state: GameState, victim: Creature) -> String:
	if victim == null:
		return CONSERVATIVE_LAST_WORDS
	match victim.alignment:
		&"liberal":
			return state.slogan if state.slogan != "" \
					else "\"We need a slogan!\""
		&"moderate":
			return MODERATE_LAST_WORDS
	return CONSERVATIVE_LAST_WORDS
