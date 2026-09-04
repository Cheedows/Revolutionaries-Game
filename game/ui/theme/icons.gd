class_name Icons
extends RefCounted
## The little pictures on the buttons.
##
## The grids themselves are [IconArt]; this makes them into textures, keeps
## the ones it has made, and hangs them on buttons.
##
## They are a second way of saying what the label already says, not a
## replacement for it. Every button that has one keeps its words: a row of
## eight unlabelled glyphs is a puzzle, and this game already asks enough of
## the player.

## How much bigger than its grid an icon is drawn.
##
## Three times, not two: at two a nine pixel grid is eighteen pixels beside a
## nineteen pixel line of text, and every icon reads as a smudge. Three is
## twenty-seven, which is about half a touch target and enough for the shapes
## to come apart.
const SCALE := 3

## The textures already made, by what was asked for.
static var _made := {}


## The icon called [param name], in [param ink], or null if there is no such
## icon.
##
## Kept once made: a roster row is rebuilt every time anything happens, and
## rasterising the same nine by nine grid on every one of those is work nobody
## asked for.
static func of(name: StringName, ink: Color = Palette.TEXT) -> Texture2D:
	if not IconArt.ROWS.has(name):
		return null
	var key := "%s:%s" % [name, ink.to_html()]
	if not _made.has(key):
		_made[key] = PixelArt.texture(PixelArt.enlarged(
				PixelArt.from_rows(IconArt.ROWS[name], ink), SCALE))
	return _made[key]


## Hangs the icon called [param name] on [param button], if there is one.
##
## Returns the button, so this can be wrapped around one as it is made.
static func on(button: Button, name: StringName,
		ink: Color = Palette.TEXT) -> Button:
	var icon := of(name, ink)
	if icon == null:
		return button
	button.icon = icon
	# Nearest neighbour, or a two-times enlargement of a nine pixel grid comes
	# out as a smudge. The button does its own scaling and does not ask the
	# texture how it would like to be drawn.
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return button


## Forgets what has been made, for when the palette changes underneath it.
static func forget() -> void:
	_made.clear()
