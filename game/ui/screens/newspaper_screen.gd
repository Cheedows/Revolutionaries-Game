class_name NewspaperScreen
extends Control
## The morning paper gets its own page, as it did in the original.

signal finished

var _session: Session
var _events: Array[Event] = []
var _status: StatusBar
var _paper: NewspaperPanel
var _page: VBoxContainer


func setup(session: Session, events: Array[Event]) -> void:
	_session = session
	_events = events
	_build()
	_adapt()
	_status.refresh(_session.state)
	_paper.show_paper(_session.state, _events)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _page != null:
		_adapt()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST and _page != null:
		finished.emit()


func _build() -> void:
	if _page != null:
		return
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Palette.BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_page = Atoms.column(Metrics.ROOM)
	_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	_page.offset_left = 16
	_page.offset_top = 16
	_page.offset_right = -16
	_page.offset_bottom = -16
	add_child(_page)
	_status = StatusBar.new()
	_page.add_child(_status)
	_paper = NewspaperPanel.new()
	_paper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page.add_child(_paper)
	var carry := Atoms.primary("Continue")
	carry.pressed.connect(func() -> void: finished.emit())
	_page.add_child(carry)


func _adapt() -> void:
	if _page == null:
		return
	var touch := Metrics.touch(self)
	theme = UiTheme.build(touch)
	_page.add_theme_constant_override(&"separation",
			Metrics.TOUCH_GAP if touch else Metrics.BASE_GAP)
	if _paper.has_method(&"compact"):
		_paper.call(&"compact", touch)
	Metrics.enlarge(self, touch)
	PressFeel.teach(self)
