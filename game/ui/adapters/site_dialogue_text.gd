class_name SiteDialogueText
extends RefCounted
## Reconstructs the actual exchange from the original, using recorded rolls.

static func recruitment(event: Event, state: GameState) -> String:
	var data := event.data
	var speaker: Creature = state.creatures.get(data.get("by", -1))
	var listener: Creature = state.creatures.get(data.get("creature", -1))
	if speaker == null or listener == null:
		return ""
	var lines: Array[String] = [speaker.name + " says, \"Do you want to hear something disturbing?\""]
	if data.get("opening_only", false):
		var response := "\"No.\" <turns away>"
		if listener.name == "Prisoner":
			response = "\"Now's not the time!\"" if listener.alignment == &"liberal" else "\"Leave me alone.\""
			response += " <turns away>"
		if listener.animal_gloss == &"tank":
			lines.append(listener.name + " rumbles disinterestedly.")
		elif listener.animal_gloss == &"animal" and listener.alignment != &"liberal":
			lines.append(listener.name + (" barks." if listener.type == &"CREATURE_GUARDDOG" else " doesn't understand."))
		else:
			lines.append(listener.name + " responds, " + response)
		return "\n".join(lines)
	lines.append(listener.name + " responds, \"What?\"")
	lines.append(speaker.name + " says, " + _argument(data, state, listener))
	var accepted := event.type == Event.RECRUIT_INTERESTED
	var reply := int(data.get("reply", 0))
	var response := ""
	if data.get("dim", false):
		response = "\"Aaaahhh...\"" if accepted else "\"Ugh.  Pfft.\""
	elif accepted:
		response = "".join(SiteDialogueTables.ACCEPT[reply]) if reply != 4 else SiteDialogueTables.ACCEPT[reply][0]
	elif listener.alignment == &"conservative" and data.get("fumbled", false):
		if listener.type == &"CREATURE_GANGUNIT":
			response = "\"Do you want me to arrest you?\""
		elif listener.type == &"CREATURE_DEATHSQUAD":
			response = "\"If you don't shut up, I'm going to shoot you.\""
		else:
			response = "".join(SiteDialogueTables.REBUFF[reply])
	elif data.get("counterargument", false):
		response = "".join(SiteDialogueTables.COUNTERARGUMENT.get(String(data.issue), []))
	else:
		response = "\"Whatever.\""
	lines.append(listener.name + " responds, " + response + ("" if accepted else " <turns away>"))
	if accepted:
		if not data.get("dim", false) and reply == 4:
			lines.append(speaker.name + " says, " + "\"Yeah, really!\"")
		lines.append("After more discussion, " + listener.name + " agrees to come by later tonight.")
	return "\n".join(lines)


static func _argument(data: Dictionary, state: GameState, listener: Creature) -> String:
	var issue := String(data.get("issue", ""))
	var table: Dictionary = SiteDialogueTables.ARGUMENT
	if data.get("fumbled", false):
		table = SiteDialogueTables.FUMBLED
	elif data.get("too_liberal", false):
		table = SiteDialogueTables.WON_ISSUE
	var parts: Array = table.get(issue, [])
	if data.get("fumbled", false) and issue == "policebehavior":
		return parts[0 if state.law.get_value(&"freespeech") == -2 else 1]
	if not data.get("fumbled", false) and not data.get("too_liberal", false) and issue == "pollution":
		return parts[0] + parts[1 if listener.animal_gloss == &"animal" else 2]
	var words: Array[String] = []
	for part: String in parts:
		words.append(part.strip_edges())
	return " ".join(words)


static func flirting(state: GameState, data: Dictionary) -> String:
	var speaker: Creature = state.creatures.get(data.get("by", -1))
	var listener: Creature = state.creatures.get(data.get("creature", -1))
	if speaker == null or listener == null:
		return ""
	var lines: Array[String] = [speaker.name + " says, " + FlirtText.said(data)]
	var outcome: StringName = data.get("outcome", &"")
	var response := ""
	if outcome == &"wrong_uniform":
		response = "\"Dirty. You know that's illegal, officer.\""
	elif outcome == &"wrong_species":
		if listener.type == &"CREATURE_TANK":
			lines.append(listener.name + " shakes its turret a firm 'no'.")
		elif listener.type in [&"CREATURE_GUARDDOG", &"CREATURE_GENETIC"]:
			var replies: Array = SiteDialogueTables.DOG_REPLIES if listener.type == &"CREATURE_GUARDDOG" else SiteDialogueTables.MONSTER_REPLIES
			response = replies[clampi(int(data.get("reply", 0)), 0, replies.size() - 1)]
		else:
			lines.append(listener.name + " doesn't quite pick up on the subtext.")
	elif outcome == &"refused" and listener.type == &"CREATURE_CORPORATE_CEO":
		response = "\"This ain't Brokeback Mountain, son.\"" if speaker.gender_liberal == &"male" else "\"I'm a happily married man, sweetie.\""
	else:
		var replies: Array = SiteDialogueTables.FLIRT_ACCEPT if outcome == &"agreed" else SiteDialogueTables.FLIRT_REFUSE
		if data.get("censored", false):
			replies = SiteDialogueTables.FLIRT_ACCEPT_CENSORED if outcome == &"agreed" else SiteDialogueTables.FLIRT_REFUSE_CENSORED
		response = replies[int(data.get("line", 0)) % replies.size()]
	if not response.is_empty():
		lines.append(listener.name + " responds, " + response)
	if outcome == &"agreed":
		lines.append(speaker.name + " and " + listener.name + " make plans for tonight" + (", and " + listener.name + " breaks for the exit" if listener.name == "Prisoner" else "") + ".")
	return "\n".join(lines)
