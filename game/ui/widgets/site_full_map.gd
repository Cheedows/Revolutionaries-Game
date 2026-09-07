class_name SiteFullMap
extends PanelContainer
## Full current floor, with a zoomed view that can be dragged on touchscreens.
signal closed
var _state: GameState
var _canvas: Control
var _tile := 20
var _zoom: Button

func open(state: GameState) -> void:
	_state = state
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_theme_stylebox_override(&"panel", UiTheme.panel())
	var column := Atoms.column(Metrics.SNUG)
	add_child(column)
	column.add_child(Atoms.wrapped(Atoms.heading("Full map")))
	column.add_child(Atoms.wrapped(Atoms.dim(SiteText.underfoot(state))))
	column.add_child(Atoms.wrapped(Atoms.dim("@ Squad  D Door  W Wall  E Exit  U Unit  H Heavy unit  T Trap")))
	_zoom = Atoms.button("Overview")
	_zoom.pressed.connect(func() -> void:
		_tile = maxi(3, int(size.x / LevelMap.WIDTH)) if _tile == 20 else 20
		_canvas.custom_minimum_size = Vector2(LevelMap.WIDTH, LevelMap.HEIGHT) * _tile
		_canvas.queue_redraw())
	column.add_child(_zoom)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.set_meta(&"own_scroller", true)
	column.add_child(scroll)
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	_canvas.custom_minimum_size = Vector2(LevelMap.WIDTH, LevelMap.HEIGHT) * _tile
	_canvas.draw.connect(_draw_map)
	scroll.add_child(_canvas)
	var back := Atoms.quiet("Back")
	back.pressed.connect(func() -> void: closed.emit())
	column.add_child(back)
	Metrics.enlarge(self, Metrics.touch(self))
	PressFeel.teach(self)

func _draw_map() -> void:
	var map := _state.site.map
	if map == null: return
	for y in LevelMap.HEIGHT:
		for x in LevelMap.WIDTH:
			var flags := map.get_flag(x, y, _state.site.z)
			if not flags & int(Tables.SITE_BLOCKS[&"known"]): continue
			var rect := Rect2(x * _tile, y * _tile, _tile - 1, _tile - 1)
			var symbol := glyph(map, x, y, _state.site.z)
			var color := Palette.TEXT_DIM if symbol == "W" else Palette.SURFACE_RAISED
			if symbol in ["U", "H", "u"]: color = Palette.CONSERVATIVE
			elif symbol == "T": color = Palette.MODERATE
			if x == _state.site.x and y == _state.site.y:
				symbol = "@"
				color = Palette.LIBERAL
			_canvas.draw_rect(rect, color)
			if _tile >= 12:
				_canvas.draw_string(get_theme_default_font(), rect.position + Vector2(0, _tile - 3), symbol,
						HORIZONTAL_ALIGNMENT_CENTER, _tile, _tile - 3, Palette.TEXT)

static func glyph(map: LevelMap, x: int, y: int, z: int) -> String:
	var siege := map.get_siege(x, y, z)
	for pair in [[&"heavy_unit", "H"], [&"unit", "U"], [&"unit_damaged", "u"], [&"trap", "T"]]:
		if siege & int(Tables.SIEGE_BLOCKS[pair[0]]): return pair[1]
	var flags := map.get_flag(x, y, z)
	for pair in [[&"block", "W"], [&"door", "D"], [&"exit", "E"], [&"loot", "$"]]:
		if flags & int(Tables.SITE_BLOCKS[pair[0]]): return pair[1]
	return "."
