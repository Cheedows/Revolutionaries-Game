class_name SiteMapView
extends PanelContainer
## The floor plan the squad is standing in.
##
## The original draws this as a grid of characters in a terminal and colours
## them by what is in each square. This draws the same grid, because a floor
## plan really is a grid — but as tiles rather than glyphs, and only the part
## of it the squad has seen.

## How big one square is drawn.
const TILE := 12

## How much of the plan is shown around the squad.
const ACROSS := 41
const DOWN := 17

## What a square that has not been seen looks like, and one that has.
const ROCK := Color("22262e")
const FLOOR := Color("30363f")


var _grid: Control
var _state: GameState


func _ready() -> void:
	_build()


## Redraws from [param state]. Does nothing useful outside a site.
func refresh(state: GameState) -> void:
	_build()
	_state = state
	_grid.queue_redraw()


func _build() -> void:
	if _grid != null:
		return
	add_theme_stylebox_override("panel", UiTheme.panel())
	var column := VBoxContainer.new()
	add_child(column)

	var heading := Label.new()
	heading.text = "Where you are"
	heading.add_theme_color_override("font_color", Palette.ACCENT)
	column.add_child(heading)

	_grid = Control.new()
	_grid.custom_minimum_size = Vector2(ACROSS * TILE, DOWN * TILE)
	_grid.draw.connect(_draw_grid)
	column.add_child(_grid)


func _draw_grid() -> void:
	if _state == null or _state.site.map == null or _state.site.location == -1:
		return
	var map := _state.site.map
	var here := Vector2i(_state.site.x, _state.site.y)
	var z := _state.site.z
	var left := here.x - ACROSS / 2
	var top := here.y - DOWN / 2

	for row in DOWN:
		for column in ACROSS:
			var x := left + column
			var y := top + row
			if x < 0 or y < 0 or x >= LevelMap.WIDTH or y >= LevelMap.HEIGHT:
				continue
			var at := Rect2(column * TILE, row * TILE, TILE - 1, TILE - 1)
			_grid.draw_rect(at, _colour_of(map, x, y, z))

	# The squad, and whoever is in the room with them.
	var middle := Rect2((ACROSS / 2) * TILE, (DOWN / 2) * TILE, TILE - 1, TILE - 1)
	_grid.draw_rect(middle, Palette.LIBERAL)
	if not _state.site.encounter_ids.is_empty():
		_grid.draw_rect(middle.grow(-3), Palette.CONSERVATIVE)


## What one square is worth looking at.
func _colour_of(map: LevelMap, x: int, y: int, z: int) -> Color:
	var flags := map.get_flag(x, y, z)
	if flags & int(Tables.SITE_BLOCKS[&"known"]) == 0:
		return ROCK
	if flags & int(Tables.SITE_BLOCKS[&"block"]) != 0:
		return ROCK
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
