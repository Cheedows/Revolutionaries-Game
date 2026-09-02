class_name ActionBar
extends PanelContainer
## The things you can do on this screen, kept where you can always reach them.
##
## The new-game screen put its Continue button at the bottom of the list it
## belonged to, inside the same scroller, and on a phone the list is taller
## than the screen — so the one control that leaves the screen was drawn off
## the bottom of it. The screen looked broken because the only way forward was
## somewhere the player had no reason to look.
##
## A screen's actions are not list items and do not scroll with the list. They
## sit here, against the bottom edge, above whatever is scrolling behind them,
## for as long as the screen is up.
##
## On a phone the buttons stack rather than share a line: three actions across
## a four-hundred-pixel viewport are three targets too narrow to hit, and a
## label that has wrapped to two lines in a button forty-eight pixels tall is
## clipped rather than wrapped.

## Beyond this many actions they stack even on a wide screen — past three, a
## row of buttons is a menu and should be read down.
const STACK_AFTER := 3

var _box: BoxContainer
var _stacked := false


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_stylebox_override(&"panel", UiTheme.panel(Palette.SURFACE))
	_box = Atoms.row(Metrics.SNUG)
	add_child(_box)


## Empties the bar.
func clear() -> void:
	for child in _box.get_children():
		_box.remove_child(child)
		child.queue_free()


## Puts [param button] in the bar.
func add(button: Button) -> void:
	_box.add_child(button)


## Whether the bar has anything in it.
func filled() -> bool:
	return _box.get_child_count() > 0


## The buttons in it, left to right or top to bottom.
func buttons() -> Array[Button]:
	var found: Array[Button] = []
	for child in _box.get_children():
		if child is Button:
			found.append(child)
	return found


## Lays the bar out for the room it has.
##
## Rebuilds the container when the direction changes rather than on every call:
## a screen asks this on each resize, and swapping a live [BoxContainer] under
## focus would drop whatever the keyboard was on.
func adapt(narrow: bool) -> void:
	var stack := narrow or _box.get_child_count() > STACK_AFTER
	if stack == _stacked and is_instance_valid(_box):
		return
	_stacked = stack
	var was := _box.get_children()
	for child in was:
		_box.remove_child(child)
	var fresh: BoxContainer = Atoms.column(Metrics.SNUG) if stack \
			else Atoms.row(Metrics.SNUG)
	remove_child(_box)
	_box.queue_free()
	_box = fresh
	add_child(_box)
	for child in was:
		_box.add_child(child)
