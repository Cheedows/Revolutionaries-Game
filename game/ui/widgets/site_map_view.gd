class_name SiteMapView
extends PanelContainer
## The floor plan the squad is standing in.
##
## The original draws this as a grid of characters in a terminal and colours
## them by what is in each square, and moves the squad with the arrow keys.
## This draws the same grid — as tiles rather than glyphs, and only the part of
## it the squad has seen — and lets a square next to the squad be clicked to
## walk that way, which is the same four choices the site loop offers.

## How big one square is drawn, pointed at and poked at. A finger cannot hit a
## twelve-pixel square, so on a touchscreen the squares grow and fewer of them
## are shown — the plan is read closer in rather than smaller.
const TILE := 48
const TOUCH_TILE := 48

## How much of the plan is shown around the squad, at each of those sizes.
const ACROSS := 11
const DOWN := 5
const TOUCH_ACROSS := 7
const TOUCH_DOWN := 3

## What a square that has not been seen looks like, and one that has.
const ROCK := Color("22262e")
const FLOOR := Color("30363f")


## Emitted when the player clicks a square next to the squad: the direction is
## one of [SiteLoop]'s move ids.
signal step_wanted(direction: int)
signal map_wanted

var _grid: Control
var _state: GameState
var _heading: Label
var _here: Label
var _steps: Dictionary = {}

## The size the plan is currently drawn at. Held rather than looked up so the
## drawing and the hit-testing cannot disagree about it.
var _tile := TILE
var _across := ACROSS
var _down := DOWN


func _ready() -> void:
	_build()


## Redraws from [param state]. Does nothing useful outside a site.
func refresh(state: GameState) -> void:
	_build()
	_state = state
	var location: Location = state.locations.get(state.site.location)
	_heading.text = location.name if location != null \
			else "Current Location"
	_here.text = SiteText.underfoot(state)
	for direction: int in _steps:
		var delta: Vector2i = SiteLoop.STEPS[direction]
		var x := state.site.x + delta.x
		var y := state.site.y + delta.y
		var blocked := state.site.map == null or not state.site.map.contains(x, y, state.site.z) \
				or (state.site.map.get_flag(x, y, state.site.z) & int(Tables.SITE_BLOCKS[&"block"])) != 0
		_steps[direction].disabled = blocked
	# Asking for a redraw of something nothing is looking at is not free, and
	# headless there is no drawing phase to answer it in.
	if _grid.is_visible_in_tree():
		_grid.queue_redraw()


## Draws the plan at fingertip size, or back at pointer size.
func compact(on: bool) -> void:
	_build()
	_tile = TOUCH_TILE if on else TILE
	_across = TOUCH_ACROSS if on else ACROSS
	if on:
		var available := get_viewport_rect().size.x - Metrics.gap(self) * 2 - UiTheme.PADDING * 2
		_across = mini(_across, int(available / _tile))
		if _across % 2 == 0:
			_across -= 1
	_down = TOUCH_DOWN if on else DOWN
	_here.visible = not on
	_grid.custom_minimum_size = Vector2(_across * _tile, _down * _tile)
	for direction: int in _steps:
		var delta: Vector2i = SiteLoop.STEPS[direction]
		_steps[direction].custom_minimum_size = Vector2.ONE * _tile
		_steps[direction].position = Vector2(Vector2i(_across / 2, _down / 2) + delta) * _tile
		_steps[direction].size = Vector2.ONE * (_tile - 1)
	if _grid.is_visible_in_tree():
		_grid.queue_redraw()


func _build() -> void:
	if _grid != null:
		return
	add_theme_stylebox_override("panel", UiTheme.panel())
	var column := Atoms.column(Metrics.SNUG)
	add_child(column)

	_heading = Atoms.wrapped(Atoms.heading("Current Location"))
	var heading_row := Atoms.row(Metrics.TIGHT)
	column.add_child(heading_row)
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_row.add_child(_heading)
	var full := Atoms.quiet("Map")
	full.pressed.connect(func() -> void: map_wanted.emit())
	heading_row.add_child(full)

	_grid = Control.new()
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_grid.custom_minimum_size = Vector2(_across * _tile, _down * _tile)
	_grid.draw.connect(_draw_grid)
	column.add_child(_grid)
	for direction: int in SiteLoop.STEPS:
		var button := Atoms.quiet("")
		button.custom_minimum_size = Vector2.ONE * Metrics.TOUCH_TARGET
		var outline := StyleBoxFlat.new()
		outline.draw_center = false
		outline.border_color = Palette.TEXT
		outline.set_border_width_all(3)
		button.add_theme_stylebox_override(&"normal", outline)
		button.add_theme_stylebox_override(&"hover", outline)
		button.add_theme_stylebox_override(&"pressed", outline)
		button.add_theme_stylebox_override(&"disabled", StyleBoxEmpty.new())
		button.tooltip_text = ["North", "South", "West", "East"][direction]
		button.pressed.connect(func() -> void: step_wanted.emit(direction))
		_steps[direction] = button
		_grid.add_child(button)
	column.add_child(Atoms.wrapped(Atoms.dim(
			"@ You  D Door  W Wall  E Exit")))

	# What is underfoot, which the original says in the message area.
	_here = Atoms.wrapped(Atoms.dim(""))
	column.add_child(_here)


