class_name PanelStack
extends VBoxContainer
## The panels that open over the roster, one at a time.
##
## The original reaches each of these from its own key and draws each on its
## own screen, and only one can be up at once. That is worth keeping — they are
## all long — so they live together here and the screen asks for one by name.

## Emitted when something in an open panel changed the game.
signal changed

## Emitted when a panel has something to tell the player.
signal reported(message: String)

## Nothing open.
const NONE := &"none"
const DOSSIER := &"dossier"
const AGENDA := &"agenda"
const HOUSE := &"house"
const PAPER := &"paper"
const STORES := &"stores"
const SETTINGS := &"settings"
const JUSTICE := &"justice"
const SLEEPERS := &"sleepers"
const SQUAD := &"squad"

var _dossier: Dossier
var _agenda: AgendaPanel
var _house: SafehousePanel
var _paper: NewspaperPanel
var _stores: StoresPanel
var _settings: SettingsPanel
var _justice: JusticePanel
var _sleepers: SleeperPanel
var _squad: MarshallingPanel


func _ready() -> void:
	_build()


## Opens [param which], closing whatever else was open. [param subject] is the
## person for a dossier and the morning's events for the paper.
func open(which: StringName, session: Session, subject: Variant = null) -> void:
	_build()
	_agenda.visible = false
	_house.visible = false
	_paper.visible = false
	_stores.visible = false
	_settings.visible = false
	_justice.visible = false
	_sleepers.visible = false
	_squad.visible = false
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
		STORES:
			_stores.show_stores(session)
		SETTINGS:
			_settings.show_settings(session)
		JUSTICE:
			_justice.show_state(session.state)
		SLEEPERS:
			_sleepers.show_sleepers(session)
		SQUAD:
			_squad.show_squad(session)
	visible = is_open()


## Whether anything is up.
func is_open() -> bool:
	_build()
	return _dossier.visible or _agenda.visible or _house.visible \
			or _paper.visible or _stores.visible or _settings.visible \
			or _justice.visible or _sleepers.visible or _squad.visible


func _build() -> void:
	if _dossier != null:
		return
	add_theme_constant_override("separation", 0)
	_dossier = Dossier.new()
	_agenda = AgendaPanel.new()
	_house = SafehousePanel.new()
	_paper = NewspaperPanel.new()
	_stores = StoresPanel.new()
	_settings = SettingsPanel.new()
	_justice = JusticePanel.new()
	_sleepers = SleeperPanel.new()
	_squad = MarshallingPanel.new()
	for panel: Control in [_dossier, _agenda, _house, _paper, _stores,
			_settings, _justice, _sleepers, _squad]:
		panel.custom_minimum_size = Vector2(0, 320)
		panel.visible = false
		panel.connect(&"closed", func() -> void:
			panel.visible = false
			visible = false
			changed.emit())
		if panel.has_signal(&"changed"):
			panel.connect(&"changed", func() -> void: changed.emit())
		if panel.has_signal(&"saved"):
			panel.connect(&"saved", func(message: String) -> void:
				reported.emit(message))
		add_child(panel)
