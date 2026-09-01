class_name WorkText
extends RefCounted
## What the log says about the rest of the day's work.
##
## Painting walls, hacking, standing in a crowd that turns, sewing, studying,
## burying somebody, and everything that happens to a car or a piece of kit.
## The wording is from src/daily/activities.cpp and src/daily/shopsnstuff.cpp.

## What a repair or a garment came out as.
const OUTCOMES := {
	&"ruined": "and ruins it",
	&"shoddy": "and it comes out worse than it went in",
	&"mended": "and it is as good as it was",
	&"improved": "and it comes out better",
}


## The line for [param event], or "" for one this does not cover.
static func describe(event: Event, state: GameState) -> String:
	var data := event.data
	match event.type:
		# --- Walls and websites -----------------------------------------
		Event.GRAFFITI_TAGGED:
			return "%s paints the slogan on a wall." % _who(state, data)
		Event.GRAFFITI_MURAL_STARTED:
			return "%s starts a mural about %s." % [_who(state, data),
					_issue(data)]
		Event.GRAFFITI_MURAL_WORKED:
			return "%s works on the mural." % _who(state, data)
		Event.GRAFFITI_MURAL_DONE:
			return "%s finishes the mural about %s." % [_who(state, data),
					_issue(data)]
		Event.GRAFFITI_SPOTTED:
			return "%s is seen with the can in their hand." % _who(state, data)
		Event.SPRAYCAN_TAKEN:
			return "%s takes a spray can%s." % [_who(state, data),
					" from the stores"
					if bool(data.get("from_base", false)) else ""]
		Event.SPRAYCAN_BOUGHT:
			return "%s buys a spray can." % _who(state, data)
		Event.SPRAYCAN_MISSING:
			return "%s has nothing to paint with." % _who(state, data)
		Event.HACK_SUCCEEDED:
			return "The websites are broken into."
		Event.HACK_DEFACED:
			return "A site is defaced over %s." % _issue(data)
		Event.BROADCAST_AIRED:
			return "The squad gets on the air about %s." % String(
					data.get("subject", &"something")).replace("_", " ")
		# --- A crowd that turns -----------------------------------------
		Event.MOB_CORNERED:
			return "%s is cornered by a crowd." % _who(state, data)
		Event.MOB_SCATTERED:
			return "The crowd around %s scatters." % _who(state, data)
		Event.MOB_EXCHANGE:
			return "%s %s the exchange." % [_who(state, data),
					"wins" if bool(data.get("won", false)) else "loses"]
		Event.MOB_BEAT_THEM:
			return "%s gets the better of them." % _who(state, data)
		Event.MOB_BEATEN:
			return "%s takes a beating." % _who(state, data)
		# --- The safehouse ----------------------------------------------
		Event.ARMOR_REPAIRED:
			return "%s mends %s, %s." % [_who(state, data), _thing(data, "armor"),
					String(OUTCOMES.get(data.get("outcome", &""),
							"and puts it back"))]
		Event.ARMOR_MADE:
			return "%s makes %s." % [_who(state, data), _thing(data, "armor")]
		Event.ARMOR_UNAFFORDABLE:
			return "%s cannot afford the cloth for %s." % [_who(state, data),
					_thing(data, "armor")]
		Event.ARMOR_NO_CLOTH:
			return "There is no cloth left for %s." % _thing(data, "armor")
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
		Event.CAR_ALARM:
			return "The alarm goes off."
		Event.CAR_SEARCHED:
			return "%s goes through it." % _who(state, data)
		Event.CAR_NERVES:
			return "%s loses their nerve and walks away." % _who(state, data)
		Event.CAR_THEFT_SPOTTED:
			return "Somebody saw %s at the car." % _who(state, data)
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
static func _gun(data: Dictionary) -> String:
	match data.get("outcome", &""):
		&"bought":
			return "The shop sells them one."
		&"refused":
			return "The shop will not sell them one."
		&"waiting_period":
			return "There is a waiting period."
	return "They ask about a gun."


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
