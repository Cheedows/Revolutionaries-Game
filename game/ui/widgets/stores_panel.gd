class_name StoresPanel
extends PanelContainer
## What the safehouse is keeping, and what the squad is carrying.
##
## Ports the reading of `moveloot()` from src/common/equipment.cpp: two piles
## side by side, and things taken out of one and put into the other. The
## original picks with letters and asks how many; this picks with buttons and
## moves one at a time, or the whole stack.

## Emitted after anything is moved.
signal changed

## Emitted when the panel should close.
signal closed

var _session: Session
var _left: VBoxContainer
var _right: VBoxContainer
var _title: Label


func _ready() -> void:
	_build()


## Shows the stores of the safehouse the squad is standing in.
func show_stores(session: Session) -> void:
	_build()
	_session = session
	visible = true
	_refresh()


func _refresh() -> void:
	var here := _house()
	_title.text = "The stores"
	_fill(_left, "The squad is carrying",
			_session.state.active_squad().haul \
					if _session.state.active_squad() != null else [], true)
	_fill(_right, "The safehouse is keeping",
			here.ground_loot if here != null else [], false)


## One side of the panel: a heading and a row per thing.
func _fill(column: VBoxContainer, heading: String, pile: Array,
		stashing: bool) -> void:
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()

	var label := Label.new()
	label.text = heading
	label.add_theme_color_override("font_color", Palette.ACCENT)
	column.add_child(label)

	if pile.is_empty():
		var empty := Label.new()
		empty.text = "Nothing."
		empty.add_theme_color_override("font_color", Palette.TEXT_FAINT)
		column.add_child(empty)
		return

	for index in pile.size():
		column.add_child(_row(pile[index], index, stashing))


func _row(item: Item, index: int, stashing: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = DossierText.item_title(item, _session.catalog)
	label.add_theme_color_override("font_color", Palette.TEXT_DIM)
	row.add_child(label)

	var one := Button.new()
	one.text = "Stash" if stashing else "Take"
	one.pressed.connect(func() -> void: _move(index, 1, stashing))
	row.add_child(one)

	if item.count > 1:
		var all := Button.new()
		all.text = "All"
		all.pressed.connect(func() -> void: _move(index, item.count, stashing))
		row.add_child(all)
	return row


func _move(index: int, many: int, stashing: bool) -> void:
	Commands.move_kit(_session, {index: many}, stashing)
	changed.emit()
	_refresh()


## The safehouse the squad is standing in, or null.
func _house() -> Location:
	var squad := _session.state.active_squad()
	if squad == null:
		return null
	var members := _session.state.squad_members(squad)
	if members.is_empty():
		return null
	return _session.state.locations.get(members[0].location)


func _build() -> void:
	if _left != null:
		return
	add_theme_stylebox_override("panel", UiTheme.panel())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)

	var heading := HBoxContainer.new()
	column.add_child(heading)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_color_override("font_color", Palette.ACCENT)
	heading.add_child(_title)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func() -> void: closed.emit())
	heading.add_child(close)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	var columns := HBoxContainer.new()
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 16)
	scroll.add_child(columns)

	_left = VBoxContainer.new()
	_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(_left)

	_right = VBoxContainer.new()
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(_right)
