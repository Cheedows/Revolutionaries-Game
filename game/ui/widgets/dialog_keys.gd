class_name DialogKeys
extends RefCounted
## Where the keyboard sits in a question, and which option a key answers.
##
## Split out of intent_dialog.gd because it is one subject and the dialog had
## grown past what one file should hold. Everything here works on a list of
## buttons and the ids they stand for, so it can be reasoned about — and
## tested — without a dialog, a tree or a screen.

## Which option the keyboard should be on, given [param reachable] in the order
## a player walks them and [param ids] saying what each button answers.
##
## The one last answered, while it is still on offer: the switches screen
## rebuilds its whole list after every press, and starting at the top each time
## means six presses to reach the sixth switch, every time. Otherwise the first
## option that can be taken.
static func lands_on(reachable: Array[Button], ids: Dictionary,
		last: Variant) -> Variant:
	var first: Variant = null
	var found := false
	for button in reachable:
		if button.disabled:
			continue
		if same(ids.get(button), last):
			return last
		if not found:
			first = ids.get(button)
			found = true
	return first if found else null


## Whether two option ids are the same one.
##
## By type first: an id is whatever the intent that made it uses — a StringName
## for a switch, an int for a member of a list — and GDScript throws on == with
## one of each rather than answering false. A dialog outlives the question it
## is showing, so what it remembers of the last answer is regularly of the
## other kind.
static func same(id: Variant, other: Variant) -> bool:
	return id != null and typeof(id) == typeof(other) and id == other
