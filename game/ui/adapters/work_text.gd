class_name WorkText
extends RefCounted
## What the log says about the rest of the day's work.
##
## Painting walls, hacking, standing in a crowd that turns, sewing, studying,
## burying somebody, and everything that happens to a car or a piece of kit.
## The wording is from src/daily/activities.cpp and src/daily/shopsnstuff.cpp.

## What a repair or a garment came out as.
## What a Liberal at the sewing machine did, from repairarmor() in
## src/daily/activities.cpp, where the sentence is built a piece at a time.
##
## These keys are the ones [Tailoring] actually emits. They did not used to be:
## the adapter was keyed on four names the simulation never sends, so every
## repair in the game fell through to the same line.
const OUTCOMES := {
	&"disposed": " disposes of ",
	&"cleaned": " cleans ",
	&"working": " is working to repair ",
	&"repaired": " repairs ",
	&"hopeless": " finds there is no hope of repairing ",
	&"patched": " repairs what little can be fixed of ",
}
const RUINED := " ruined"

## A mural this good is a beautiful one, from src/daily/activities.cpp.
const BEAUTIFUL := 3

## The original prints nothing for a tag that went unnoticed — it only says
## anything when the police saw it — so this line is the port's, because a log
## that is a record rather than a screen has to say the day happened.
const TAGGED := "%s spends the day tagging walls."


## A garment worked on: what was done to it, whose it was, and whether it
## survived. The original assembles this sentence in that order.
static func _repaired(state: GameState, data: Dictionary) -> String:
	var did := String(OUTCOMES.get(data.get("outcome", &""), " repairs "))
	var whose := "a" if bool(data.get("from_a_pile", false)) else "their"
	var ruined := RUINED if bool(data.get("ruined", false)) else ""
	return "%s%s%s%s %s." % [_who(state, data), did, whose, ruined,
			_thing(data, "armor")]


