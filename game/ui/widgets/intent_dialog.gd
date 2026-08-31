class_name IntentDialog
extends PanelContainer
## Renders any question the simulation asks, whatever it is about.
##
## Every system in core/ parks on a [PendingIntent] rather than blocking, and
## every one of those carries the same shape: a type, some context and a list
## of options. So one widget can render all of them, and a screen only needs a
## bespoke one where a list of buttons is genuinely not enough.
##
## Emits [signal chosen] with the option's id, or [signal declined] when the
## player backs out of a question that allows it.

signal chosen(id: Variant)
signal declined

## Beyond this many options the list scrolls rather than growing.
const SCROLL_AFTER := 8
const ROW_HEIGHT := 34

## The number keys pick the first nine options, as the original's letters pick
## its own. Past nine there is no key for it and the list is walked instead.
const SHORTCUTS := 9

var _title: Label
var _detail: Label
var _options: VBoxContainer
var _scroll: ScrollContainer
var _refuse: Button

## The option each button stands for, so the buttons stay the only thing that
## knows about layout and the ids stay data.
var _ids: Dictionary = {}


func _init() -> void:
	visible = false
	_build()


## The keyboard: a number picks that option, escape backs out of a question
## that allows it, and the arrow keys walk the list on their own.
func _gui_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE and _refuse.visible:
		declined.emit()
		accept_event()
		return
	var index := key.keycode - KEY_1
	if index < 0 or index >= SHORTCUTS:
		return
	var button := _button_at(index)
	if button == null or button.disabled:
		return
	chosen.emit(_ids.get(button))
	accept_event()


## The nth option's button, or null.
func _button_at(index: int) -> Button:
	var seen := 0
	for row in _options.get_children():
		for child in (row as Control).get_children():
			if not (child is Button):
				continue
			if seen == index:
				return child
			seen += 1
	return null


## Shows [param intent]. The dialog stays up until an option is taken.
func ask(intent: Intent, state: GameState) -> void:
	_title.text = IntentText.question(intent, state)
	_title.visible = not _title.text.is_empty()
	_detail.text = IntentText.detail(intent, state)
	_detail.visible = not _detail.text.is_empty()

	_ids.clear()
	for child in _options.get_children():
		child.queue_free()
		_options.remove_child(child)

	var entries := intent.options
	if entries.is_empty():
		# A report rather than a choice: the original's "press any key".
		_add(IntentText.CARRY_ON, "", true, null)
	for entry: Dictionary in entries:
		_add(IntentText.option(entry, state), IntentText.note(entry),
				IntentText.enabled(entry), entry.get("id"))

	_scroll.custom_minimum_size.y = mini(entries.size(), SCROLL_AFTER) * ROW_HEIGHT
	_refuse.visible = intent.cancellable
	_refuse.text = IntentText.refusal(intent)
	visible = true
	_focus_first()


## Takes the dialog away.
func dismiss() -> void:
	visible = false


func _add(label: String, note: String, enabled: bool, id: Variant) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var button := Button.new()
	# The number that picks it, so the shortcut is visible rather than folklore.
	var place := _ids.size() + 1
	button.text = "%d. %s" % [place, label] if place <= SHORTCUTS else label
	button.disabled = not enabled
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(func() -> void: chosen.emit(id))
	_ids[button] = id
	row.add_child(button)

	if not note.is_empty():
		var cost := Label.new()
		cost.text = note
		cost.add_theme_color_override("font_color", Palette.TEXT_DIM)
		cost.custom_minimum_size.x = 72
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(cost)

	_options.add_child(row)


func _focus_first() -> void:
	if not is_inside_tree():
		return
	for row in _options.get_children():
		for child in (row as Control).get_children():
			if child is Button and not (child as Button).disabled:
				(child as Button).grab_focus()
				return


func _build() -> void:
	# The dialog takes the keyboard so its shortcuts work wherever focus is.
	focus_mode = Control.FOCUS_ALL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)

	_title = Label.new()
	_title.add_theme_color_override("font_color", Palette.ACCENT)
	box.add_child(_title)

	_detail = Label.new()
	_detail.add_theme_color_override("font_color", Palette.TEXT_DIM)
	box.add_child(_detail)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)

	_options = VBoxContainer.new()
	_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_options.add_theme_constant_override("separation", 4)
	_scroll.add_child(_options)

	_refuse = Button.new()
	_refuse.pressed.connect(func() -> void: declined.emit())
	box.add_child(_refuse)
