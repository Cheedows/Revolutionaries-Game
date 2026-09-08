class_name InterrogationDialogue
extends RefCounted
## Dialogue from src/daily/interrogation.cpp. Picks are made in core, never here.

const LINES := {
	&"props": [
		"{by} plays violent video games with {who}.",
		"{by} reads Origin of the Species to {who}.",
		"{by} burns flags in front of {who}.",
		"{by} explores an elaborate political fantasy with {who}.",
		"{by} watches controversial avant-garde films with {who}.",
		"{by} plays the anime film Bible Black for {who}.",
		"{by} watches a documentary about Emmett Till with {who}.",
		"{by} watches Michael Moore films with {who}.",
		"{by} listens to Liberal radio shows with {who}.",
	],
	&"opening": [
		"{by} talks about {issue} with {who}.", "{by} argues about {issue} with {who}.",
		"{by} tries to expose the true Liberal side of {who}.", "{by} attempts to recruit {who}.",
	],
	&"psychology": [
		"{who} plays mind games with {by}.", "{who} knows how this works, and won't budge.",
		"{who} asks if Liberal mothers would approve of this.",
		"{who} seems resistant to this form of interrogation.",
	],
	&"religion": [
		"{by} is unable to shake {who}'s religious conviction.",
		"{who} will never be broken so long as God grants it strength.",
		"{by}'s efforts to question {who}'s faith seem futile.",
		"{who} calmly explains the Conservative tenets of its faith.",
	],
	&"business": [
		"{who} will never be moved by {by}'s pathetic economic ideals.",
		"{who} wishes a big company would just buy the LCS and shut it down.",
		"{who} explains to {by} why communism failed.", "{who} mumbles incoherently about Reaganomics.",
	],
	&"science": [
		"{who} wonders what mental disease has possessed {by}.", "{who} explains why nuclear energy is safe.",
		"{who} makes Albert Einstein faces at {by}.", "{who} pities {by}'s blind ignorance of science.",
	],
	&"persuaded": [
		"{who}'s Conservative beliefs are shaken.", "{who} quietly considers these ideas.",
		"{who} is beginning to see Liberal reason.", "{who} has a revelation of understanding.",
		"{who} grudgingly admits sympathy for LCS ideals.",
	],
	&"held_firm": ["{who} holds firm."],
	&"turned_tables": ["{who} turns the tables on {by}!\n{by} has been tainted with wisdom!"],
	&"alienated": [
		"{who} babbles mindlessly.", "{who} just whimpers.", "{who} cries helplessly.",
		"{who} is losing faith in the world.", "{who} only grows more distant.",
		"{who} is too terrified to even speak to {by}.", "{who} just hates the LCS even more.",
	],
	&"consoled": [
		"{by} consoles the Conservative automaton.", "{by} shares some chocolates.",
		"{by} provides a shoulder to cry on.", "{by} understands {who}'s pain.",
		"{by}'s heart opens to the poor Conservative.",
		"{by} helps the poor thing to come to terms with captivity.",
		"{by}'s patience and kindness leaves the Conservative confused.",
	],
	&"clinging": [
		"{who} emotionally clings to {by}'s sympathy.", "{who} begs {by} for help.",
		"{who} promises to be good.", "{who} reveals childhood pains.",
		"{who} thanks {by} for being merciful.", "{who} cries in {by}'s arms.", "{who} really likes {by}.",
	],
	&"grounded": [
		"{who} takes the drug-induced hallucinations with stoicism.",
		"{who} mutters its initials over and over again.", "{who} babbles continuous numerical sequences.",
		"{who} manages to remain grounded through the hallucinations.",
	],
	&"angel": [
		"{who} hallucinates and sees {by} as an angel.", "{who} realizes with joy that {by} is Ronald Reagan!",
		"{who} stammers and {hug}{by}.", "{who} begs {by} to let the colors stay forever.",
	],
	&"demon": [
		"{who} screams in horror as {by} turns into an alien.", "{who}{curl} begs for the nightmare to end.",
		"{who} watches {by} shift from one demonic form to another.", "{hitler}",
	],
	&"colours": [
		"{who} comments on the swirling light {by} is radiating.", "{who} can't stop looking at the moving colors.",
		"{who} laughs hysterically at {by}'s altered appearance.", "{who} barks and woofs like a dog.",
	],
	&"restraint": [
		"The Automaton is locked in a back room converted into a makeshift cell.",
		"The Automaton is tied hands and feet to a metal chair in the middle of a back room.",
	],
	&"despair": ["{who} mutters about death.", "{who} broods darkly.",
		"{who} has lost hope of rescue.", "{who} is making peace with God.",
		"{who} is bleeding from self-inflicted wounds.", "{who} has committed suicide."],
	&"remorse": ["{by} feels sick to the stomach afterward and throws up in a trash can.",
		"{by} feels sick to the stomach afterward and gets drunk, eventually falling asleep.",
		"{by} feels sick to the stomach afterward and curls up in a ball, crying softly.",
		"{by} feels sick to the stomach afterward and shoots up and collapses in a heap on the floor."],
	&"colder": ["{by} grows colder."],
	&"takes_it": ["{who} takes it well."],
	&"message": ["{who} seems to be getting the message."],
	&"hurt": ["{who} is badly hurt.", "{who}'s weakened body crumbles under the brutal assault."],
	&"prayer": ["{who} prays...", "{who} cries out for God.",
		"{who} takes solace in the personal appearance of God.", "{who} appears to be having a religious experience."],
	&"broken": ["{who} screams helplessly for {mercy}.", "{who}{limp}",
		"{who}{cry}", "{who}{wonder}"],
}

