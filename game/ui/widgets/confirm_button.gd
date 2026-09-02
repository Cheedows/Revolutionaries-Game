class_name ConfirmButton
extends Button
## A button for something that cannot be undone. Press it twice.
##
## The original never takes a destructive key on the first press: it puts up a
## screen saying what is about to happen and waits for a different key.
##
##     Do you want to permanently release this squad member from the LCS?
##     If the member has low heart they may go to the police.
##       C - Confirm       Any other key to continue
##
## The port had that for two of its four destructive actions, written inside
## dossier.gd where nothing else could reach it, and drawn in a button
## identical to Close. "Delete a Save File" had none at all: one press and the
## file was gone.
##
## So it is a component. The first press arms it — the label becomes the
## original's own "C - Confirm" and the warning goes wherever the screen puts
## warnings. The second press does it. Pressing it again puts it back. It is
## drawn in the opposition's colour throughout, so the thing that ends a
## character never looks like the thing that closes a panel.

## Emitted on the second press, when the player has meant it twice.
signal confirmed

## Emitted when the button arms or disarms, with the warning to show — empty
## when it goes back. The screen decides where a warning goes; this decides
## when there is one.
signal warned(said: String)

## The original's own confirmation key.
const CONFIRM := "C - Confirm"

var _said := ""
var _warning := ""
var _armed := false


func _init(said: String = "", warning: String = "") -> void:
	_said = said
	_warning = warning
	text = said
	add_theme_color_override(&"font_color", Palette.CONSERVATIVE)
	add_theme_stylebox_override(&"normal",
			UiTheme.outlined(Palette.CONSERVATIVE))
	add_theme_stylebox_override(&"hover",
			UiTheme.filled(Palette.CONSERVATIVE.darkened(0.55)))
	pressed.connect(_step)


## Whether the next press will do it.
func armed() -> bool:
	return _armed


## Puts the button back to its first state without doing anything.
func disarm() -> void:
	if not _armed:
		return
	_armed = false
	text = _said
	warned.emit("")


## A press. The first arms it, the second does it.
##
## Not a toggle, which is how this was written the first time and is why the
## thing never fired: a toggle's second press sets it back to off, so the
## branch that did the work could not be reached. "Kill member" and "Remove
## member" armed themselves, said what would happen, and then cancelled — for
## as long as the button has existed.
func _step() -> void:
	if not _armed:
		_armed = true
		text = CONFIRM
		warned.emit(_warning)
		return
	_armed = false
	text = _said
	warned.emit("")
	confirmed.emit()
