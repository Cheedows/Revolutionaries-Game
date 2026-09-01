class_name SpecialEditionText
extends RefCounted
## What the Liberal Guardian's special edition said.
##
## Says what [SpecialEditionRun] rolled, from printnews() in
## src/monthly/lcsmonthly.cpp.

## What each document is called when the squad is offered it.
const NAMES := {
	&"LOOT_AMRADIOFILES": "AM Radio Memos",
	&"LOOT_CABLENEWSFILES": "Cable News Memos",
	&"LOOT_CCS_BACKERLIST": "CCS Backer List",
	&"LOOT_CEOLOVELETTERS": "CEO Love Letters",
	&"LOOT_CEOPHOTOS": "CEO Photos",
	&"LOOT_CEOTAXPAPERS": "CEO Tax Papers",
	&"LOOT_CORPFILES": "Secret Corporate Files",
	&"LOOT_INTHQDISK": "Intel. HQ Data Disk",
	&"LOOT_JUDGEFILES": "Judge Corrupt. Evidence",
	&"LOOT_POLICERECORDS": "Police Records",
	&"LOOT_PRISONFILES": "Prison Records",
	&"LOOT_RESEARCHFILES": "Research Papers",
	&"LOOT_SECRETDOCUMENTS": "Secret Documents",
}

## How each story opens.
const OPENINGS := {
	&"LOOT_CEOPHOTOS": "The Liberal Guardian runs a story featuring photos of "
			+ "a major CEO ",
	&"LOOT_CEOLOVELETTERS": "The Liberal Guardian runs a story featuring love "
			+ "letters from a major CEO ",
	&"LOOT_CEOTAXPAPERS": "The Liberal Guardian runs a story featuring a major "
			+ "CEO's tax papers ",
	&"LOOT_CORPFILES": "The Liberal Guardian runs a story featuring Corporate "
			+ "files ",
	&"LOOT_INTHQDISK": "The Liberal Guardian runs a story featuring CIA and "
			+ "other intelligence files ",
	&"LOOT_SECRETDOCUMENTS": "The Liberal Guardian runs a story featuring CIA "
			+ "and other intelligence files ",
	&"LOOT_POLICERECORDS": "The Liberal Guardian runs a story featuring police "
			+ "records ",
	&"LOOT_JUDGEFILES": "The Liberal Guardian runs a story with evidence of a "
			+ "Conservative judge ",
	&"LOOT_RESEARCHFILES": "The Liberal Guardian runs a story featuring "
			+ "research papers ",
	&"LOOT_PRISONFILES": "The Liberal Guardian runs a story featuring prison "
			+ "documents ",
	&"LOOT_CABLENEWSFILES": "The Liberal Guardian runs a story featuring cable "
			+ "news memos ",
	&"LOOT_AMRADIOFILES": "The Liberal Guardian runs a story featuring AM "
			+ "radio plans ",
}