static func describe(state: GameState, data: Dictionary) -> String:
	var who: Creature = state.creatures.get(int(data.get("creature", 0)))
	var lead: Creature = state.creatures.get(int(data.get("by", 0)))
	var names := {"who": who.name if who != null else "Someone",
		"by": lead.name if lead != null else "Someone"}
	var result: StringName = data.get("result", &"")
	if result == &"revealed":
		var place: Location = state.locations.get(int(data.get("location", 0)))
		return "{who} reveals details about the {place}.\n{by} was able to create a map of the site with this information.".format(
			{"who": names.who, "by": names.by, "place": place.name if place != null else "site"})
	if result == &"overdose_death":
		return ("{by} uses a defibrillator repeatedly but {who} flatlines.\nIt is a lethal overdose in {who}'s weakened state." if data.get("skilled", false)
			else "{who} dies due to {by}'s incompetence at first aid.").format(names)
	if result == &"resuscitated":
		if int(data.get("line", 0)) == 0:
			return "{by} deftly rescues it from cardiac arrest with a defibrillator.\n{by} skillfully saves {who} from any health damage.".format(names)
		return ("{by} clumsily rescues it from cardiac arrest with a defibrillator.\n" +
			("{who} had a near-death experience and met God in heaven." if who != null and who.skills.get_value(&"religion") > 0
			else "{who} had a near-death experience and met John Lennon.")).format(names)
	var choices: Array = LINES.get(result, [])
	if choices.is_empty():
		return ""
	var issue := int(data.get("issue", -1))
	names["issue"] = ViewText.of(Ids.VIEWS[issue]) if issue >= 0 and issue < Ids.VIEWS.size() else ""
	var tied := bool(data.get("restrained", false))
	names["hug"] = "talks about hugging " if tied else "hugs "
	names["curl"] = "" if tied else " curls up and"
	names["hitler"] = ("{who} begs Hitler to stay and kill {by}." if float(data.get("rapport", 0)) < -3
		else "{who} screams for {by} to stop looking like Hitler.").format(names)
	names["mercy"] = "John Lennon's mercy" if data.get("drugs", false) else (
		"God's mercy" if who != null and who.skills.get_value(&"religion") > 0 else "mommy")
	names["limp"] = " goes limp in the restraints." if tied else " curls up in the corner and doesn't move."
	names["cry"] = " barks helplessly." if data.get("odd", false) else " cries helplessly."
	names["wonder"] = " wonders about apples." if data.get("odd", false) else " wonders about death."
	return String(choices[int(data.get("line", 0)) % choices.size()]).format(names)

static func report(events: Array, state: GameState) -> String:
	var lines := PackedStringArray()
	for event: Event in events:
		var said := SiegeText.describe(event, state)
		if not said.is_empty(): lines.append(said)
	return "\n\n".join(lines)

static func profile(who: Creature, lead: Creature) -> Array[String]:
	var lines: Array[String] = ["Prisoner: " + who.name,
		"Health: " + ConditionText.of(who), "Heart: %d  Wisdom: %d  Health: %d" % [
		AttributeRules.effective(who, &"heart", true), AttributeRules.effective(who, &"wisdom", true),
		AttributeRules.effective(who, &"health", true)]]
	if lead == null: return lines
	lines.append("Lead Interrogator: " + lead.name)
	lines.append("Psychology Skill: %d  Heart: %d  Wisdom: %d" % [lead.skills.get_value(&"psychology"),
		AttributeRules.effective(lead, &"heart", true), AttributeRules.effective(lead, &"wisdom", true)])
	if lead.armor != null: lines.append("Outfit: " + DossierText.item_title(lead.armor, null))
	var warmth := who.interrogation.toward(lead.id) if who.interrogation != null else 0.0
	var rapport := "The Conservative would like to murder %s."
	if warmth > 3: rapport = "The Conservative clings helplessly to %s as its only friend."
	elif warmth > 1: rapport = "The Conservative likes %s."
	elif warmth > -1: rapport = "The Conservative is uncooperative toward %s."
	elif warmth > -4: rapport = "The Conservative hates %s."
	lines.append(rapport % lead.name)
	return lines


static func execution(state: GameState, data: Dictionary) -> String:
	var who: Creature = state.creatures.get(int(data.get("creature", 0)))
	var lead: Creature = state.creatures.get(int(data.get("by", 0)))
	var name := who.name if who != null else "Someone"
	if lead == null:
		return "There is no one able to get up the nerve to execute %s in cold blood." % name
	var methods := ["strangling it to death.", "beating it to death.",
		"burning photos of Reagan in front of it.", "telling it that taxes have been increased.",
		"telling it its parents wanted to abort it."]
	return "%s executes %s by %s" % [lead.name, name, methods[int(data.get("method", 0)) % methods.size()]]
