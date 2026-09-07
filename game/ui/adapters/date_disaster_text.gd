class_name DateDisasterText
extends RefCounted
## The missing comma in the original joins its first two humiliation strings.
const ENDINGS := [
	" is publicly humiliated. runs away.", " escapes through the bathroom window.",
	" spends the night getting drunk alone.", " gets chased out by an angry mob.",
	" gets stuck washing dishes all night.", " is rescued by a passing Elite Liberal.",
	" makes like a tree and leaves.",
]

static func describe(data: Dictionary, state: GameState) -> String:
	var person: Creature = state.creatures.get(int(data.get("creature", 0)))
	var who := person.name if person != null else "Someone"
	var many := int(data.get("dates", 2)) > 2
	var scene := ""
	match int(data.get("disaster", 0)):
		0:
			scene = "Unfortunately, they all know each other and had been discussing" if many else "Unfortunately, they know each other and had been discussing"
			scene += " " + who + ".  An ambush was set for the lying dog..."
		1:
			scene = "Unfortunately, they all turn up at the same time." if many else "Unfortunately, they turn up at the same time."
			scene += "\nRuh roh..."
		2:
			if many:
				scene = who + " realizes they have committed to eating %d meals at once." % int(data.get("dates", 2))
			else:
				var partners: Array = data.get("partners", [])
				var names: Array[String] = []
				for id in partners:
					var date: Creature = state.creatures.get(int(id))
					if date != null:
						names.append(date.name)
				scene = who + " mixes up the names of " + " and ".join(names) + "."
			scene += "\nThings go downhill fast."
	return scene + "\n" + who + ENDINGS[clampi(int(data.get("humiliation", 0)), 0, 6)]
