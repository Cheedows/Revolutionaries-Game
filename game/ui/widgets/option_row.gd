class_name OptionRow
extends RowButton
## One answer in a list of answers.
##
## The plain counterpart to [ToggleRow]: a thing you pick rather than a thing
## you switch on. Picking it answers the question and the list goes away, so it
## has no on state — only the states every button has.
##
## What it adds over a bare [Button] is the two shapes the original's own
## options come in. Most carry a short aside — "$60 a day", "3 days" — which
## belongs in a column on the right where the eye can run down it. A few carry
## a sentence instead — "Liberalism is forgotten. Is it too late to fight
## back?" — which cannot go in a column and goes on a line of its own under the
## label. Told apart by length, because that is the only thing that
## distinguishes them in the data.

## Longer than this and the aside is prose rather than a price.
const NOTE_IS_PROSE := 16

## How much room the right-hand column gets.
const NOTE_COLUMN := 72


## Builds an answer called [param said], with [param explained] beside or under
## it, numbered [param place] where there is a keyboard to type the number.
func _init(said: String = "", explained: String = "", place: int = 0,
		touch: bool = false, under: bool = false) -> void:
	if touch:
		stand_at_least(Metrics.TOUCH_TARGET)

	var row := Atoms.row(Metrics.SNUG)
	# [param under] overrules the length rule. A price belongs in the column
	# where the eye runs down it; what an answer is worth belongs under the
	# answer, and putting some of them in the column because they happened to
	# be short reads as an accident rather than as a rule.
	var aside := under or explained.length() > NOTE_IS_PROSE

	var stack := Atoms.column(0)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(stack)

	var label := Atoms.wrapped(
			Atoms.body(said if place <= 0 else "%d. %s" % [place, said]))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(label)

	if aside:
		var beneath := Atoms.wrapped(Atoms.dim(explained))
		beneath.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(beneath)
	elif not explained.is_empty():
		var cost := Atoms.dim(explained)
		cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cost.autowrap_mode = TextServer.AUTOWRAP_OFF
		cost.custom_minimum_size.x = NOTE_COLUMN
		cost.size_flags_horizontal = Control.SIZE_SHRINK_END
		cost.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(cost)

	hold(row)
