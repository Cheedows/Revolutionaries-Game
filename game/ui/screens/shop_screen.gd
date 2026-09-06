class_name ShopScreen
extends FocusPage
## A shop is a place, not a modal box in the safehouse.
##
## This screen presents the shop PendingIntent while the PlayScreen keeps the
## same Session alive underneath it. Buying and selling still go through the
## deterministic core; this class only owns presentation and input.

signal finished
signal newspaper_ready(events: Array[Event])

var _session: Session
var _heading: Label
var _where: Label
var _log: LogView
var _dialog: IntentDialog


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
	_heading = Atoms.heading("Shop")
	_page.add_child(_heading)
	_where = Atoms.dim("")
	_page.add_child(_where)
	_log = LogView.new()
	_log.custom_minimum_size = Vector2(0, 96)
	_page.add_child(_log)
	_dialog = IntentDialog.new()
	_dialog.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dialog.pin(true)
	_dialog.chosen.connect(_on_answer)
	_dialog.declined.connect(func() -> void: _on_answer(null))
	_page.add_child(_dialog)


func adapt() -> void:
	if _page == null:
		return
	super.adapt()
	var touch := Metrics.touch(self)
	_dialog.compact(touch)
	Metrics.enlarge(self, touch)
	PressFeel.teach(self)


func _settle() -> void:
	var morning: Array[Event] = BaseOrders.drain(_session, _log)
	if not morning.is_empty():
		newspaper_ready.emit(morning)
		return
	if not _shop_waiting():
		finished.emit()
		return
	_refresh()


func _refresh() -> void:
	_status.refresh(_session.state)
	var intent := _session.pending().intent
	var location_id := int(intent.context.get("location", -1))
	var site: Location = _session.state.locations.get(location_id)
	_heading.text = site.name if site != null else "Shop"
	_where.text = "Shopping" if site == null else "At %s" % site.name
	_dialog.ask(intent, _session.state)
	adapt()


func _on_answer(id: Variant) -> void:
	if not _session.is_waiting():
		return
	_session.answer(id)
	_settle()


func _shop_waiting() -> bool:
	if _session == null or not _session.is_waiting():
		return false
	var type := _session.pending().intent.type
	return type == Intent.CHOOSE_PURCHASE \
			or type == Intent.CHOOSE_ITEMS_TO_FENCE \
			or type == Intent.CHOOSE_SHOP_DEPARTMENT
