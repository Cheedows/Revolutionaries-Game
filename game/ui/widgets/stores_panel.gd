class_name StoresPanel
extends Card
## What the safehouse is keeping, and what the squad is carrying.
##
## Ports the reading of `moveloot()` from src/common/equipment.cpp: two piles
## side by side, and things taken out of one and put into the other. The
## original picks with letters and asks how many; this picks with buttons and
## moves one at a time, or the whole stack.

## Emitted after anything is moved.
signal changed

var _session: Session
var _columns: BoxContainer
var _left: VBoxContainer
var _right: VBoxContainer


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
	_head.set_title("The stores")
	_fill(_left, "Equip the Squad",
			_session.state.active_squad().haul \
					if _session.state.active_squad() != null else [], true)
	_fill(_right, "Stash things at the Safehouse",
			here.ground_loot if here != null else [], false)


## One side of the panel: a heading and a row per thing.
func _fill(column: VBoxContainer, heading: String, pile: Array,
		stashing: bool) -> void:
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()

	var label := Atoms.heading(heading)
	column.add_child(label)

	if pile.is_empty():
		var empty := Atoms.nothing("Nothing.")
		column.add_child(empty)
		return

	for index in pile.size():
		column.add_child(_row(pile[index], index, stashing))


func _row(item: Item, index: int, stashing: bool) -> Control:
	var row := ListRow.new(DossierText.item_title(item, _session.catalog))

	var one := Atoms.button("Stash" if stashing else "Take", false)
	one.pressed.connect(func() -> void: _move(index, 1, stashing))
	row.act(one)

	if item.count > 1:
		var all := Atoms.button("All", false)
		all.pressed.connect(func() -> void: _move(index, item.count, stashing))
		row.act(all)
	return row


func _move(index: int, many: int, stashing: bool) -> void:
	KitCommands.move_kit(_session, {index: many}, stashing)
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
	card()
	# card() guards itself; the columns need their own guard, and losing it
	# meant every call to compact() built a second pair of them beside the
	# first — which is a panel twice as wide as a phone.
	if _left != null:
		return
	_columns = Atoms.split(Metrics.WIDE)
	hold(_columns)
	var columns := _columns

	_left = Atoms.column(Metrics.SNUG)
	columns.add_child(_left)

	_right = Atoms.column(Metrics.SNUG)
	columns.add_child(_right)


## What the squad is carrying and what is in the safehouse sit side by side on
## a desk. Two of those columns are wider than a phone put together, so on a
## phone one goes under the other.
func compact(on: bool) -> void:
	_build()
	Atoms.stack(_columns, on)