## And the angle it took, by document and by the roll.
const ANGLES := {
	&"LOOT_CEOPHOTOS": [
		"engaging in lewd behavior with animals.",
		"digging up graves and sleeping with the dead.",
		"participating in a murder.",
		"engaging in heavy bondage.  A cucumber was involved in some way.",
		"tongue-kissing an infamous dictator.",
		"making out with an FDA official overseeing the CEO's products.",
		"castrating himself.",
		"waving a Nazi flag at a supremacist rally.",
		"torturing an employee with a hot iron.",
		"playing with feces and urine.",
	],
	&"LOOT_CEOLOVELETTERS": [
		"addressed to his pet dog.  Yikes.",
		"to the judge that acquit him in a corruption trial.",
		"to an illicit gay lover.",
		"to himself.  They're very steamy.",
		"implying that he has enslaved his houseservants.",
		"to the FDA official overseeing the CEO's products.",
		"that seem to touch on every fetish known to man.",
		"promising someone company profits in exchange for sexual favors.",
	],
	&"LOOT_CEOTAXPAPERS": [
		"showing that he has engaged in consistent tax evasion.",
	],
	&"LOOT_CORPFILES": [
		"describing a genetic monster created in a lab.",
		"with a list of gay employees entitled \"Homo-workers\".",
		"containing a memo: \"Terminate the pregnancy, I terminate you.\"",
		"cheerfully describing foreign corporate sweatshops.",
		"describing an intricate tax scheme.",
	],
	&"LOOT_INTHQDISK": [
		"documenting the overthrow of a government.",
		"documenting the planned assassination of a Liberal federal judge.",
		"containing private information on innocent citizens.",
		"documenting \"harmful speech\" made by innocent citizens.",
		"used to keep tabs on gay citizens.",
		"documenting the infiltration of a pro-choice group.",
	],
	&"LOOT_POLICERECORDS": [
		"documenting human rights abuses by the force.",
		"documenting a police torture case.",
		"documenting a systematic invasion of privacy by the force.",
		"documenting a forced confession.",
		"documenting widespread corruption in the force.",
		"documenting gladiatorial matches held between prisoners by guards.",
	],
	&"LOOT_JUDGEFILES": [
		"taking bribes to acquit murderers.",
		"promising Conservative rulings in exchange for appointments.",
	],
	&"LOOT_RESEARCHFILES": [
		"documenting horrific animal rights abuses.",
		"studying the effects of torture on cats.",
		"covering up the accidental creation of a genetic monster.",
		"showing human test subjects dying under genetic research.",
	],
	&"LOOT_PRISONFILES": [
		"documenting human rights abuses by prison guards.",
		"documenting a prison torture case.",
		"documenting widespread corruption among prison employees.",
		"documenting gladiatorial matches held between prisoners by guards.",
	],
	&"LOOT_CABLENEWSFILES": [
		"calling their news 'the vanguard of Conservative thought'.",
		"mandating negative coverage of Liberal politicians.",
		"planning to drum up a false scandal about a Liberal figure.",
		"instructing a female anchor to 'get sexier or get a new job'.",
	],
	&"LOOT_AMRADIOFILES": [
		"calling listeners 'sheep to be told what to think'.",
		"saying 'it's okay to lie, they don't need the truth'.",
		"planning to drum up a false scandal about a Liberal figure.",
	],
}

## What is said after the angle, by who it will have annoyed.
const RILED := {
	&"corps": "This is bound to get the Corporations a little riled up.",
	&"cia": "This is bound to get the Government a little riled up.",
	&"cablenews": "This is bound to get the Conservative masses a little riled up.",
	&"amradio": "This is bound to get the Conservative masses a little riled up.",
}

## The one story that is not a story about a document but the end of the other
## side.
const BACKERS: Array[String] = [
	"The Liberal Guardian runs more than one thousand pages of documents about "
			+ "the CCS organization, also revealing in extreme detail the names and "
			+ "responsibilities of Conservative Crime Squad sympathizers and supporters "
			+ "in the state and federal governments. Sections precisely document the "
			+ "extensive planning to create an extra-judicial death squad that would be "
			+ "above prosecution, and could hunt down law-abiding Liberals and act "
			+ "as a foil when no other enemies were present to direct public energy "
			+ "against.",
	"The scandal reaches into the heart of the Conservative leadership in the "
			+ "country, and the full ramifications of this revelation may not be felt "
			+ "for months. One thing is clear, however, from the immediate public reaction "
			+ "toward the revelations, and the speed with which even AM Radio and Cable "
			+ "News denounce the CCS.",
	"This is the beginning of the end for the Conservative Crime Squad.",
]


## What one of the documents is called.
static func name_of(document: StringName) -> String:
	return String(NAMES.get(document,
			String(document).trim_prefix("LOOT_").capitalize()))


## The lines the issue ran, from a [constant Event.MAJOR_EVENT] of kind
## "special_edition".
static func lines(data: Dictionary) -> Array[String]:
	var document: StringName = data.get("document", &"")
	if document == &"LOOT_CCS_BACKERLIST":
		return BACKERS.duplicate()

	var lines: Array[String] = []
	var opening := String(OPENINGS.get(document, ""))
	var angle := int(data.get("angle", -1))
	var options: Array = ANGLES.get(document, [])
	if angle >= 0 and angle < options.size():
		lines.append(opening + String(options[angle]))
	elif opening != "":
		lines.append(opening.strip_edges() + ".")
	lines.append("The major networks and publications take it up and run it "
			+ "for weeks.")
	var offended: StringName = SpecialEdition.OFFENDS.get(document, &"")
	if offended != &"":
		lines.append(String(RILED[offended]))
	return lines
