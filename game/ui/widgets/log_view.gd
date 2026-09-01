class_name LogView
extends PanelContainer
## The running account of what has happened.
##
## Replaces the original's message area, which was the same 24-line terminal the
## rest of the game drew into. Here it is its own thing that keeps a history and
## scrolls.

## Lines kept before the oldest are dropped.
##
## Far fewer on a phone: the log no longer scrolls on its own there — the whole
## page does — so every line kept is page to scroll past, and four hundred of
## them would bury everything else.
const HISTORY := 400
const NARROW_HISTORY := 30

var _lines: VBoxContainer
var _scroll: ScrollContainer
var _kept := HISTORY


func _ready() -> void:
	_build()


## Builds the scroller and the column of lines.
##
## Called from _ready(), but also from anything that writes, because a caller
## may reasonably fill the log before the widget reaches the tree — and a view
## that silently drops what it was given is worse than one that builds early.
func _build() -> void:
	if _lines != null:
		return
	add_theme_stylebox_override("panel", UiTheme.panel())
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_scroll)

	_lines = VBoxContainer.new()
	_lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lines.add_theme_constant_override("separation", 2)
	_scroll.add_child(_lines)


## Builds the widget without writing to it, so a screen can lay it out before
## anything has happened.
func refresh(_state: GameState) -> void:
	_build()


## Adds one line.
func append(text: String, colour: Color = Palette.TEXT) -> void:
	if text.is_empty():
		return
	_build()
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", colour)
	_lines.add_child(label)

	while _lines.get_child_count() > _kept:
		var oldest := _lines.get_child(0)
		_lines.remove_child(oldest)
		oldest.queue_free()

	# Follow the tail, so the newest line is the one being read. Only once the
	# widget is on screen: there is nothing to scroll before that.
	if not is_inside_tree():
		return
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


## Keeps a shorter history, for a page that scrolls as one.
func compact(on: bool) -> void:
	_build()
	_kept = NARROW_HISTORY if on else HISTORY
	while _lines.get_child_count() > _kept:
		var oldest := _lines.get_child(0)
		_lines.remove_child(oldest)
		oldest.queue_free()


## Adds a heading, for the start of a day or a report.
func append_heading(text: String) -> void:
	_build()
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Palette.ACCENT)
	_lines.add_child(label)


func clear() -> void:
	_build()
	for child in _lines.get_children():
		_lines.remove_child(child)
		child.queue_free()
