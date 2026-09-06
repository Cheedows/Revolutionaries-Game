class_name FocusPage
extends Control
## Shared frame for one full-page task, with fixed status and Back controls.

var name_state: GameState
var _page: VBoxContainer
var _status: StatusBar
var _back_button: Button


func frame(back_action: Callable = Callable()) -> VBoxContainer:
	if _page != null:
		return _page
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Palette.BACKGROUND
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_page = Atoms.column(Metrics.ROOM)
	_page.minimum_size_changed.connect(_fit_page.call_deferred)
	_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_page)
	_status = StatusBar.new()
	_status.compact(Metrics.touch(self))
	_page.add_child(_status)
	if back_action.is_valid():
		_back_button = Icons.on(Atoms.quiet("Back"), &"back", Palette.TEXT_DIM)
		_back_button.pressed.connect(back_action)
		_page.add_child(_back_button)
	return _page


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _page != null:
		adapt.call_deferred()


func adapt() -> void:
	if _page == null:
		return
	var touch := Metrics.touch(self)
	theme = UiTheme.build(touch)
	_status.compact(touch)
	var gap := Metrics.gap(self)
	_page.offset_left = gap
	_page.offset_top = gap
	_page.offset_right = -gap
	_page.offset_bottom = -gap
	_page.add_theme_constant_override(&"separation", gap)
	Metrics.enlarge(self, touch)
	PressFeel.teach(self)
	NameColours.paint_tree(self, name_state)
	_fit_page.call_deferred()


func _fit_page() -> void:
	if is_inside_tree() and _page != null and _page.is_node_ready():
		_page.size = size - Vector2.ONE * (Metrics.gap(self) * 2)
