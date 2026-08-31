class_name SaveGame
extends RefCounted
## Reading and writing saves on disk.
##
## The document itself is [SaveSerializer]'s; this is the file around it, and
## the only place in the game that touches the filesystem. It lives in app/
## because core/ may not: a system is given a state and a generator and has no
## idea a disk exists.

## Where saves go. Godot maps user:// to the platform's own application data
## directory, so this works the same on all three.
const DIRECTORY := "user://saves"

## The slot the game writes itself into at the start of every day, which is
## what the original does with save.dat.
const AUTOSAVE := "autosave"

const EXTENSION := ".json"


## Writes [param session] into [param slot]. Returns whether it worked.
static func write(session: Session, slot: String = AUTOSAVE) -> bool:
	if not _make_room():
		return false
	var file := FileAccess.open(_path(slot), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(
			SaveSerializer.to_dict(session.state, session.rng)))
	file.close()
	return true


## Reads [param slot] into [param session]. Returns whether it worked; the
## session is left alone when it does not, so a corrupt file cannot lose the
## game that is running.
static func read(session: Session, slot: String = AUTOSAVE) -> bool:
	var document := document_in(slot)
	if document.is_empty():
		return false
	var loaded := SaveSerializer.from_dict(document, session.rng)
	if loaded == null:
		return false
	session.state = loaded
	return true


## The raw document in [param slot], or an empty dictionary.
static func document_in(slot: String) -> Dictionary:
	var file := FileAccess.open(_path(slot), FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


## Whether there is anything in [param slot].
static func exists(slot: String = AUTOSAVE) -> bool:
	return FileAccess.file_exists(_path(slot))


## The slots that have something in them, in alphabetical order.
static func slots() -> PackedStringArray:
	var found := PackedStringArray()
	var directory := DirAccess.open(DIRECTORY)
	if directory == null:
		return found
	for name: String in directory.get_files():
		if name.ends_with(EXTENSION):
			found.append(name.substr(0, name.length() - EXTENSION.length()))
	found.sort()
	return found


## Throws a save away, which is what the original's title screen offers when
## it is asked to delete one.
static func erase(slot: String) -> bool:
	if not exists(slot):
		return false
	return DirAccess.remove_absolute(_path(slot)) == OK


## What a slot holds, without loading it: the date, the money and the name of
## the organisation, for a list of saves to show.
static func describe(slot: String) -> Dictionary:
	var document := document_in(slot)
	if document.is_empty() or document.get("magic") != SaveSerializer.MAGIC:
		return {}
	var calendar: Dictionary = document.get("calendar", {})
	var ledger: Dictionary = document.get("ledger", {})
	var world: Dictionary = document.get("world", {})
	return {
		"slot": slot,
		"version": int(document.get("version", 0)),
		"day": int(calendar.get("day", 0)),
		"month": int(calendar.get("month", 0)),
		"year": int(calendar.get("year", 0)),
		"funds": int(ledger.get("funds", 0)),
		"city": String(world.get("city_name", "")),
		"slogan": String(world.get("slogan", "")),
	}


static func _path(slot: String) -> String:
	return "%s/%s%s" % [DIRECTORY, slot, EXTENSION]


static func _make_room() -> bool:
	if DirAccess.dir_exists_absolute(DIRECTORY):
		return true
	return DirAccess.make_dir_recursive_absolute(DIRECTORY) == OK
