class_name NameColours
extends RefCounted
## One alignment policy for names in prose, choices, headers and character rows.

static func of(person: Creature) -> Color:
	return Palette.for_alignment(Alignment.value_of(person.alignment))


static func spans(text: String, state: GameState, ink: Color) -> Array[Dictionary]:
	var runs: Array[Dictionary] = []
	if state == null:
		return [{"text": text, "colour": ink}]
	var names := {}
	for person: Creature in state.creatures.values():
		if not person.name.is_empty():
			names[person.name] = of(person)
	var ordered := names.keys()
	ordered.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	var escaped: Array[String] = []
	for name: String in ordered:
		for special in ["\\", ".", "^", "$", "|", "(", ")", "[", "]", "{", "}", "*", "+", "?"]:
			name = name.replace(special, "\\" + special)
		escaped.append(name)
	if escaped.is_empty():
		return [{"text": text, "colour": ink}]
	var expression := RegEx.new()
	expression.compile("(?<![\\p{L}\\p{N}_])(?:" + "|".join(escaped) + ")(?![\\p{L}\\p{N}_])")
	var at := 0
	for found: RegExMatch in expression.search_all(text):
		if found.get_start() > at:
			runs.append({"text": text.substr(at, found.get_start() - at), "colour": ink})
		runs.append({"text": found.get_string(), "colour": names[found.get_string()]})
		at = found.get_end()
	if at < text.length():
		runs.append({"text": text.substr(at), "colour": ink})
	return runs


## Ordinary one-person labels retain their layout; disabled ancestors win.
static func paint_tree(node: Node, state: GameState) -> void:
	if state == null:
		return
	var names := {}
	for person: Creature in state.creatures.values():
		if not person.name.is_empty():
			names[person.name] = of(person)
	_paint(node, names, false)


static func _paint(node: Node, names: Dictionary, disabled: bool) -> void:
	if node is BaseButton:
		disabled = disabled or node.disabled
	if node is Label:
		var shown: String = node.text
		var numbered := shown.find(". ")
		if numbered > 0 and shown.left(numbered).is_valid_int():
			shown = shown.substr(numbered + 2)
		for name: String in names:
			if shown == name or shown.begins_with(name + " - ") or shown.begins_with(name + " ("):
				if disabled:
					node.set_meta(&"enabled_ink", names[name])
				node.add_theme_color_override(&"font_color", Palette.TEXT_FAINT if disabled else names[name])
				break
	for child in node.get_children():
		_paint(child, names, disabled)
