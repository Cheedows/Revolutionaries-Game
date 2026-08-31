class_name IntentText
extends RefCounted
## Turns a question the simulation is asking into words.
##
## The counterpart to [EventText]: an [Intent] carries a type, a context and a
## list of options, and no prose at all. This is the only place that knows what
## each of them should say.

## What each kind of question is asking, in the second person.
const QUESTIONS := {
	Intent.CHOOSE_BASE_ACTION: "What now?",
	Intent.ASSIGN_ACTIVITY: "What should they be doing?",
	Intent.FORM_SQUAD: "Who is going?",
	Intent.EQUIP_SQUAD: "What are they taking?",
	Intent.CHOOSE_VEHICLE: "What are they driving?",
	Intent.CHOOSE_DESTINATION: "Where to?",
	Intent.CHOOSE_CAR_TYPE: "What kind of car?",
	Intent.APPROACH_CAR: "Try this one?",
	Intent.FORCE_CAR_DOOR: "Force the door?",
	Intent.START_CAR: "Get it started?",
	Intent.CHOOSE_SITE_MOVE: "What does the squad do?",
	Intent.CHOOSE_ENCOUNTER_RESPONSE: "They are right there.",
	Intent.CHOOSE_ATTACK_TARGET: "Who first?",
	Intent.CHOOSE_CHASE_ACTION: "They are still behind you.",
	Intent.CONFIRM_RETREAT: "Pull out?",
	Intent.CONFIRM_NOISY_DOOR: "It will make a noise.",
	Intent.CONFIRM_PICK_LOCK: "Pick the lock?",
	Intent.CONFIRM_FORCE_DOOR: "Break it down?",
	Intent.CHOOSE_DATE_APPROACH: "How does the evening go?",
	Intent.CHOOSE_DIALOGUE: "What do you say?",
	Intent.CHOOSE_INTERROGATION_TACTIC: "How do you ask?",
	Intent.CONFIRM_RECRUIT: "Bring them in?",
	Intent.CHOOSE_DEFENSE: "How is the case run?",
	Intent.CHOOSE_SHOP_DEPARTMENT: "Which counter?",
	Intent.CHOOSE_PURCHASE: "Buy what?",
	Intent.CHOOSE_ITEMS_TO_FENCE: "Sell what?",
	Intent.CHOOSE_LIBERAL_AGENDA: "What matters most?",
	Intent.ACKNOWLEDGE_REPORT: "",
	Intent.CONFIRM_NEW_GAME: "Start again?",
	Intent.CHOOSE_FOUNDER_BACKGROUND: "And then?",
}

## What a question with no options at all offers instead.
const CARRY_ON := "Carry on"

## What declining looks like, by question. Everything else says "Never mind".
const REFUSALS := {
	Intent.CONFIRM_RETREAT: "Stay",
	Intent.CONFIRM_RECRUIT: "Leave them",
	Intent.CHOOSE_ATTACK_TARGET: "Hold fire",
}


## The question itself.
static func question(intent: Intent, state: GameState) -> String:
	var asked := String(QUESTIONS.get(intent.type,
			String(intent.type).capitalize() + "?"))
	if intent.type == Intent.ASSIGN_ACTIVITY or intent.type == Intent.CHOOSE_DIALOGUE:
		var who := _who(state, int(intent.context.get("creature", 0)))
		if not who.is_empty():
			return "%s — %s" % [who, asked]
	return asked


## A line under the question, when the context has something worth saying.
static func detail(intent: Intent, state: GameState) -> String:
	var context := intent.context
	var lines := PackedStringArray()
	if context.has("location"):
		var site: Location = state.locations.get(int(context["location"]))
		if site != null:
			lines.append(site.name)
	if context.has("attacker"):
		lines.append("%s outside" % String(context["attacker"]).capitalize())
	if context.has("chasers"):
		lines.append("%d after you" % int(context["chasers"]))
	if bool(context.get("in_cars", false)):
		lines.append("in the car")
	return ", ".join(lines)


## What one option's button should say.
##
## An option is a dictionary the system built; anything with a "label" says so
## itself, and the rest are named from whatever they do carry.
static func option(entry: Dictionary, state: GameState) -> String:
	if entry.has("label"):
		return String(entry["label"])
	if entry.has("creature"):
		return _who(state, int(entry["creature"]))
	if entry.has("name"):
		return String(entry["name"])
	if entry.has("type"):
		return String(entry["type"]).capitalize().replace("_", " ")
	return "Option %s" % entry.get("id", "?")


## Whether the option can be taken. Systems mark the ones that cannot.
static func enabled(entry: Dictionary) -> bool:
	return bool(entry.get("enabled", true))


## What the option costs or is worth, shown beside it.
static func note(entry: Dictionary) -> String:
	if entry.has("price"):
		return "$%d" % int(entry["price"])
	if entry.has("note"):
		return String(entry["note"])
	return ""


## What refusing this question is called.
static func refusal(intent: Intent) -> String:
	return String(REFUSALS.get(intent.type, "Never mind"))


static func _who(state: GameState, id: int) -> String:
	var creature: Creature = state.creatures.get(id)
	return creature.name if creature != null else ""