## The line for [param event], or "" for one this does not cover.
static func describe(event: Event, state: GameState) -> String:
	var data := event.data
	match event.type:
		# --- Walls and websites -----------------------------------------
		Event.GRAFFITI_TAGGED:
			return TAGGED % _who(state, data)
		Event.GRAFFITI_MURAL_STARTED:
			return "%s has begun work on a large mural about %s." % [
					_who(state, data), _issue(data)]
		Event.GRAFFITI_MURAL_WORKED:
			return "%s works through the night on a large mural." \
					% _who(state, data)
		Event.GRAFFITI_MURAL_DONE:
			# A good enough mural is a beautiful one, which the original says
			# by putting the word in.
			return "%s has completed a%s mural about %s." % [
					_who(state, data),
					" beautiful" if int(data.get("power", 0)) > BEAUTIFUL
							else "", _issue(data)]
		Event.GRAFFITI_SPOTTED:
			return "%s was spotted by the police%s" % [_who(state, data),
					" while working on the mural!"
					if bool(data.get("mural", false))
					else " while spraying an LCS tag!"]
		Event.SPRAYCAN_TAKEN:
			return TAGGED % _who(state, data)
		Event.SPRAYCAN_BOUGHT:
			return "%s bought spraypaint for graffiti." % _who(state, data)
		Event.SPRAYCAN_MISSING:
			return "%s needs a spraycan equipped to do graffiti." \
					% _who(state, data)
		Event.HACK_SUCCEEDED:
			return "The websites are broken into."
		Event.HACK_DEFACED:
			return "A site is defaced over %s." % _issue(data)
		Event.BROADCAST_AIRED:
			return "The squad gets on the air about %s." % String(
					data.get("subject", &"something")).replace("_", " ")
		# --- A crowd that turns -----------------------------------------
		Event.MOB_CORNERED, Event.MOB_SCATTERED, Event.MOB_EXCHANGE, \
				Event.MOB_BEAT_THEM, Event.MOB_BEATEN:
			return MobText.describe(event, state)
		# --- The safehouse ----------------------------------------------
		Event.ARMOR_REPAIRED:
			return _repaired(state, data)
		Event.ARMOR_MADE:
			return "%s makes %s." % [_who(state, data), _thing(data, "armor")]
		Event.ARMOR_UNAFFORDABLE:
			return "%s cannot afford material for clothing." % _who(state, data)
		Event.ARMOR_NO_CLOTH:
			return "%s cannot find enough cloth to reduce clothing costs." \
					% _who(state, data)
		Event.STUDY_FINISHED:
			return "%s has learned all the course can teach about %s." % [
					_who(state, data),
					String(data.get("skill", &"it")).replace("_", " ")]
		Event.BODY_BURIED:
			return "%s is buried." % _who(state, data)
		Event.TREATMENT_NEEDED:
			return "%s needs a hospital." % _who(state, data)
		Event.CREATURE_HOSPITALIZED:
			return "%s is taken to hospital for %d month(s)." % [
					_who(state, data), int(data.get("months", 0))]
		Event.FLAG_RAISED:
			return "A flag goes up over %s." % _place(state, data)
		Event.FLAG_BURNED:
			return "The flag over %s comes down and burns." % _place(state, data)
		Event.ACTIVITY_RESOLVED:
			return ""  # the assignment's own events say what came of it
		# --- Cars and kit ------------------------------------------------
		Event.CAR_ALARM, Event.CAR_SEARCHED, Event.CAR_NERVES, \
				Event.CAR_THEFT_SPOTTED, Event.CAR_OPENED, \
				Event.CAR_STARTED, Event.CAR_HOTWIRE_FAILED:
			return CarTheftText.describe(event, state)
		Event.CAR_TAKEN:
			return "The car is gone."
		Event.CAR_BOUGHT:
			return "%s buys a car for $%d." % [_who(state, data),
					int(data.get("price", 0))]
		Event.CAR_SOLD:
			return "%s sells a car for $%d." % [_who(state, data),
					int(data.get("price", 0))]
		Event.ITEM_BOUGHT:
			return "%s buys %s for $%d." % [_who(state, data),
					_thing(data, "item"), int(data.get("price", 0))]
		Event.ITEM_ACQUIRED:
			return "%s picks up %s." % [_who(state, data), _thing(data, "item")]
		Event.ITEM_EQUIPPED:
			return ""  # the kit list says what they are carrying
		Event.ITEM_LOST:
			return "Something is left behind."
		Event.ITEM_DAMAGED:
			return "%s is the worse for it." % _thing(data, "item")
		Event.ITEM_DESTROYED:
			return "%s is ruined." % _thing(data, "item")
		Event.ITEM_FENCED:
			return "Sold: %s, for $%d." % [_thing(data, "item"),
					int(data.get("amount", 0))]
		Event.GUN_SOUGHT:
			return _gun(data)
	return ""


## Trying to buy a gun somewhere that may not sell them.
## Asking somebody where to get a gun, and what they say back. Every line is
## heyINeedAGun()'s, from src/sitemode/talk.cpp; the port's outcome names are
## that function's branches in order.
const ASKING := "\"Hey, I need a gun.\""
const ANSWERS := {
	&"naked": "\"Jesus...\"",
	&"uniform": "\"I don't sell guns, officer.\"",
	&"alarm": "\"We can talk when things are calm.\"",
	&"wrong_place": "\"Uhhh... not a good place for this.\"",
	&"trading": "\"What exactly do you need?\"",
}


static func _gun(data: Dictionary) -> String:
	return "%s %s" % [ASKING,
			String(ANSWERS.get(data.get("outcome", &""), ANSWERS[&"trading"]))]


## The issue a thing was about.
static func _issue(data: Dictionary) -> String:
	var view: StringName = data.get("issue", &"")
	return String(EventText.LAW_NAMES.get(view,
			String(view).capitalize())).to_lower()


## An item or a garment, said the way a person would say it.
static func _thing(data: Dictionary, key: String) -> String:
	var idname := String(data.get(key, &"something"))
	for prefix in ["ARMOR_", "WEAPON_", "LOOT_", "CLIP_"]:
		idname = idname.trim_prefix(prefix)
	return idname.replace("_", " ").to_lower()


static func _place(state: GameState, data: Dictionary) -> String:
	var site: Location = state.locations.get(data.get("location", -1))
	return site.name if site != null else "the safehouse"


static func _who(state: GameState, data: Dictionary) -> String:
	var creature: Creature = state.creatures.get(data.get("creature", 0))
	return creature.name if creature != null and creature.name != "" \
			else "Someone"