func _draw_grid() -> void:
	if _state == null or _state.site.map == null or _state.site.location == -1:
		return
	if not _grid.is_visible_in_tree():
		return
	var map := _state.site.map
	var here := Vector2i(_state.site.x, _state.site.y)
	var z := _state.site.z
	var left := here.x - _across / 2
	var top := here.y - _down / 2

	for row in _down:
		for column in _across:
			var x := left + column
			var y := top + row
			if x < 0 or y < 0 or x >= LevelMap.WIDTH or y >= LevelMap.HEIGHT:
				continue
			var at := Rect2(column * _tile, row * _tile, _tile - 1, _tile - 1)
			_grid.draw_rect(at, _colour_of(map, x, y, z))
			var flags := map.get_flag(x, y, z)
			if flags & int(Tables.SITE_BLOCKS[&"known"]) != 0:
				var symbol := ""
				if flags & int(Tables.SITE_BLOCKS[&"block"]) != 0:
					symbol = "W"
				elif flags & int(Tables.SITE_BLOCKS[&"door"]) != 0:
					symbol = "D"
				elif flags & int(Tables.SITE_BLOCKS[&"exit"]) != 0:
					symbol = "E"
				var siege_symbol := SiteFullMap.glyph(map, x, y, z)
				if siege_symbol in ["U", "H", "u", "T"]: symbol = siege_symbol
				_mark(at, symbol)

	# The squad, and whoever is in the room with them.
	var middle := Rect2((_across / 2) * _tile, (_down / 2) * _tile,
			_tile - 1, _tile - 1)
	_grid.draw_rect(middle, Palette.LIBERAL)
	_mark(middle, "@")


func _mark(at: Rect2, symbol: String) -> void:
	var font := get_theme_default_font()
	var font_size := _tile - 6
	_grid.draw_string(font, at.position + Vector2(0, font.get_ascent(font_size)),
			symbol, HORIZONTAL_ALIGNMENT_CENTER, at.size.x, font_size,
			Palette.TEXT if symbol == "W" else Palette.BACKGROUND)


## A click on a square next to the squad walks that way.
##
## Only the four the site loop offers: a floor plan is walked a square at a
## time, and anything further is a route rather than a step.
func allow_steps(on: bool) -> void:
	for button: Button in _steps.values():
		button.visible = on


func _on_grid_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed \
			or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var column := int(click.position.x) / _tile - _across / 2
	var row := int(click.position.y) / _tile - _down / 2
	if absi(column) + absi(row) != 1:
		return
	if row == -1:
		step_wanted.emit(SiteLoop.MOVE_UP)
	elif row == 1:
		step_wanted.emit(SiteLoop.MOVE_DOWN)
	elif column == -1:
		step_wanted.emit(SiteLoop.MOVE_LEFT)
	else:
		step_wanted.emit(SiteLoop.MOVE_RIGHT)


## What one square is worth looking at.
func _colour_of(map: LevelMap, x: int, y: int, z: int) -> Color:
	var flags := map.get_flag(x, y, z)
	if flags & int(Tables.SITE_BLOCKS[&"known"]) == 0:
		return ROCK
	var siege_mark := SiteFullMap.glyph(map, x, y, z)
	if siege_mark in ["U", "H", "u"]: return Palette.CONSERVATIVE
	if siege_mark == "T": return Palette.MODERATE
	if flags & int(Tables.SITE_BLOCKS[&"block"]) != 0:
		return Palette.TEXT_DIM.darkened(0.6)
	if flags & int(Tables.SITE_BLOCKS[&"exit"]) != 0:
		return Palette.ACCENT
	if flags & int(Tables.SITE_BLOCKS[&"door"]) != 0:
		return Palette.MODERATE
	if flags & (int(Tables.SITE_BLOCKS[&"fire_peak"])
			| int(Tables.SITE_BLOCKS[&"fire_start"])) != 0:
		return Palette.EXPENSE
	if flags & (int(Tables.SITE_BLOCKS[&"bloody"])
			| int(Tables.SITE_BLOCKS[&"bloody2"])) != 0:
		return Palette.CONSERVATIVE.darkened(0.4)
	if map.get_special(x, y, z) != LevelMap.NO_SPECIAL:
		return Palette.ACCENT.darkened(0.5)
	if flags & int(Tables.SITE_BLOCKS[&"loot"]) != 0:
		return Palette.INCOME.darkened(0.4)
	return FLOOR
