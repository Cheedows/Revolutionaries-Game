class_name SiteActionDialog
extends IntentDialog
## Compact exploration buttons; conversations retain the full choice list.

const INVENTORY := &"inventory"
const ACTIONS := {
	SiteLoop.WAIT: ["Wait", &"site_wait"],
	SiteLoop.FIGHT: ["Attack", &"site_attack"],
	SiteLoop.USE: ["Use", &"site_use"],
	SiteLoop.TAKE: ["Take", &"site_take"],
	SiteLoop.RELOAD: ["Reload", &"site_reload"],
	SiteLoop.GRAB: ["Grab", &"site_grab"],
	SiteLoop.RELEASE: ["Release", &"site_release"],
	SiteLoop.FREE: ["Free", &"site_free"],
	INVENTORY: ["Inventory", &"site_inventory"],
}
var _grid := false


func ask(intent: Intent, state: GameState) -> void:
	_grid = intent.type == Intent.CHOOSE_SITE_MOVE
	var old := _options
	var content := old.get_parent()
	content.remove_child(old)
	old.queue_free()
	if _grid:
		var grid := GridContainer.new()
		grid.columns = 3
		_options = grid
	else:
		_options = Atoms.column(Metrics.TIGHT)
	_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_options)
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if _grid else ScrollContainer.SCROLL_MODE_AUTO
	pin(not _grid)
	super.ask(intent, state)
	if _grid:
		_title.hide()
		_detail.hide()
		_add("Inventory", "", true, INVENTORY, false, false)


func _add(label: String, note: String, enabled: bool, id: Variant,
		toggle: bool, on: bool, under: bool = false) -> void:
	if not _grid:
		super._add(label, note, enabled, id, toggle, on, under)
		return
	var art: Array = ACTIONS.get(id, [label, &""])
	var button := Icons.on(Atoms.button(art[0]), art[1])
	button.add_theme_font_size_override(&"font_size", 14)
	button.add_theme_constant_override(&"icon_max_width", 18)
	button.expand_icon = true
	button.custom_minimum_size = Vector2(0, Metrics.TOUCH_TARGET)
	button.tooltip_text = label
	button.disabled = not enabled
	button.pressed.connect(_answer.bind(id))
	_ids[button] = id
	_listed += 1
	_options.add_child(button)


func compact(on: bool) -> void:
	super.compact(on)
	if _grid and _options is GridContainer:
		(_options as GridContainer).columns = 3 if on else 5
