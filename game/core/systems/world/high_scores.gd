class_name HighScores
extends RefCounted
## The five games worth remembering, and the tally across all of them.
##
## Ports savehighscore() from src/title/highscore.cpp. The table keeps five
## entries; a win always beats a loss, an earlier win beats a later one, and
## between two losses the bigger operation wins.

## How many games the table remembers.
const SLOTS := 5

## The end the game came to, in the original's order. Everything but the first
## is a way of losing.
const ENDINGS: Array[StringName] = [
	&"won", &"hicks", &"cia", &"police", &"corporate", &"reagan", &"dead",
	&"prison", &"executed", &"dating", &"hiding", &"disband_loss",
	&"dispersed", &"ccs", &"firemen", &"stalin",
]

## The lifetime tallies, which are added to rather than replaced.
const LIFETIME: Array[StringName] = [
	&"recruits", &"dead", &"kills", &"kidnappings", &"funds", &"spent",
	&"buys", &"burns",
]


## What this game would go into the table as.
static func entry_for(state: GameState, ending: StringName) -> Dictionary:
	return {
		"ending": String(ending),
		"slogan": state.slogan,
		"month": state.calendar.month,
		"year": state.calendar.year,
		"recruits": state.recruits,
		"dead": state.dead,
		"kills": state.kills,
		"kidnappings": state.kidnappings,
		"funds": state.ledger.total_income,
		"spent": state.ledger.total_expense,
		"buys": int(state.stats.get(&"flags_bought", 0)),
		"burns": int(state.stats.get(&"flags_burnt", 0)),
	}


## Adds [param entry] to [param table] where it belongs, pushing everything
## below it down and dropping whatever falls off the end.
##
## Returns the place it took, or -1 when it was not good enough for the table.
static func place(table: Array, entry: Dictionary) -> int:
	for slot in SLOTS:
		if slot < table.size() and not _beats(entry, table[slot]):
			continue
		table.insert(slot, entry)
		while table.size() > SLOTS:
			table.remove_at(table.size() - 1)
		return slot
	return -1


## Whether [param entry] belongs above [param sitting].
##
## **Original quirk, reproduced.** The first test — two wins in the same month
## — adds the expense to itself rather than to the income, so what it actually
## compares is twice what the winner spent against what the sitting entry both
## earned and spent.
static func _beats(entry: Dictionary, sitting: Dictionary) -> bool:
	var won := String(entry["ending"]) == "won"
	var theirs_won := String(sitting["ending"]) == "won"
	var against: int = int(sitting["spent"]) + int(sitting["funds"])

	if won and theirs_won:
		if int(entry["year"]) == int(sitting["year"]) \
				and int(entry["month"]) == int(sitting["month"]):
			return int(entry["spent"]) + int(entry["spent"]) > against
		return int(entry["year"]) < int(sitting["year"]) \
				or (int(entry["year"]) == int(sitting["year"])
						and int(entry["month"]) < int(sitting["month"]))
	if won:
		return true
	if theirs_won:
		return false
	return int(entry["spent"]) + int(entry["funds"]) > against


## Adds this game's figures to the lifetime tally.
static func add_lifetime(lifetime: Dictionary, entry: Dictionary) -> Dictionary:
	for field: StringName in LIFETIME:
		lifetime[String(field)] = int(lifetime.get(String(field), 0)) \
				+ int(entry[String(field)])
	return lifetime
