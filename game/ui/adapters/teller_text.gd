class_name TellerText
extends RefCounted
## Robbing a bank across the counter.
##
## The original writes the note out — there are ten of them, all in capitals —
## and then has the teller read it and do one of six things, five of which end
## in the guards coming and five of which end in the money. Both are rolled,
## and [BankTeller] was making both rolls and discarding them.
##
## Word for word from talkToBankTeller() in src/sitemode/talk.cpp.

const SLIPS_A_NOTE := " slips the teller a note: "

const NOTES: Array[String] = [
	"KINDLY PUT MONEY IN BAG. OR ELSE.",
	"I AM LIBERATING YOUR MONEY SUPPLY.",
	"THIS IS A ROBBERY. GIVE ME THE MONEY.",
	"I HAVE A GUN. CASH PLEASE.",
	"THE LIBERAL CRIME SQUAD REQUESTS CASH.",
	"I AM MAKING A WITHDRAWAL. ALL YOUR MONEY.",
	"YOU ARE BEING ROBBED. GIVE ME YOUR MONEY.",
	"PLEASE PLACE LOTS OF DOLLARS IN THIS BAG.",
	"SAY NOTHING. YOU ARE BEING ROBBED.",
	"ROBBERY. GIVE ME CASH. NO FUNNY MONEY.",
]

const READS_THE_NOTE := "The bank teller reads the note, "

## What a teller at a bank that watches its counters does.
const RAISES_THE_ALARM: Array[String] = [
	"gestures, ", "signals, ", "shouts, ", "screams, ",
	"gives a warning, ",
]
const GUARDS_MOVE_IN := "and dives for cover as the guards move in on the"\
		+ " squad!"

## And what one at a bank that does not simply does.
const PAYS_UP: Array[String] = [
	"nods calmly, ", "looks startled, ", "bites her lip, ", "grimaces, ",
	"frowns, ",
]
const CASH_IN_THE_BAG := "and slips several bricks of cash into the squad's"\
		+ " bag."


## The quiet way: the note, and what came of it.
static func robbed(state: GameState, data: Dictionary) -> String:
	var note := NOTES[int(data.get("note", 0)) % NOTES.size()]
	var said := "%s%s\"%s\"" % [_who(state, data), SLIPS_A_NOTE, note]
	var quiet := bool(data.get("quiet", true))
	var reactions: Array[String] = PAYS_UP if quiet else RAISES_THE_ALARM
	var reaction := reactions[int(data.get("reaction", 0)) % reactions.size()]
	return "%s %s%s%s" % [said, READS_THE_NOTE, reaction,
			CASH_IN_THE_BAG if quiet else GUARDS_MOVE_IN]


static func _who(state: GameState, data: Dictionary) -> String:
	var creature: Creature = state.creatures.get(data.get("creature", 0))
	return creature.name if creature != null and creature.name != "" \
			else "Someone"
