class_name SiteMap
extends Resource
## A hand-drawn site floor plan, from the art/mapCSV_* pairs.
##
## Tiles and specials are parallel grids in row-major order, indexed
## [code]y * width + x[/code]. Tile and special numbers are the original's;
## their meanings live with the site systems in core/, not here.

@export var idname: StringName = &""
@export var width: int = 0
@export var height: int = 0
@export var tiles: PackedInt32Array = PackedInt32Array()
@export var specials: PackedInt32Array = PackedInt32Array()
