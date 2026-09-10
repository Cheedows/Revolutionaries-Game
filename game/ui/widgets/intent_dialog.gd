class_name IntentDialog
extends PanelContainer
## Renders simulation questions as rows plus an action bar.
## Screens need a bespoke dialog only when that shared shape is not enough.

signal chosen(id: Variant)
signal declined

## Number keys pick the first nine listed options.
const SHORTCUTS := 9

var _title: Label
var _detail: NameText
var _options: Container
var _scroll: ScrollContainer
var _content: Container
var _bar: ActionBar
var _refuse: Button

## Button -> option id, keeping ids independent of layout.
var _ids: Dictionary = {}
## Count listed rows only; action-bar buttons are not numbered.
var _listed := 0
## Last answer, so rebuilt choices restore keyboard focus.
var _last: Variant = null
## Whether the options are being sized for a fingertip.
var _touch := false
## Whether the bar is pinned below a scrolling list.
var _pinned := false


func _init() -> void:
	visible = false
	_build()


## Number keys answer; escape declines a cancellable question.
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
	var listed := _listed_buttons()
	if index >= listed.size() or listed[index].disabled:
		return
	_answer(_ids.get(listed[index]))
	accept_event()


## Sizes the next set of options for a finger or pointer.
func compact(on: bool) -> void:
	_touch = on
	_bar.adapt(on)
	_sync_unpinned_height()


## Pins the action bar while the choices scroll. Unpinned dialogs instead
## contribute their full choice height to the screen's own scroller.
func pin(on: bool) -> void:
	_pinned = on
	size_flags_vertical = Control.SIZE_EXPAND_FILL if on else Control.SIZE_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL if on \
			else Control.SIZE_FILL
	if on:
		# The one scroller on the screen; Metrics.unscroll() leaves it alone.
		Metrics.page_scroller(_scroll)
	else:
		if _scroll.has_meta(&"page_scroller"):
			_scroll.remove_meta(&"page_scroller")
		_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sync_unpinned_height()

## Shows [param intent]. The dialog stays up until an option is taken.
func ask(intent: Intent, state: GameState) -> void:
	_title.text = IntentText.question(intent, state)
	_title.visible = not _title.text.is_empty()
	_detail.referents = NameColours.referents(intent.context)
	_detail.show_text(IntentText.detail(intent, state), state, Palette.TEXT_DIM)
	_detail.visible = not _detail.get_parsed_text().is_empty()

	_ids.clear()
	_listed = 0
	for child in _options.get_children():
		_options.remove_child(child)
		child.queue_free()
	# Keep the persistent Back/Cancel control out of the disposable action list.
	if _refuse.get_parent() != null:
		_refuse.get_parent().remove_child(_refuse)
	_bar.clear()

	var entries := intent.options
	if entries.is_empty():
		# A report rather than a choice: the original's "press any key".
		_add(IntentText.CARRY_ON, "", true, null, false, false)
	for entry: Dictionary in entries:
		var label := IntentText.option(entry, state)
		var enabled := IntentText.enabled(entry)
		if bool(entry.get("footer", false)):
			var action := Atoms.primary(label)
			action.disabled = not enabled
			action.pressed.connect(_answer.bind(entry.get("id")))
			_ids[action] = entry.get("id")
			_bar.add(action)
			continue
		_add(label, IntentText.note(entry), enabled, entry.get("id"),
				bool(entry.get("toggle", false)), bool(entry.get("on", false)),
				bool(entry.get("under", false)))

	_refuse.visible = intent.cancellable
	_refuse.text = IntentText.refusal(intent)
	if _refuse.visible:
		_bar.add(_refuse)
	else:
		add_child(_refuse)
	_bar.visible = _bar.filled()
	_bar.adapt(_touch)
	NameColours.paint_choices(_options, _ids, state)
	_sync_unpinned_height()
	visible = true
	_restore()
	PressFeel.teach(self)


## Answerable ids in player order: listed rows, then the action bar.
func answerable() -> Array:
	var ids: Array = []
	for button in _listed_buttons():
		if not button.disabled:
			ids.append(_ids.get(button))
	for button in _bar.buttons():
		if not button.disabled and button != _refuse:
			ids.append(_ids.get(button))
	return ids

## Every offered id and whether it is enabled, including refused choices.
func offered() -> Dictionary:
	var found := {}
	for button in _listed_buttons():
		found[_ids.get(button)] = not button.disabled
	for button in _bar.buttons():
		if button != _refuse:
			found[_ids.get(button)] = not button.disabled
	return found


## Takes the dialog away.
func dismiss() -> void:
	visible = false


func _answer(id: Variant) -> void:
	_last = id
	chosen.emit(id)


func _add(label: String, note: String, enabled: bool, id: Variant,
		toggle: bool, on: bool, under: bool = false) -> void:
	_listed += 1
	# Numbers are keyboard affordances, so phone rows do not draw them.
	var place := 0 if _touch else (_listed if _listed <= SHORTCUTS else 0)
	var button: Button
	if toggle:
		var switch := ToggleRow.new(label, note, place, _touch)
		# Refused wins over "on", matching the classic-mode override.
		switch.disabled = not enabled
		switch.set_on(on)
		button = switch
	else:
		button = OptionRow.new(label, note, place, _touch, under)
	button.disabled = not enabled
	button.pressed.connect(_answer.bind(id))
	_ids[button] = id
	_options.add_child(button)


func _listed_buttons() -> Array[Button]:
	var found: Array[Button] = []
	for child in _options.get_children():
		if child is Button:
			found.append(child)
	return found


## The keyboard target: none on touch, otherwise the last answer if reachable.
func keyboard_lands_on() -> Variant:
	if _touch or Metrics.handheld():
		return null
	return DialogKeys.lands_on(_reachable(), _ids, _last)


func _reachable() -> Array[Button]:
	var reachable := _listed_buttons()
	reachable.append_array(_bar.buttons())
	return reachable


func _restore() -> void:
	if not is_inside_tree():
		return
	var wanted: Variant = keyboard_lands_on()
	for button in _reachable():
		if not button.disabled and DialogKeys.same(_ids.get(button), wanted):
			button.grab_focus()
			return


## ScrollContainer does not inherit the minimum height of its child. When this
## dialog is unpinned its inner scroller is only a layout wrapper, so mirror the
## content minimum explicitly. This is intentionally updated only at the known
## mutation/profile points above. Listening to minimum_size_changed here creates
## a feedback loop through ScrollContainer/Container relayout on desktop and can
## prevent the first frame from being drawn.
func _sync_unpinned_height() -> void:
	if _scroll == null or _content == null:
		return
	_scroll.custom_minimum_size.y = 0.0 if _pinned \
			else _content.get_combined_minimum_size().y


func _build() -> void:
	# The dialog takes the keyboard so its shortcuts work wherever focus is.
	focus_mode = Control.FOCUS_ALL
	var box := Atoms.column(Metrics.SNUG)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(box)

	_title = Atoms.wrapped(Atoms.heading(""))
	box.add_child(_title)

	_detail = NameText.new()

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Unpinned dialogs belong to the screen scroller and must expose full height.
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_scroll)

	_options = Atoms.column(Metrics.TIGHT)
	_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content = Atoms.column(Metrics.TIGHT)
	_scroll.add_child(_content)
	_content.add_child(_detail)
	_content.add_child(_options)

	_bar = ActionBar.new()
	_bar.visible = false
	box.add_child(_bar)

	_refuse = Atoms.button("")
	_refuse.visible = false
	add_child(_refuse)
	_refuse.pressed.connect(func() -> void: declined.emit())
