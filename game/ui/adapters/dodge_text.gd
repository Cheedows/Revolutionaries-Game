class_name DodgeText
extends RefCounted
## What a miss looks like.
##
## The original does not say "missed". It keys nineteen lines on the defence
## roll, from the attacker simply missing up to the target avoiding the attack
## with only an angry glare, and keeps a second set of nineteen for somebody
## doing it at the wheel. Every one of them is in src/combat/fight.cpp; the
## roll that chooses between them is the same roll that decided the miss, so
## [Attack] carries it and nothing extra is rolled here.
##
## Its own file because it is two-thirds of a page of dialogue and combat_text
## has work of its own to do.

const DODGES: Array[String] = [
	"", "%s missed!", "%s just barely missed!",
	"%s tumbles out of the way!",
	"%s jumps aside at the last moment!",
	"%s leaps for cover!",
	"%s ducks back behind cover!",
	"%s wisely stays behind cover!",
	"%s rolls away from the attack!",
	"%s nimbly dodges away from the line of fire!",
	"%s leaps over the attack!",
	"%s gracefully dives to avoid the attack!",
	"%s twists to avoid the attack!",
	"%s spins to the side!",
	"%s does the Matrix-dodge!",
	"%s avoids the attack with no difficulty at all!",
	"%s flexes slightly to avoid being hit!",
	"%s confidently allows the attack to miss!",
	"%s seems to avoid the attack with only an angry glare!",
]

## The same, for somebody doing it at the wheel.
const DRIVING: Array[String] = [
	"", "%s missed!", "%s just barely missed!",
	"%s can't seem to keep the vehicle in either the lane or the line of fire!",
	"%s swerves randomly!",
	"%s cuts off another driver and the shot is blocked!",
	"%s drops behind a hill in the road!",
	"%s changes lanes at the last second!",
	"%s accelerates suddenly and the shot goes short!",
	"%s fakes a left, and goes right instead!",
	"%s fakes a right, and goes left instead!",
	"%s fakes with the brakes while powering ahead!",
	"%s swerves to the other side of a truck!",
	"%s weaves through a row of taxis!",
	"%s dodges behind a hot dog cart!",
	"%s squeezes between some bridge supports for cover!",
	"%s squeals around a corner and behind a building!",
	"%s power slides through a narrow gap in the traffic!",
	"%s rolls the car onto two wheels to dodge the shot!",
]

## A roll off the end of either list, which is somebody who rolled a zero.
## The original's comment on this line reads "You should feel bad."
const MISSES_COMPLETELY := "%s misses completely!"

## The first two lines of both lists are about the attacker rather than the
## target, which is why they read the other way round.
const ABOUT_THE_ATTACKER := 3


## A miss, said the way the defence roll earned.
static func of(state: GameState, data: Dictionary) -> String:
	var dodge := int(data.get("dodge", 0))
	var lines: Array[String] = DRIVING \
			if bool(data.get("driving", false)) else DODGES
	if dodge <= 0 or dodge >= lines.size():
		return MISSES_COMPLETELY % _who(state, data.get("attacker", 0))
	var whose := "attacker" if dodge < ABOUT_THE_ATTACKER else "target"
	return lines[dodge] % _who(state, data.get(whose, 0))


static func _who(state: GameState, id: int) -> String:
	var creature: Creature = state.creatures.get(id)
	return creature.name if creature != null and creature.name != "" \
			else "Someone"
