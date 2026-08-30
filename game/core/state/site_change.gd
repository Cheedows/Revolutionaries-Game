class_name SiteChange
extends RefCounted
## A lasting mark left on a site: a tag, a smashed wall, a bloodstain.
##
## Mirrors sitechangest in src/includes.h. Sites regenerate from their seed
## every visit, so anything the squad did that should still be there next time
## is kept as one of these on the location and painted back on afterwards.

var x: int = 0
var y: int = 0
var z: int = 0

## The site block flag to add, from [constant Tables.SITE_BLOCKS].
var flag: int = 0


func _init(at_x: int = 0, at_y: int = 0, at_z: int = 0, block_flag: int = 0) -> void:
	x = at_x
	y = at_y
	z = at_z
	flag = block_flag
