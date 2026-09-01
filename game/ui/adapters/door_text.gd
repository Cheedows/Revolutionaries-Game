class_name DoorText
extends RefCounted
## What the people on the door say.
##
## Split from site_report_text.gd because it is nine hundred words of dialogue
## and one file was over the length the layer rules allow.

## What the door staff say, word for word from the switches in
## src/sitemode/mapspecials.cpp.
##
## Each complaint has several ways of saying it and the original rolls between
## them. That roll happens in the simulation either way — it moves the
## generator — so [Bouncer] and [SecurityCheck] carry which line came up, and
## this says the line rather than a summary of what the line meant. A club
## bouncer and a guard on a checkpoint object to the same things in quite
## different words, so they get a list each.
const CLUB := {
	&"ccs": [
		"\"Can I see... heh heh... some ID?\"",
		"\"Woah... you think you're coming in here?\"",
		"\"Check out this fool. Heh.\"",
		"\"Want some trouble, dumpster breath?\"",
		"\"You're gonna stir up the hornet's nest, fool.\"",
		"\"Come on, take a swing at me. Just try it.\"",
		"\"You really don't want to fuck with me.\"",
		"\"Hey girly, have you written your will?\"",
		"\"Oh, you're trouble. I *like* trouble.\"",
		"\"I'll bury you in those planters over there.\"",
		"\"Looking to check on the color of your blood?\"",
	],
	&"nude": [
		"\"No shirt, no underpants, no service.\"",
		"\"Put some clothes on! That's disgusting.\"",
		"\"No! No, you can't come in naked! God!!\"",
		"\"No shoes, no shirt and you don't get service\"",
	],
	&"underage": [
		"\"Hahaha, come back in a few years.\"",
		"\"Find some kiddy club.\"",
		"\"You don't look 18 to me.\"",
		"\"Go back to your treehouse.\"",
		"\"Where's your mother?\"",
	],
	&"female": [
		"\"Move along ma'am, this club's for men.\"",
		"\"This 'ain't no sewing circle, ma'am.\"",
		"\"Sorry ma'am, this place is only for the men.\"",
		"\"Where's your husband?\"",
	],
	&"femaleish": [
		"\"You /really/ don't look like a man to me...\"",
		"\"Y'know... the 'other' guys won't like you much.\"",
		"\"Uhh... can't let you in, ma'am. Sir. Whatever.\"",
	],
	&"dress_code": [
		"\"Check the dress code.\"",
		"\"We have a dress code here.\"",
		"\"I can't let you in looking like that.\"",
	],
	&"smell_funny": [
		"\"God, you smell.\"",
		"\"Not letting you in. Because I said so.\"",
		"\"There's just something off about you.\"",
		"\"Take a shower.\"",
		"\"You'd just harass the others, wouldn't you?\"",
		"\"Get the hell out of here.\"",
	],
	&"bloody_clothes": [
		"\"Good God! What is wrong with your clothes?\"",
		"\"Absolutely not. Clean up a bit.\"",
		"\"This isn't a goth club, bloody clothes don't cut it here.\"",
		"\"Uh, maybe you should wash... replace... those clothes.\"",
		"\"Did you spill something on your clothes?\"",
		"\"Come back when you get the red wine out of your clothes.\"",
	],
	&"damaged_clothes": [
		"\"Good God! What is wrong with your clothes?\"",
		"\"This isn't a goth club, ripped clothes don't cut it here.\"",
	],
	&"second_rate_clothes": [
		"\"That looks like you sewed it yourself.\"",
		"\"If badly cut clothing is a hot new trend, I missed it.\"",
	],
	&"weapons": [
		"\"No weapons allowed.\"",
		"\"I can't let you in carrying that.\"",
		"\"I can't let you take that in.\"",
		"\"Come to me armed, and I'll tell you to take a hike.\"",
		"\"Real men fight with fists. And no, you can't come in.\"",
	],
	&"guest_list": ["\"This club is by invitation only.\""],
	&"admitted": [
		"\"Keep it civil and don't drink too much.\"",
		"\"Let me get the door for you.\"",
		"\"Ehh, alright, go on in.\"",
		"\"Come on in.\"",
	],
}

