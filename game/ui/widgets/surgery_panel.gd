class_name SurgeryPanel
extends PanelContainer
## Fitting something to somebody, in the safehouse.
##
## Draws select_augmentation() from src/basemode/activate.cpp. One Liberal
## operates on another with whatever they know of science and first aid; the
## original reaches it from the activation screen, and this reaches it from
## the record of whoever is doing the operating.

## Emitted when an operation has been performed.
signal changed

## Emitted when the panel should close.
signal closed

var _session: Session
var _surgeon: Creature
var _body: VBoxContainer
var _title: Label
var _notice: Label


func _ready() -> void:
	_build()


## Shows what [param surgeon] could do, and to whom.
func show_surgeon(session: Session, surgeon: Creature) -> void:
	_build()
	_session = session
	_surgeon = surgeon
	visible = surgeon != null
	if surgeon != null:
		_refresh()


func _refresh() -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_notice.visible = false

	_title.text = "%s operating — hands worth %d" % [_surgeon.name,
			Augmentation.skill_of(_surgeon)]
	var patients := Augmentation.patients(_session.state, _surgeon)
	if patients.is_empty():
		_line("Nobody else is here to be operated on.")
		return
	for patient in patients:
		_heading(patient.name)
		var offered := 0
		for slot: StringName in Augmentation.SLOTS:
			for type: AugmentType in Augmentation.available(_session.state,
					patient, slot, _session.catalog):
				_body.add_child(_row(patient, slot, type))
				offered += 1
		if offered == 0:
			_line("  Nothing can be fitted to them today.")


## One thing that could be fitted, and the button that fits it.
func _row(patient: Creature, slot: StringName, type: AugmentType) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = "  %s — %s" % [String(slot).capitalize(), type.name]
	label.add_theme_color_override("font_color", Palette.TEXT_DIM)
	row.add_child(label)

	var risk := Label.new()
	risk.text = "difficulty %d" % type.difficulty
	risk.add_theme_color_override("font_color", Palette.TEXT_FAINT)
	row.add_child(risk)

	var go := Button.new()
	go.text = "Operate"
	go.pressed.connect(func() -> void:
		var refused := Commands.operate(_session, _surgeon, patient, type)
		if refused != "":
			_notice.text = refused
			_notice.visible = true
			return
		changed.emit()
		_refresh())
	row.add_child(go)
	return row


func _build() -> void:
	if _body != null:
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

	_notice = Label.new()
	_notice.visible = false
	_notice.add_theme_color_override("font_color", Palette.CONSERVATIVE)
	column.add_child(_notice)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 2)
	scroll.add_child(_body)


func _heading(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Palette.ACCENT)
	_body.add_child(label)


func _line(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Palette.TEXT_FAINT)
	_body.add_child(label)
