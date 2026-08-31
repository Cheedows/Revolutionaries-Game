class_name SiteText
extends RefCounted
## What the squad can see from where it is standing.
##
## The original says this a line at a time in the message area as the squad
## walks. This is the standing reading: what the square holds, who is in the
## room, and what the building thinks of the visit so far.

## What each thing on a square is called.
const FEATURES := {
	&"door": "a door", &"exit": "the way out", &"loot": "something worth taking",
	&"bloody": "blood on the floor", &"bloody2": "a great deal of blood",
	&"fire_start": "fire catching", &"fire_peak": "fire",
	&"fire_end": "smoke and ash", &"debris": "wreckage",
	&"restricted": "a door nobody is supposed to go through",
}

## The order they are worth mentioning in.
const ORDER: Array[StringName] = [
	&"fire_peak", &"fire_start", &"fire_end", &"exit", &"restricted", &"door",
	&"loot", &"debris", &"bloody2", &"bloody",
]


## One line about where the squad is standing.
static func underfoot(state: GameState) -> String:
	if state.site.map == null or state.site.location == -1:
		return ""
	var site := state.site
	var flags := site.map.get_flag(site.x, site.y, site.z)
	var seen: Array[String] = []
	for feature: StringName in ORDER:
		if flags & int(Tables.SITE_BLOCKS[feature]) != 0:
			seen.append(String(FEATURES[feature]))
	if site.map.get_special(site.x, site.y, site.z) != LevelMap.NO_SPECIAL:
		seen.append("something to work with")

	var parts: Array[String] = []
	parts.append("Here: %s." % (", ".join(seen) if not seen.is_empty()
			else "nothing but floor"))
	if not site.ground_loot.is_empty():
		parts.append("%d thing%s on the floor." % [site.ground_loot.size(),
				"" if site.ground_loot.size() == 1 else "s"])
	if not site.encounter_ids.is_empty():
		parts.append("%d in the room." % site.encounter_ids.size())
	if site.alarm:
		parts.append("The building knows you are here.")
	return " ".join(parts)