## The same, at a checkpoint rather than a door.
const CHECKPOINT := {
	&"nude": [
		"\"Get out of here you nudist!!\"",
		"\"Back off, creep!\"",
		"\"Jesus!! Somebody call the cops!\"",
		"\"Are you sleepwalking?!\"",
	],
	&"underage": [
		"\"No admittance, youngster.\"",
		"\"You're too young to work here.\"",
		"\"Go play someplace else.\"",
		"\"Where's your mother?\"",
	],
	&"dress_code": ["\"Employees only.\""],
	&"smell_funny": [
		"\"You don't work here, do you?\"",
		"\"Hmm... can I see your badge?\"",
		"\"There's just something off about you.\"",
		"\"You must be new. You'll need your badge.\"",
	],
	&"bloody_clothes": [
		"\"Good God! What is wrong with your clothes?\"",
		"\"Are you hurt?! The aid station is the other way!\"",
		"\"Your clothes, that's blood!\"",
		"\"Blood?! That's more than a little suspicious...\"",
		"\"Did you just butcher a cat?!\"",
		"\"Blood everywhere...?\"",
	],
	&"damaged_clothes": [
		"\"Good God! What is wrong with your clothes?\"",
		"\"Is that a damaged halloween costume?\"",
	],
	&"second_rate_clothes": [
		"\"That looks like you sewed it yourself.\"",
		"\"That's a poor excuse for a uniform. Who are you?\"",
	],
	&"weapons": [
		"\"Put that away!\"",
		"\"Hey, back off!\"",
		"\"Don't try anything!\"",
		"\"Are you here to make trouble?\"",
		"\"Stay back!\"",
	],
	&"admitted": [
		"\"Move along.\"",
		"\"Have a nice day.\"",
		"\"Quiet day, today.\"",
		"\"Go on in.\"",
	],
}

## What a guard who already knows the squad says to somebody with no clothes
## on. The original does not roll for this one.
const NUDE_TO_A_KNOWN_FACE := "\"Jesus! Put some clothes on!\""

## What the door staff said, and what they were looking at.
static func said(data: Dictionary) -> String:
	var metal_detector := bool(data.get("metal_detector", false))
	var reason: StringName = StringName(data.get("reason", &""))
	if metal_detector and reason == &"weapons":
		# A metal detector does not argue; it just goes off.
		return "-BEEEP- -BEEEP- -BEEEP-"
	var at_a_checkpoint := data.has("metal_detector")
	if at_a_checkpoint and reason == &"nude" and int(data.get("badge", 0)) > 0:
		return NUDE_TO_A_KNOWN_FACE
	var lines: Array = (CHECKPOINT if at_a_checkpoint else CLUB).get(reason, [])
	if lines.is_empty():
		return "They look the squad over."
	return String(lines[int(data.get("line", 0)) % lines.size()])


## See opened(): the original prints nothing when a door is simply pushed.
const PUSHED_OPEN := "The door opens."


## Getting a door open by force, from unlock() in src/sitemode/miscactions.cpp.
## Which line depends on what was in the squad's hands.
const FORCED := {
	&"crowbar": "uses a crowbar on the door",
	&"bash": "smashes in the door",
	&"wheelchair": "rams open the door",
	&"kick": "kicks in the door",
}


## A door coming open, forced or simply pushed.
##
## The original says nothing when a door is simply pushed open — the squad
## moves and that is the report — but an event that renders to nothing is the
## failure this port keeps having, so the log says the plain thing instead.
static func opened(state: GameState, data: Dictionary) -> String:
	if not bool(data.get("forced", false)):
		return PUSHED_OPEN
	var how := &"crowbar" if bool(data.get("crowbar", false)) else &"kick"
	return "%s %s!" % [_name(state, int(data.get("creature", 0))),
			String(FORCED[how])]


static func _name(state: GameState, id: int) -> String:
	var creature: Creature = state.creatures.get(id)
	return creature.name if creature != null and creature.name != "" \
			else "Someone"
