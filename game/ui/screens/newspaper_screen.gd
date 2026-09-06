class_name NewspaperScreen
extends FocusPage
## The morning paper gets its own page, as it did in the original.

signal finished

var _session: Session
var _events: Array[Event] = []
var _paper: NewspaperPanel


func setup(session: Session, events: Array[Event] = []) -> void:
	_session = session
	_events = events
	_build()
	adapt()
	_status.refresh(_session.state)
	_paper.show_paper(_session.state, _events)


func _build() -> void:
	if _page != null:
		return
	frame()
	_paper = NewspaperPanel.new()
	_paper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page.add_child(_paper)
	_paper.closed.connect(func() -> void: finished.emit())
	for scroll: ScrollContainer in Sheet._scrollers(_paper):
		Metrics.page_scroller(scroll)
	var carry := Atoms.primary("Carry on")
	carry.pressed.connect(func() -> void: finished.emit())
	_page.add_child(carry)


func adapt() -> void:
	if _page == null:
		return
	super.adapt()
	var touch := Metrics.touch(self)
	if _paper.has_method(&"compact"):
		_paper.call(&"compact", touch)
	Metrics.enlarge(self, touch)
	PressFeel.teach(self)
