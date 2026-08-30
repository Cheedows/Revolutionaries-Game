class_name Catalog
extends RefCounted
## Indexes the generated content in data/ by idname.
##
## Content is data (ARCHITECTURE.md §5): a new weapon or creature type is a new
## .tres, and nothing in core/ names it. Systems ask the catalog by idname,
## which is what the original's XML also uses.

const DIRECTORIES := {
	&"creature": "res://data/creatures",
	&"weapon": "res://data/weapons",
	&"armor": "res://data/armor",
	&"mask": "res://data/masks",
	&"clip": "res://data/clips",
	&"loot": "res://data/loot",
	&"augment": "res://data/augments",
	&"vehicle": "res://data/vehicles",
	&"shop": "res://data/shops",
	&"sitemap": "res://data/sitemaps",
}

var _by_kind: Dictionary = {}


## Loads every kind. Call once; systems then look things up for free.
func load_all() -> void:
	for kind: StringName in DIRECTORIES:
		_by_kind[kind] = _load_kind(DIRECTORIES[kind])
	# Masks are armor in the original and share its idname space.
	var armor: Dictionary = _by_kind[&"armor"]
	for idname: StringName in _by_kind[&"mask"]:
		armor[idname] = _by_kind[&"mask"][idname]


## One entry, or null when nothing has that idname.
func get_entry(kind: StringName, idname: StringName) -> Resource:
	var entries: Dictionary = _by_kind.get(kind, {})
	return entries.get(idname)


## Every entry of a kind, in load order.
func all_of(kind: StringName) -> Array:
	var entries: Dictionary = _by_kind.get(kind, {})
	return entries.values()


## Every idname of a kind, sorted, so iteration is reproducible.
func idnames(kind: StringName) -> Array:
	var entries: Dictionary = _by_kind.get(kind, {})
	var names := entries.keys()
	names.sort()
	return names


func _load_kind(directory: String) -> Dictionary:
	var entries := {}
	var dir := DirAccess.open(directory)
	if dir == null:
		return entries
	var files := dir.get_files()
	files.sort()
	for file in files:
		if not file.ends_with(".tres"):
			continue
		var resource: Resource = load(directory.path_join(file))
		if resource == null:
			continue
		var idname: StringName = resource.get(&"idname")
		if idname == null or idname == &"":
			idname = StringName(file.get_basename())
		entries[idname] = resource
	return entries
