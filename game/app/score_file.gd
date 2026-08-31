class_name ScoreFile
extends RefCounted
## The high-score table on disk.
##
## The original keeps score.dat beside the save; this keeps the same table in
## the same place saves go, in the same document format. As with [SaveGame],
## the filesystem stops here: [HighScores] decides what goes in the table and
## knows nothing about files.

const PATH := "user://saves/scores.json"


## Reads the table. Returns {"table": [...], "lifetime": {...}}, empty when
## there is nothing there yet.
static func read() -> Dictionary:
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return {"table": [], "lifetime": {}}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"table": [], "lifetime": {}}
	var document: Dictionary = parsed
	return {
		"table": document.get("table", []),
		"lifetime": document.get("lifetime", {}),
	}


## Records the game in [param session] as having ended in [param ending].
## Returns the place it took, or -1.
static func record(session: Session, ending: StringName) -> int:
	var kept := read()
	var entry := HighScores.entry_for(session.state, ending)
	var table: Array = kept["table"]
	var place := HighScores.place(table, entry)
	var lifetime := HighScores.add_lifetime(kept["lifetime"], entry)

	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return -1
	file.store_string(JSON.stringify({"table": table, "lifetime": lifetime}))
	file.close()
	return place


## Ends the game: the score goes in the book and the save is thrown away, which
## is what the original does before it shows you the table.
static func finish(session: Session, ending: StringName) -> int:
	var place := record(session, ending)
	SaveGame.erase(SaveGame.AUTOSAVE)
	return place
