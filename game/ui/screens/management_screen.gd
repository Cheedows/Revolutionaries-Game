class_name ManagementScreen
extends FocusPage
## A full page for one management task. Nested tasks go through PlayScreen.

signal finished
signal page_wanted(which: StringName, subject: Variant)
signal route_changed

var kind: StringName = &"roster"
var subject: Variant = null
var history: Array[Dictionary] = []
var _session: Session
var _content: Control
var _panels: PanelStack
var _log: LogView
var _notice: Label
var _leaving := false
var _was_narrow := false


func setup(session: Session) -> void:
	_session = session
	if _page != null:
		_refresh()
		return
	var page := frame(_finish)
	_notice = Atoms.wrapped(Atoms.dim(""))
	_notice.visible = false
	page.add_child(_notice)
	_log = LogView.new()
	_log.visible = false
	add_child(_log)
	match kind:
		&"roster":
			_content = Roster.new()
			_wire_roster(_content as Roster)
		&"members":
			var squad := SquadPanel.new()
			_content = squad
			squad.changed.connect(_refresh)
			squad.destination_wanted.connect(_travel)
			var arrange := Atoms.wrapped_button(Atoms.button("Choosing the Right Liberal Vehicle"))
			arrange.pressed.connect(func() -> void: page_wanted.emit(PanelStack.SQUAD, null))
			page.add_child(arrange)
		&"country":
			_content = LawList.new()
		&"history":
			page.add_child(Atoms.title("History"))
			var log := LogView.new()
			_content = log
			log.restore(history)
		_:
			_panels = PanelStack.new()
			_content = _panels
			_panels.changed.connect(_panel_changed)
			_panels.reported.connect(_report)
			_panels.surgery_wanted.connect(func(who: Creature) -> void:
				page_wanted.emit(PanelStack.SURGERY, who))
			_panels.activity_chosen.connect(func(who: Creature, doing: StringName) -> void:
				_say(BaseOrders.assign(_session, who, doing)))
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(_content)
	_refresh()


func _wire_roster(roster: Roster) -> void:
	roster.activity_wanted.connect(func(who: Creature) -> void:
		page_wanted.emit(PanelStack.ACTIVITY, who))
	roster.dossier_wanted.connect(func(who: Creature) -> void:
		page_wanted.emit(PanelStack.DOSSIER, who))
	roster.activity_chosen.connect(func(who: Creature, doing: StringName) -> void:
		_say(BaseOrders.assign(_session, who, doing)))
	roster.code_name_changed.connect(func(who: Creature, said: String) -> void:
		MemberNames.set_code_name(_session.state, who, said)
		_refresh.call_deferred())
	roster.hostage_chosen.connect(func(keeper: Creature, held: Creature) -> void:
		_say(BaseOrders.watch(_session, keeper, held)))
	roster.recruit_chosen.connect(func(who: Creature, type: StringName) -> void:
		_say(BaseOrders.recruit(_session, who, type)))


func _refresh() -> void:
	_status.refresh(_session.state)
	_was_narrow = Metrics.touch(self)
	if _content is Roster:
		var roster := _content as Roster
		roster.compact(Metrics.touch(self))
		roster.offer_garments(AssignmentChoice.garments(_session.state, _session.catalog))
		roster.offer_recruits(Recruiting.recruitable(_session.state))
		roster.refresh(_session.state)
	elif _content is SquadPanel or _content is LawList:
		_content.call(&"refresh", _session.state)
	elif _panels != null:
		_panels.open(kind, _session, subject)
	adapt()


func _panel_changed() -> void:
	if not _panels.is_open():
		_finish()
	else:
		_status.refresh(_session.state)
		adapt.call_deferred()
		route_changed.emit()


func _travel() -> void:
	Commands.choose_destination(_session)
	route_changed.emit()


func _say(lines: PackedStringArray) -> void:
	for line in lines:
		_report(line)
	if _content is Roster:
		_refresh.call_deferred()


func _report(said: String) -> void:
	_log.append(said, Palette.TEXT_DIM)
	_notice.text = said
	_notice.visible = not said.is_empty()


func adapt() -> void:
	super.adapt()
	if _content == null:
		return
	if _content is Roster and _was_narrow != Metrics.touch(self):
		_was_narrow = Metrics.touch(self)
		_refresh.call_deferred()
	if _content.has_method(&"compact"):
		_content.call(&"compact", Metrics.touch(self))
	# Cards used to get scrolling only when a Sheet opened them. Here the
	# active card is the page, so its body must scroll under the fixed header.
	for scroll: ScrollContainer in Sheet._scrollers(_content):
		Metrics.page_scroller(scroll)
	Metrics.enlarge(self, Metrics.touch(self))
	PressFeel.teach(self)


func _finish() -> void:
	if _leaving:
		return
	_leaving = true
	finished.emit()
