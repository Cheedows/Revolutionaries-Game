class_name PixelArtRect
extends TextureRect
## A picture from [PixelArt], on screen.
##
## Everything about showing pixel art that is not about making it: nearest
## neighbour, so enlarging it keeps its edges instead of smearing them; no
## width of its own, so a masthead eighty cells across does not drag the page
## off the side of a phone; and its own height, so it does not collapse to
## nothing in a column that is deciding who gets what.

## How tall a picture stands by default, as a share of its natural height.
const NATURAL := 1.0


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Shows [param image] at [param tall] pixels high, keeping its shape.
##
## The height is asked for and the width is not: a picture in a column should
## take the width it is given and stand as tall as it needs to, which is the
## opposite of what a [TextureRect] does if left alone.
func show_image(image: Image, tall: int) -> void:
	texture = PixelArt.texture(image)
	custom_minimum_size = Vector2(0.0, float(tall))


## Shows one of the original's own pictures, out of [CharArt].
func show_art(art: Dictionary, index: int, tall: int,
		tint: Color = Color.TRANSPARENT) -> void:
	show_image(PixelArt.from_cells(art, index, tint), tall)
