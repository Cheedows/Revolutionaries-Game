class_name ImpactText
extends RefCounted
const UNARMED := ["punches", "swings at", "grapples with", "kicks", "strikes at", "jump kicks", "gracefully strikes at"]
## Impact details from src/combat/fight.cpp, using the recorded outcome only.

static func hit(attacker: String, target: String, part: String, route: String,
		verb: String, data: Dictionary) -> String:
	var line := "%s %s %s in the %s%s" % [attacker, verb, target, part, route]
	var hits := int(data.get("hits", 1))
	if hits > 1 or bool(data.get("always_describe", false)):
		line += ", " + String(data.get("hit_description", "striking"))
		if hits > 1:
			line += {2: " twice", 3: " three times", 4: " four times", 5: " five times"}.get(hits, " %d times" % hits)
	var wound := int(data.get("wound", 0))
	if wound & Wound.CLEAN_OFF:
		return line + (" CUTTING IT IN HALF!" if data.get("part") == &"body" else " CUTTING IT OFF!")
	if wound & Wound.NASTY_OFF:
		if data.get("part") == &"head": return line + " BLOWING IT APART!"
		return line + (" BLOWING IT IN HALF!" if data.get("part") == &"body" else " BLOWING IT OFF!")
	return line + String(data.get("punctuation", "."))

static func organ(who: String, data: Dictionary) -> String:
	var organ := String(data.get("organ", "body"))
	var kind := int(data.get("wound", 0))
	var index := 0 if kind & Wound.SHOT else (1 if kind & Wound.BURNED else (2 if kind & Wound.TORN else (3 if kind & Wound.CUT else 4)))
	var names := {"righteye": "right eye", "lefteye": "left eye", "upperspine": "upper spine", "lowerspine": "lower spine", "rightlung": "right lung", "leftlung": "left lung", "rightkidney": "right kidney", "leftkidney": "left kidney"}
	var name: String = names.get(organ, organ)
	var verbs: Array = ["blasted", "burned", "torn", "punctured", "punctured"]
	match organ:
		"face": verbs = ["blasted off", "burned away", "torn off", "cut away", "removed"]
		"righteye", "lefteye": verbs = ["blasted out", "burned away", "torn out", "poked out", "removed"]
		"tongue": verbs = ["blasted off", "burned away", "torn out", "cut off", "removed"]
		"nose": verbs = ["blasted off", "burned away", "torn off", "cut off", "removed"]
		"teeth": return _counted(who, data, true) + ["shot out!", "burned away!", "gouged out!", "cut out!", "knocked out!"][index]
		"neck": return who + ("'s neck bones are shattered!" if kind & Wound.SHOT else "'s neck is broken!")
		"upperspine", "lowerspine": return who + "'s " + name + (" is shattered!" if kind & Wound.SHOT else " is broken!")
		"ribs": return _counted(who, data, false) + ("shot apart!" if kind & Wound.SHOT else "broken!")
	return who + "'s " + name + " is " + String(verbs[index]) + "!"

static func _counted(who: String, data: Dictionary, teeth: bool) -> String:
	var count := int(data.get("count", 1))
	var before := int(data.get("before", count))
	if count > 1:
		return ("All " if count == before else "") + "%d of %s's %s are " % [count, who, "teeth" if teeth else "ribs"]
	if before > 1:
		return "One of " + who + ("'s teeth is " if teeth else "'s rib is ")
	return who + ("'s last tooth is " if teeth else "'s last unbroken rib is ")
