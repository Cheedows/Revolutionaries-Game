class_name SurgeryPanel
extends Card
## Fitting something to somebody, in the safehouse.
##
## Draws select_augmentation() from src/basemode/activate.cpp. One Liberal
## operates on another with whatever they know of science and first aid; the
## original reaches it from the activation screen, and this reaches it from
## the record of whoever is doing the operating.

## Emitted when an operation has been performed.
signal changed

var _session: Session
var _surgeon: Creature


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
	refuse("")

	_head.set_title("%s will augment another Liberal to make them physically " \
			% _surgeon.name + "superior.")
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
	var row := Atoms.row(Metrics.SNUG)
	var label := Atoms.dim("  %s - %s" % [String(slot).capitalize(), type.name])
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var risk := Atoms.tinted("difficulty %d" % type.difficulty, Palette.TEXT_FAINT)
	row.add_child(risk)

	var go := Atoms.button("Operate", false)
	go.pressed.connect(func() -> void:
		var refused := Commands.operate(_session, _surgeon, patient, type)
		if refused != "":
			refuse(refused)
			return
		changed.emit()
		_refresh())
	row.add_child(go)
	return row


func _build() -> void:
	card()


func _heading(text: String) -> void:
	var label := Atoms.wrapped(Atoms.heading(text))
	_body.add_child(label)


func _line(text: String) -> void:
	var label := Atoms.wrapped(Atoms.tinted(text, Palette.TEXT_FAINT))
	_body.add_child(label)
