class_name ReportText
extends RefCounted

const SURVEY := {
	&"gay": "were in favor of equal rights for homosexuals",
	&"deathpenalty": "opposed the death penalty",
	&"taxes": "were against cutting taxes",
	&"nuclearpower": "were terrified of nuclear power",
	&"animalresearch": "deplored animal research",
	&"policebehavior": "were critical of the police",
	&"torture": "wanted stronger measures to prevent torture",
	&"intelligence": "thought the intelligence community invades privacy",
	&"freespeech": "believed in unfettered free speech",
	&"genetics": "abhorred genetically altered food products",
	&"justices": "were for the appointment of Liberal justices",
	&"sweatshops": "would boycott companies that used sweatshops",
	&"pollution": "thought industry should lower pollution",
	&"corporateculture": "were disgusted by corporate malfeasance",
	&"ceosalary": "believed that CEO salaries are too great",
	&"women": "favored doing more for gender equality",
	&"civilrights": "felt more work was needed for racial equality",
	&"guncontrol": "are concerned about gun violence",
	&"military": "opposed increasing military spending",
	&"liberalcrimesquad": "respected the power of the Liberal Crime Squad",
	&"liberalcrimesquadpos": "of these held the Liberal Crime Squad in high regard",
	&"conservativecrimesquad": "held the Conservative Crime Squad in contempt",
	&"prisons": "wanted to end prisoner abuse and torture",
	&"amradio": "do not like AM radio",
	&"cablenews": "have a negative opinion of cable news programs",
}

static func polling(data: Dictionary, state: GameState) -> String:
	var lines: Array[String] = ["Survey of Public Opinion, According to Recent Polls"]
	lines.append("%d%% had a favorable opinion of President %s." % [
			int(data.get("approval", 0)), state.government.executive_names[0]])
	var concern := StringName(data.get("concern", &""))
	if concern != &"":
		lines.append("The people are most concerned about " + ViewText.heading(concern) + ".")
	var figures: PackedInt32Array = data.get("survey", PackedInt32Array())
	for i in mini(figures.size(), Ids.VIEWS.size()):
		var amount := "??" if figures[i] < 0 else str(figures[i])
		var wording := String(SURVEY.get(Ids.VIEWS[i], ViewText.heading(Ids.VIEWS[i])))
		if Ids.VIEWS[i] == &"drugs":
			wording = "supported keeping marijuana legal" if state.law.get_value(&"drugs") >= 1 else "believed in legalizing marijuana"
		elif Ids.VIEWS[i] == &"immigration":
			wording = "condemned unnecessary immigration regulations" if state.law.get_value(&"immigration") >= 1 else "wanted amnesty for illegal immigrants"
		lines.append(amount + "% " + wording)
	return "\n".join(lines)

static func finances(data: Dictionary) -> String:
	var lines: Array[String] = ["Financial Report"]
	lines.append("In hand: $%d." % int(data.get("funds", 0)))
	for side in ["income", "expense"]:
		var total := 0
		lines.append("Coming in" if side == "income" else "Going out")
		var book: Dictionary = data.get(side, {})
		for key in book:
			total += int(book[key])
			lines.append("%s: $%d" % [String(key).replace("_", " "), int(book[key])])
		lines.append("Total: $%d" % total)
	return "\n".join(lines)
