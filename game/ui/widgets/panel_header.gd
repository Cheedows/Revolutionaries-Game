class_name PanelHeader
extends HFlowContainer
## The top of a panel: what it is, and the way out of it.
##
## Ten panels had this, written out ten times: a heading label with
## [constant Control.SIZE_EXPAND_FILL] and a Close button beside it, in a row.
## A row is the thing that was wrong. "Choosing the Right Liberal Vehicle" and
## a Close button do not fit across four hundred pixels, and a row does not
## wrap — it draws the Close button off the side of the screen, which is where
## it was, unreachable, on every panel with a long name.
##
## A flow puts the button back on the line when there is room for it and under
## the heading when there is not, and the heading wraps rather than pushing.
## Ten copies of a bug is one bug; this is where it lives now.

## Emitted when the player is finished with the panel.
signal closed

var _title: Label


func _init(said: String = "") -> void:
	add_theme_constant_override(&"h_separation", Metrics.SNUG)
	add_theme_constant_override(&"v_separation", Metrics.TIGHT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_title = Atoms.wrapped(Atoms.heading(said))
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_title)

	var close := Icons.on(Atoms.button("Close", false), &"close")
	close.pressed.connect(func() -> void: closed.emit())
	add_child(close)


## What the panel is called.
func set_title(said: String) -> void:
	_title.text = said


func title() -> String:
	return _title.text
