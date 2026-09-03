class_name IntentDialog
extends PanelContainer
## Renders any question the simulation asks, whatever it is about.
##
## Every system in core/ parks on a [PendingIntent] rather than blocking, and
## every one of those carries the same shape: a type, some context and a list
## of options. So one widget can render all of them, and a screen only needs a
## bespoke one where a list of buttons is genuinely not enough.
##
## The options themselves are [OptionRow]s and [ToggleRow]s, and the ways out
## live in an [ActionBar]; this decides which of them a question needs and
## keeps track of what the player can currently answer.
##
## Emits [signal chosen] with the option's id, or [signal declined] when the
## player backs out of a question that allows it.

signal chosen(id: Variant)
signal declined

## The number keys pick the first nine options, as the original's letters pick
## its own. Past nine there is no key for it and the list is walked instead.
const SHORTCUTS := 9

var _title: Label
var _detail: Label
var _options: VBoxContainer
var _scroll: ScrollContainer
var _bar: ActionBar
var _refuse: Button

## The option each button stands for, so the buttons stay the only thing that
## knows about layout and the ids stay data.
var _ids: Dictionary = {}

## How many of them are in the numbered list, which is what the next one's
## number is. Counted rather than taken from _ids, because the bar's buttons
## are in there too and are not numbered.
var _listed := 0

## What the player last answered. A screen that rebuilds its list after every
## answer — the switches on the new-game screen do exactly this — puts the
## keyboard back where it was rather than at the top. See [method _restore].
var _last: Variant = null

## Whether the options are being sized for a fingertip.
var _touch := false

## Whether the bar is held against the bottom of the dialog rather than
## trailing the list. See [method pin].
var _pinned := false


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
	var listed := _listed_buttons()
	if index >= listed.size() or listed[index].disabled:
		return
	_answer(_ids.get(listed[index]))
	accept_event()


## Sizes the options for a finger, or back for a pointer.
##
## Takes effect on the next question rather than immediately: the options are
## rebuilt every time one is asked, and a question already on screen should not
## reshuffle itself under the thumb about to answer it.
func compact(on: bool) -> void:
	_touch = on
	_bar.adapt(on)


## Holds the ways out against the bottom of the dialog, with the options
## scrolling behind them.
##
## For a screen the dialog fills on its own. Off by default, because where the
## dialog is one panel among several the screen owns the scrolling and the bar
## rides at the end of the list like anything else.
func pin(on: bool) -> void:
	_pinned = on
	size_flags_vertical = Control.SIZE_EXPAND_FILL if on else Control.SIZE_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL if on \
			else Control.SIZE_FILL
	if on:
		# The one scroller on the screen, so Metrics.unscroll() leaves it alone
		# and the list keeps scrolling under the pinned bar.
		Metrics.page_scroller(_scroll)
	elif _scroll.has_meta(&"page_scroller"):
		_scroll.remove_meta(&"page_scroller")


## Shows [param intent]. The dialog stays up until an option is taken.
func ask(intent: Intent, state: GameState) -> void:
	_title.text = IntentText.question(intent, state)
	_title.visible = not _title.text.is_empty()
	_detail.text = IntentText.detail(intent, state)
	_detail.visible = not _detail.text.is_empty()

	_ids.clear()
	_listed = 0
	for child in _options.get_children():
		_options.remove_child(child)
		child.queue_free()
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
	_bar.visible = _bar.filled()
	_bar.adapt(_touch)
	visible = true
	_restore()


## The ids a player could take right now, in the order they would reach them:
## down the list, then along the ways out under it.
##
## The buttons stay private, but something has to be able to ask what is on
## offer without knowing where each one is drawn — a test driving the game
## through the interface, most of all, which would otherwise have to be
## rewritten every time the layout moves.
func answerable() -> Array:
	var ids: Array = []
	for button in _listed_buttons():
		if not button.disabled:
			ids.append(_ids.get(button))
	for button in _bar.buttons():
		if not button.disabled and button != _refuse:
			ids.append(_ids.get(button))
	return ids


## Every option the question put up, and whether it can be taken.
##
## The companion to [method answerable], which reports only what is live: a
## test proving an option is *offered and refused* — a saved game to carry on
## with when there is none — needs the disabled ones too. Both exist so that
## nothing outside walks the buttons. Four tests used to, and all four broke
## silently the day the rows stopped being wrapped in a container: the loop
## found nothing, and the assertion that should have failed errored instead
## and was counted as a pass.
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
	# The number is only drawn where there is a keyboard to type it. On a phone
	# it is a number nobody can enter, in front of every line in the game.
	var place := 0 if _touch else (_listed if _listed <= SHORTCUTS else 0)
	var button: Button
	if toggle:
		var switch := ToggleRow.new(label, note, place, _touch)
		# Refused before it is set, so a switch that is both on and refused —
		# which is what the original leaves behind when Classic Mode is turned
		# on over the top of it — draws as refused rather than as on.
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


## Which option the keyboard should be sitting on, or null for none at all.
##
## Kept apart from the act of focusing it so that it can be asked. Godot will
## not move focus onto a control that is not inside a live tree, and this
## suite runs without one — so a test that watched for the ring would be
## watching an engine refusal rather than this decision, and would go on
## passing whatever this decided.
##
## Null on a phone. Focus draws a ring; the first option of every list was
## wearing it; and a ring around the first of six identical switches reads as
## the one already chosen. Nothing on a touchscreen has moved it there, so
## nothing should be wearing it.
##
## Otherwise the option last answered, while it is still on offer. The switches
## screen rebuilds its whole list after every press, and starting at the top
## each time means six presses to reach the sixth switch, every time.
func keyboard_lands_on() -> Variant:
	if _touch or Metrics.handheld():
		return null
	return DialogKeys.lands_on(_reachable(), _ids, _last)


## Every button a key could answer, in the order a player walks them: down the
## list, then along the ways out under it.
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


func _build() -> void:
	# The dialog takes the keyboard so its shortcuts work wherever focus is.
	focus_mode = Control.FOCUS_ALL
	var box := Atoms.column(Metrics.SNUG)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(box)

	_title = Atoms.wrapped(Atoms.heading(""))
	box.add_child(_title)

	_detail = Atoms.wrapped(Atoms.dim(""))
	box.add_child(_detail)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_scroll)

	_options = Atoms.column(Metrics.TIGHT)
	_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_options)

	_bar = ActionBar.new()
	_bar.visible = false
	box.add_child(_bar)

	_refuse = Atoms.button("")
	_refuse.pressed.connect(func() -> void: declined.emit())
