class_name PanelStack
extends VBoxContainer
## The panels that open over the roster, one at a time.
##
## The original reaches each of these from its own key and draws each on its
## own screen, and only one can be up at once. That is worth keeping — they are
## all long — so they live together here and the screen asks for one by name.

## Emitted when something in an open panel changed the game.
signal changed

## Nothing open.
const NONE := &"none"
const DOSSIER := &"dossier"
const AGENDA := &"agenda"
const HOUSE := &"house"
const PAPER := &"paper"

var _dossier: Dossier
var _agenda: AgendaPanel
var _house: SafehousePanel
var _paper: NewspaperPanel


func _ready() -> void:
	_build()


## Opens [param which], closing whatever else was open. [param subject] is the
## person for a dossier and the morning's events for the paper.
func open(which: StringName, session: Session, subject: Variant = null) -> void:
	_build()
	_agenda.visible = false
	_house.visible = false
	_paper.visible = false
	_dossier.show_creature(session, null)
	match which:
		DOSSIER:
			_dossier.show_creature(session, subject as Creature)
		AGENDA:
			_agenda.show_state(session.state)
		HOUSE:
			_house.show_house(session)
		PAPER:
			_paper.show_paper(session.state, subject as Array[Event])
	visible = is_open()


## Whether anything is up.
func is_open() -> bool:
	_build()
	return _dossier.visible or _agenda.visible or _house.visible \
			or _paper.visible


func _build() -> void:
	if _dossier != null:
		return
	add_theme_constant_override("separation", 0)
	_dossier = Dossier.new()
	_agenda = AgendaPanel.new()
	_house = SafehousePanel.new()
	_paper = NewspaperPanel.new()
	for panel: Control in [_dossier, _agenda, _house, _paper]:
		panel.custom_minimum_size = Vector2(0, 320)
		panel.visible = false
		panel.connect(&"closed", func() -> void:
			panel.visible = false
			visible = false
			changed.emit())
		if panel.has_signal(&"changed"):
			panel.connect(&"changed", func() -> void: changed.emit())
		add_child(panel)
