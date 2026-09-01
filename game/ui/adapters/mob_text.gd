class_name MobText
extends RefCounted
## What a crowd that turns on somebody comes to.
##
## Causing trouble can end with a mob of angry rednecks in the street, and the
## original writes the fight blow by blow: eight ways of getting the better of
## them and eight of coming off worse, rolled between. The roll is the
## simulation's — it moves the generator — so [Trouble] carries which line came
## up and this says it.
##
## All of it is from src/daily/activities.cpp.

const CORNERED := "%s is cornered by a mob of angry rednecks."
const BRANDISHES := "%s brandishes the %s!"
const SCATTERS := "The mob scatters!"

## Getting the better of them.
const WON: Array[String] = [
	"%s breaks the arm of the nearest person!",
	"%s knees a guy in the balls!",
	"%s knocks one out with a fist to the face!",
	"%s bites some hick's ear off!",
	"%s smashes one of them in the jaw!",
	"%s shakes off a grab from behind!",
	"%s yells the slogan!",
	"%s knocks two of their heads together!",
]

## And coming off worse.
const LOST: Array[String] = [
	"%s is held down and kicked by three guys!",
	"%s gets pummeled!",
	"%s gets hit by a sharp rock!",
	"%s is thrown against the sidewalk!",
	"%s is bashed in the face with a shovel!",
	"%s is forced into a headlock!",
	"%s crumples under a flurry of blows!",
	"%s is hit in the chest with a pipe!",
]

## How it ends for somebody the mob got hold of.
##
## Written in the pieces the original prints it in, because the word in the
## middle depends on the law: it swears unless free speech has been legislated
## away, and says [tar] when it has.
const BEAT_THE := "%s beat the "
const SWEARING := "shit"
const CENSORED := "[tar]"
const OUT_OF_EVERYONE := " out of everyone who got close!"
const SEVERELY_BEATEN := "%s is severely beaten before the mob is broken up."


## The line for [param event], or "" for one this does not cover.
static func describe(event: Event, state: GameState) -> String:
	var data := event.data
	var who := _who(state, data)
	match event.type:
		Event.MOB_CORNERED:
			return CORNERED % who
		Event.MOB_SCATTERED:
			return SCATTERS
		Event.MOB_EXCHANGE:
			var lines: Array[String] = WON \
					if bool(data.get("won", false)) else LOST
			return lines[int(data.get("manner", 0)) % lines.size()] % who
		Event.MOB_BEAT_THEM:
			var word := CENSORED \
					if state.law.get_value(&"freespeech") \
					== Law.ARCH_CONSERVATIVE else SWEARING
			return BEAT_THE % who + word + OUT_OF_EVERYONE
		Event.MOB_BEATEN:
			return SEVERELY_BEATEN % who
	return ""


static func _who(state: GameState, data: Dictionary) -> String:
	var creature: Creature = state.creatures.get(data.get("creature", 0))
	return creature.name if creature != null and creature.name != "" \
			else "Someone"
