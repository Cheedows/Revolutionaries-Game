class_name SiteScreen
extends FocusPage
## The squad inside a location. The safehouse is not part of this screen.

signal finished
signal newspaper_ready(events: Array[Event])

var _session: Session
var _map: SiteMapView
var _log: LogView
var _dialog: IntentDialog
var _people: SitePeople
var _inventory: SiteInventory
var _transcript: SiteTranscript
var _exchange: Dictionary = {}
var _party: SiteParty
var _full_map: SiteFullMap


func setup(session: Session) -> void:
	_session = session
	_build()
	adapt()
	_log.clear()
	_settle()


func _build() -> void:
	if _page != null:
		return
	frame()
	_status.hide()
	_party = SiteParty.new()
	_party.inspect_wanted.connect(func() -> void: _on_answer(SiteActionDialog.INVENTORY))
	_page.add_child(_party)
	_map = SiteMapView.new()
	_map.size_flags_vertical = Control.SIZE_FILL
	_map.step_wanted.connect(_on_step)
	_party.map_wanted.connect(_open_map)
	_page.add_child(_map)
	_people = SitePeople.new()
	_people.talk_wanted.connect(_on_talk_to)
	_page.add_child(_people)
	_log = LogView.new()
	_log.conversation.connect(func(line: Dictionary) -> void: _exchange = line)
	_log.custom_minimum_size = Vector2(0, 120)
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page.add_child(_log)
	_dialog = SiteActionDialog.new()
	_dialog.pin(true)
	_dialog.chosen.connect(_on_answer)
	_dialog.declined.connect(func() -> void: _on_answer(null))
	_page.add_child(_dialog)
	_inventory = SiteInventory.new()
	_inventory.hide()
	_inventory.closed.connect(func() -> void:
		_inventory.hide()
		_page.show()
		if _session.is_waiting() and _session.pending().intent.type == Intent.EQUIP_SQUAD:
			_on_answer(null))
	_inventory.equipment_wanted.connect(func() -> void: _on_answer(SiteLoop.EQUIP))
	add_child(_inventory)
	_transcript = SiteTranscript.new()
	_transcript.hide()
	_transcript.closed.connect(func() -> void:
		_transcript.hide()
		_page.show())
	add_child(_transcript)


func _settle() -> void:
	var morning: Array[Event] = BaseOrders.drain(_session, _log)
	if not morning.is_empty():
		newspaper_ready.emit(morning)
		return
	if not _inside():
		finished.emit()
		return
	_refresh()
	if not _exchange.is_empty():
		_transcript.show_exchange(_exchange)
		_exchange = {}
		_page.hide()


func _refresh() -> void:
	if _session.is_waiting() and _session.pending().intent.type == Intent.EQUIP_SQUAD:
		_inventory.show_inventory(_session)
		_page.hide()
		return
	_status.refresh(_session.state)
	_party.refresh(_session.state)
	_map.refresh(_session.state)
	var moving := _session.is_waiting() and _session.pending().intent.type == Intent.CHOOSE_SITE_MOVE
	_map.allow_steps(moving)
	var fighting := _session.state.site.alarm or (_session.is_waiting() and
			_session.pending().intent.type in [Intent.CHOOSE_ATTACK_TARGET,
			Intent.CHOOSE_ENCOUNTER_RESPONSE, Intent.CONFIRM_RETREAT])
	_map.visible = moving or fighting
	_people.in_combat = fighting
	_people.can_talk = moving
	_people.refresh(_session.state)
	_log.show()
	_log.custom_minimum_size.y = 120 if moving or fighting else 72
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL if moving or fighting else Control.SIZE_FILL
	if _session.is_waiting():
		var intent := _session.pending().intent
		if moving:
			var options: Array[Dictionary] = []
			# People own conversation; the map owns movement. These are the other actions.
			for action in [SiteLoop.WAIT, SiteLoop.FIGHT, SiteLoop.USE, SiteLoop.TAKE,
					SiteLoop.RELOAD, SiteLoop.GRAB, SiteLoop.RELEASE, SiteLoop.FREE]:
				for option: Dictionary in intent.options:
					if option.id == action:
						options.append(option)
			intent = Intent.new(intent.type, options, intent.context, false)
		_dialog.ask(intent, _session.state)
	else:
		_dialog.dismiss()
	adapt()


func _on_talk_to(id: int) -> void:
	if not _session.is_waiting() or _session.pending().intent.type != Intent.CHOOSE_SITE_MOVE:
		return
	if not SiteConversation.available(_session.state, _session.state.creatures.get(id)):
		return
	_on_answer(SiteLoop.TALK)
	if _session.is_waiting() and _session.pending().intent.context.get("select_listener", false):
		_on_answer(id)


func _input(event: InputEvent) -> void:
	if _full_map != null:
		if event.is_action_pressed(&"ui_cancel"): back()
		return
	if _transcript != null and _transcript.visible:
		if event.is_action_pressed(&"ui_cancel"):
			back()
			get_viewport().set_input_as_handled()
		return
	if _inventory != null and _inventory.visible:
		if event.is_action_pressed(&"ui_cancel"):
			_inventory.closed.emit()
			get_viewport().set_input_as_handled()
		return
	if _session == null or not _session.is_waiting() or _session.pending().intent.type != Intent.CHOOSE_SITE_MOVE:
		return
	if not event.is_pressed() or event.is_echo():
		return
	for action: StringName in [&"ui_up", &"ui_down", &"ui_left", &"ui_right"]:
		if event.is_action_pressed(action):
			_on_step([&"ui_up", &"ui_down", &"ui_left", &"ui_right"].find(action))
			get_viewport().set_input_as_handled()
			return


func _on_answer(id: Variant) -> void:
	if id is StringName and id == SiteActionDialog.INVENTORY:
		_inventory.show_inventory(_session)
		_page.hide()
		return
	if not _session.is_waiting():
		return
	_session.answer(id)
	_settle()


func _on_step(direction: int) -> void:
	if _session.is_waiting() \
			and _session.pending().intent.type == Intent.CHOOSE_SITE_MOVE:
		_on_answer(direction)


func _inside() -> bool:
	return _session != null and _session.state.mode == &"site" \
			and _session.state.site.location != -1


func adapt() -> void:
	if _page == null:
		return
	super.adapt()
	var touch := Metrics.touch(self)
	_map.compact(touch)
	_dialog.compact(touch)
	Metrics.enlarge(self, touch)
	PressFeel.teach(self)


func back() -> void:
	if _full_map != null:
		_full_map.closed.emit()
		return
	if _transcript.visible:
		_transcript.closed.emit()
	elif _inventory.visible:
		_inventory.closed.emit()
	elif _session.is_waiting() and _session.pending().intent.cancellable:
		_on_answer(null)


func _open_map() -> void:
	_full_map = SiteFullMap.new()
	add_child(_full_map)
	_page.hide()
	_full_map.closed.connect(func() -> void:
		_full_map.queue_free()
		_full_map = null
		_page.show())
	_full_map.open(_session.state)
