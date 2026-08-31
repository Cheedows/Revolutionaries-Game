class_name MajorEventBadText
extends RefCounted
## The crime and courts half of a bad night's news.
##
## Says what [MajorEventBad] rolled, from the negative half of
## constructeventstory() in src/news/majorevent.cpp.

const BREAK := "&r"

## What the suspect was holding.
const EVIDENCE := {
	&"pieces": "pieces of another victim", &"toys": "bloody toys",
	&"clothing": "a child's clothing stained with DNA evidence",
	&"yearbooks": "seven junior high school yearbooks",
	&"backpacks": "two small backpacks",
}

## What was done to the children.
const DESECRATION := {
	&"satanic": "carved with satanic symbols", &"mutilated": "sexually mutilated",
	&"teeth": "missing all of their teeth",
	&"fingers": "missing all of their fingers", &"eyes": "without eyes",
}

## How the police got there.
const BREAKTHROUGH := {
	&"call": "a victim called 911 just prior to being slain while still on the phone",
	&"address": "the suspect allegedly carved an address into one of the bodies",
	&"witness": "an eye witness allegedly spotted the suspect luring a victim into a car",
	&"trail": "a blood trail was found on a road that led them to the suspect's car trunk",
	&"ditch": "they found a victim in a ditch, still clinging to life",
}

## Where the shooting was stopped.
const VENUE := {
	&"mall": " Mall", &"theater": " Theater",
	&"high_school": " High School", &"university": " University",
}

## How the hero is addressed.
const TITLE := {&"mr": "Mr. ", &"ms": "Ms. ", &"mrs": "Mrs. ", &"miss": "Miss "}


static func describe(state: GameState, view: StringName,
		slots: Dictionary) -> String:
	match String(view):
		"deathpenalty": return _death_penalty(state, slots)
		"justices": return _justices(slots)
		"guncontrol": return _gun_control(state, slots)
		"prisons": return MajorEventPrisonText.describe(state, slots)
	return MajorEventIndustryText.describe(state, view, slots)


## A child killer caught.
static func _death_penalty(state: GameState, slots: Dictionary) -> String:
	var text := "%s - Perhaps parents can rest easier tonight.  " % slots["city"]
	text += "The authorities have apprehended their primary suspect in the "
	text += "string of brutal child killings that has kept everyone in the "
	text += "area on edge, according to a spokesperson for the police "
	text += "department here.  "
	text += "%s %s %s was detained yesterday afternoon, reportedly in " \
			% [slots["first"], slots["middle"], slots["last"]]
	text += "possession of %s" % EVIDENCE[slots["evidence"]]
	text += ".  Over twenty children in the past two years have gone missing, "
	text += "only to turn up later"
	if state.law.get_value(&"freespeech") == Law.ARCH_CONSERVATIVE:
		text += " [in a better place]"
	else:
		text += " dead and %s" % DESECRATION[slots["desecration"]]
	text += ".  Sources say that the police got a break in the case when "
	text += String(BREAKTHROUGH[slots["break"]])
	text += "."
	text += BREAK
	text += "   The district attorney's office has already repeatedly said it "
	text += "will be seeking "
	if state.law.get_value(&"deathpenalty") == Law.ELITE_LIBERAL:
		text += "life imprisonment in this case."
	else:
		text += "the death penalty in this case."
	text += BREAK
	return text


## A conviction overturned.
static func _justices(slots: Dictionary) -> String:
	var killer := String(slots["killer_last"])
	var judge := String(slots["judge_last"])
	var theirs := "her" if int(slots["judge_gender"]) == Gender.FEMALE else "his"
	var text := "%s - The conviction of confessed serial killer %s %s %s " \
			% [slots["city"], slots["killer_first"], slots["killer_middle"],
					killer]
	text += "was overturned by a federal judge yesterday.  "
	text += "Justice %s %s of the notoriously liberal circuit of appeals here " \
			% [slots["judge_first"], judge]
	text += "made the decision based on "
	match String(slots["reasoning"]):
		"eyewitness":
			text += "ten-year-old eyewitness testimony"
		"corruption":
			text += "%s general feeling about police corruption" % theirs
		"conspiracy":
			text += "%s belief that the crimes were a vast right-wing " % theirs
			text += "conspiracy"
		"another_chance":
			text += "%s belief that %s deserved another chance" % [theirs, killer]
		"liberty":
			text += "%s personal philosophy of liberty" % theirs
		"friendship":
			text += "%s close personal friendship with the %s family" \
					% [theirs, killer]
		"magic_eight_ball":
			text += "%s consultations with a Magic 8-Ball" % theirs
	text += ", despite the confession of %s, which even Justice %s grants was " \
			% [killer, judge]
	text += "not coerced in any way.%s" % BREAK
	text += "   Ten years ago, %s was convicted of the now-infamous %s " \
			% [killer, slots["slayings"]]
	text += "slayings.  "
	text += "After an intensive manhunt, %s was found with the murder weapon, " \
			% killer
	text += "covered in the victims' blood.  "
	text += "%s confessed and was sentenced to life, saying \"" % killer
	text += "Thank you for saving me from myself.  "
	text += "If I were to be released, I would surely kill again.\"%s" % BREAK
	text += "   A spokesperson for the district attorney "
	text += "has stated that the case will not be retried, due "
	text += "to the current economic doldrums that have left the state "
	text += "completely strapped for cash.%s" % BREAK
	return text


## A shooting stopped by somebody else with a gun.
##
## **Original quirk, reproduced.** The shooter is given a full name and then
## referred to throughout by their middle name.
static func _gun_control(state: GameState, slots: Dictionary) -> String:
	var speech := state.law.get_value(&"freespeech")
	var spree := "[hurting spree]" if speech == -2 else "mass shooting"
	var shooter := String(slots["shooter_middle"])
	var hero := "%s%s" % [TITLE[slots["title"]], slots["hero_last"]]

	var text := "%s - In a surprising turn, a %s was prevented by a bystander " \
			% [slots["city"], spree]
	text += "with a gun."
	text += " After %s %s opened fire at the %s%s, %s %s sprung into action. " \
			% [slots["shooter_first"], shooter, slots["shooter_last"],
					VENUE[slots["venue"]], slots["hero_first"],
					slots["hero_last"]]
	text += "The citizen pulled a concealed handgun and fired once at the "
	text += "shooter, forcing %s to take cover while others called the " % shooter
	text += "police.%s" % BREAK
	text += "  Initially, %s attempted to talk down the shooter, but as %s " \
			% [hero, shooter]
	text += "became more agitated, the heroic citizen was forced to engage the "
	text += "shooter in a "
	if speech == -2:
		text += "firefight, [putting the attacker to sleep] "
	else:
		text += "firefight, killing the attacker "
	text += "before "
	text += "she " if int(slots["shooter_gender"]) == Gender.FEMALE else "he "
	text += "could hurt anyone else.%s" % BREAK
	text += "  The spokesperson for the police department said, \"We'd have a "
	text += "yet another %s if not for %s's heroic actions.\"" % [spree, hero]
	return text
