class_name SiteReportText
extends RefCounted
## What the log says about being inside a building.
##
## The wording is from src/sitemode/: stealth.cpp for being noticed,
## mapspecials.cpp for the door staff and the specials, and sitemode.cpp for
## the rest.

## What the site's own status line says once the room has turned on the squad.
const ALIENATED: Array[String] = ["ALIENATED MASSES", "ALIENATED EVERYONE"]

## What was opened, from unlock() in src/sitemode/miscactions.cpp.
const UNLOCKS := {
	&"door": "unlocks the door",
	&"cage": "unlocks the cage",
	&"cage_hard": "unlocks the cage",
	&"cell": "unlocks the cell",
	&"armory": "opens the armory",
	&"safe": "cracks the safe",
	&"vault": "cracks the combo locks",
}

## What somebody does when their nerve goes, from blew_stealth_check[] in
## src/sitemode/stealth.cpp.
const FUMBLES: Array[String] = [
	"%s coughs.",
	"%s accidentally mumbles the slogan.",
	"%s paces uneasily.",
	"%s stares at the Conservatives.",
	"%s laughs nervously.",
]

## The line for [param event], or "" for one this does not cover.
static func describe(event: Event, state: GameState) -> String:
	var data := event.data
	match event.type:
		Event.SITE_ALARM_RAISED:
			return "The alarm goes off!"
		Event.SITE_ALIENATED:
			return ALIENATED[clampi(int(data.get("level", 1)), 1, 2) - 1]
		Event.SITE_PANIC_SENSED:
			return "CONSERVATIVES SUSPICIOUS"
		Event.SQUAD_UNSEEN:
			return "The squad sneaks past the conservatives!"
		Event.SQUAD_ACTED_NATURAL:
			return "The squad acts natural."
		Event.SQUAD_FUMBLED:
			return FUMBLES[clampi(int(data.get("manner", 0)), 0,
					FUMBLES.size() - 1)] % _who(state, data)
		Event.SQUAD_BLOCKED:
			return "There is no way through there."
		Event.SQUAD_SURRENDERED:
			return "The squad gives up."
		Event.ENCOUNTER_STARTED:
			return "Somebody is coming."
		Event.ENEMY_FLED:
			return "%s runs%s." % [_who(state, data),
					", dragging themselves"
					if bool(data.get("crawling", false)) else ""]
		Event.ENEMY_ROUTED:
			return "They break and run."
		Event.STAIRS_TAKEN:
			return "The squad goes %s." % (
					"up" if bool(data.get("up", false)) else "down")
		Event.SIGN_READ:
			return "A sign: %s." % String(data.get("sign", &"nothing")) \
					.replace("_", " ")
		Event.DOOR_UNLOCKED:
			return "%s %s!" % [_who(state, data),
					String(UNLOCKS.get(data.get("kind", &"door"),
							"unlocks the door"))]
		Event.DOOR_ASSESSED:
			return DoorText.said(data)
		Event.BLUFF_TRIED:
			return "They %s the story." % (
					"buy" if bool(data.get("fooled", false)) else "do not buy")
		Event.ANIMAL_ADDRESSED:
			return "The animals %s." % (
					"understand" if bool(data.get("won_over", false))
					else "do not understand")
		Event.BODY_DROPPED:
			return "%s is put down." % _who(state, data)
		Event.CREATURE_SPAWNED:
			return ""  # somebody arriving is the encounter's news, not theirs
		# --- What the squad came for ------------------------------------
		Event.VAULT_OPENED:
			return "The vault is open."
		Event.TELLER_ROBBED:
			return _teller(state, data)
		Event.LOOT_TAKEN:
			return "The squad takes what is here."
		Event.LOOT_FENCED:
			return "Sold: %s, for $%d." % [
					String(data.get("kind", &"something")).trim_prefix("LOOT_")
							.replace("_", " ").to_lower(),
					int(data.get("paid", 0))]
		Event.PRISONERS_FREED:
			return "%d prisoners are let out." % int(data.get("count", 0))
		Event.OPPRESSED_FREED:
			return _freed(data)
		Event.COMPUTER_HACKED:
			return "%s gets into the machine." % _who(state, data)
		Event.COMPUTER_RESISTED:
			return "The machine will not have it."
		Event.OVAL_OFFICE:
			return "This is the Oval Office."
		Event.CCS_BOSS_FOUND:
			return "The Conservative Crime Squad's boss is here%s." % (
					"" if bool(data.get("ready", false))
					else ", and not ready for this")
		Event.SITE_CAPTURED:
			return "%s belongs to the squad now." % _place(state, data)
		Event.SITE_CLOSED:
			return "%s is closed for %d days." % [_place(state, data),
					int(data.get("days", 0))]
		Event.SITE_SECURED:
			return "%s will be harder to get into next time." % _place(state,
					data)
		Event.SITE_REMODELLED:
			return "%s has been rebuilt." % _place(state, data)
	return ""


## The teller, and how much of a scene it was. A note is its own exchange; a
## gun in the air is the other branch of the same prompt.
static func _teller(state: GameState, data: Dictionary) -> String:
	if data.has("note"):
		return TellerText.robbed(state, data)
	if not bool(data.get("worked", true)):
		return "%s asks, and gets nowhere." % _who(state, data)
	return "%s empties the drawer at gunpoint." % _who(state, data)


## Letting somebody out of a cage, and who came along afterwards.
static func _freed(data: Dictionary) -> String:
	var freed := int(data.get("freed", 0))
	var joined := int(data.get("joined", 0))
	if freed == 0:
		return "There is nobody left to let out."
	if joined == 0:
		return "%d are let out, and go their own way." % freed
	return "%d are let out, and %d of them come along." % [freed, joined]


static func _place(state: GameState, data: Dictionary) -> String:
	var site: Location = state.locations.get(data.get("location", -1))
	return site.name if site != null else "the place"


static func _who(state: GameState, data: Dictionary) -> String:
	var creature: Creature = state.creatures.get(data.get("creature", 0))
	return creature.name if creature != null and creature.name != "" \
			else "Someone"
