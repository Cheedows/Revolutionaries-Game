class_name PixelArt
extends RefCounted
## Turns character grids into pictures.
##
## Two kinds of grid go in and an [Image] comes out of both:
##
##   [b]Cells[/b] — the original's own art, out of [CharArt]. Four bytes to a
##   cell: a code page 437 character and the two colours it was drawn in. Each
##   cell becomes a small block of pixels, because every character the art uses
##   is a rectangle — a full block, a half block on one of four sides, or one of
##   three dithers — so the shapes come across exactly rather than depending on
##   the player having a terminal font.
##
##   [b]Rows[/b] — art written here, as lines of text: "#" is ink, "." is
##   nothing, "+" is half. One character is one pixel. This is how the icons are
##   drawn, and it is the whole of the format: a picture you can read in the
##   source and edit in a text editor.
##
## An image, not a control that paints itself. That was the first shape of this
## and it could only ever be a panel on a page; a picture can be a button's
## icon, a texture, a window's icon, anything at all. [PixelArtRect] is the
## thin wrapper that puts one on screen.

## How many pixels a terminal cell becomes.
##
## Four by eight: wide enough for a left or right half block and a dither to
## come out even, tall enough for the top and bottom halves, and the two-to-one
## shape a terminal cell actually had — at square cells every masthead comes
## out twice as tall as it should be.
const CELL := Vector2i(4, 8)

## Which part of a cell each character fills, as a fraction of it.
const SHAPES := {
	219: Rect2(0.0, 0.0, 1.0, 1.0),      # full block
	220: Rect2(0.0, 0.5, 1.0, 0.5),      # lower half
	223: Rect2(0.0, 0.0, 1.0, 0.5),      # upper half
	221: Rect2(0.0, 0.0, 0.5, 1.0),      # left half
	222: Rect2(0.5, 0.0, 0.5, 1.0),      # right half
	205: Rect2(0.0, 0.25, 1.0, 0.5),     # the double rule under a masthead
	186: Rect2(0.25, 0.0, 0.5, 1.0),     # and the same standing up
}

## The three dithers, as how much of the cell they cover. The original stipples
## them; at four pixels by eight a stipple reads as a tint, which is what a
## stipple is for.
const SHADES := {176: 0.25, 177: 0.5, 178: 0.75}

## The sixteen colours a terminal had, in the order the art numbers them.
## Written without the leading hash, as the palette writes its own.
const DOS := [
	Color("000000"), Color("0000aa"), Color("00aa00"), Color("00aaaa"),
	Color("aa0000"), Color("aa00aa"), Color("aa5500"), Color("aaaaaa"),
	Color("555555"), Color("5555ff"), Color("55ff55"), Color("55ffff"),
	Color("ff5555"), Color("ff55ff"), Color("ffff55"), Color("ffffff"),
]

## What each character means in a written grid.
const INK := "#"
const HALF := "+"
const NOTHING := "."


## Picture [param index] out of one of [CharArt]'s sets, as an image.
##
## [param tint] recolours it: every cell keeps its shape and gives up its
## colour, and how bright it was decides how much of the tint it gets. That has
## to go by brightness rather than by "is it black", because the mastheads and
## the block capitals are not drawn with characters at all — they are spaces on
## a coloured ground, so throwing the grounds away leaves a bar where the
## paper's name should be.
##
## [param columns] draws only the first few, for the one letter the original
## draws narrower than the rest.
static func from_cells(art: Dictionary, index: int,
		tint: Color = Color.TRANSPARENT, columns: int = 0) -> Image:
	var wide := int(art["wide"])
	var tall := int(art["tall"])
	var cells := Marshalls.base64_to_raw(String(art["cells"]))
	var each := wide * tall * 4
	var at := index * each
	if index < 0 or at + each > cells.size():
		return null
	var across := wide if columns <= 0 else mini(columns, wide)
	var image := Image.create_empty(across * CELL.x, tall * CELL.y, false,
			Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for x in across:
		for y in tall:
			_cell(image, cells, at + (x * tall + y) * 4,
					Vector2i(x, y) * CELL, tint)
	return image


## A written grid as an image, one character to a pixel.
##
## Every row is padded out to the longest, so a grid with a short line in it is
## still a rectangle rather than a crash.
static func from_rows(rows: Array, ink: Color) -> Image:
	var wide := 0
	for row: String in rows:
		wide = maxi(wide, row.length())
	if wide == 0 or rows.is_empty():
		return null
	var image := Image.create_empty(wide, rows.size(), false,
			Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			match row[x]:
				INK:
					image.set_pixel(x, y, ink)
				HALF:
					image.set_pixel(x, y, Color(ink, 0.45))
	return image


## Several images side by side, with [param gap] pixels between them.
##
## What a headline is: the original sets one out of its block capitals a letter
## at a time, and one picture of the whole line is easier to place than a row
## of controls that each have to be told how wide to be.
static func run_together(images: Array, gap: int = 0) -> Image:
	var wide := 0
	var tall := 0
	for image: Image in images:
		if image == null:
			continue
		wide += image.get_width() + gap
		tall = maxi(tall, image.get_height())
	if wide <= 0 or tall <= 0:
		return null
	var all := Image.create_empty(wide - gap, tall, false, Image.FORMAT_RGBA8)
	all.fill(Color.TRANSPARENT)
	var at := 0
	for image: Image in images:
		if image == null:
			continue
		all.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()),
				Vector2i(at, 0))
		at += image.get_width() + gap
	return all


## The same picture at [param times] its size, which is the only honest way to
## make pixel art bigger.
static func enlarged(image: Image, times: int) -> Image:
	if image == null or times <= 1:
		return image
	var bigger := image.duplicate() as Image
	bigger.resize(image.get_width() * times, image.get_height() * times,
			Image.INTERPOLATE_NEAREST)
	return bigger


## An image as something that can be hung on a control.
static func texture(image: Image) -> ImageTexture:
	if image == null:
		return null
	return ImageTexture.create_from_image(image)


static func _cell(image: Image, cells: PackedByteArray, offset: int,
		where: Vector2i, tint: Color) -> void:
	var code := cells[offset]
	var back := _colour(cells[offset + 2], false, tint)
	if back.a > 0.0:
		_fill(image, where, Rect2(0.0, 0.0, 1.0, 1.0), back)
	var ink := _colour(cells[offset + 1], cells[offset + 3] != 0, tint)
	if SHADES.has(code):
		_dither(image, where, Color(ink, float(SHADES[code])))
	elif SHAPES.has(code):
		_fill(image, where, SHAPES[code], ink)


## Fills part of a cell.
static func _fill(image: Image, where: Vector2i, part: Rect2,
		colour: Color) -> void:
	var from := Vector2i(part.position * Vector2(CELL))
	var size := Vector2i(part.size * Vector2(CELL))
	for x in size.x:
		for y in size.y:
			image.set_pixel(where.x + from.x + x, where.y + from.y + y, colour)


## A dither, drawn as a checker rather than as a flat wash: a quarter, a half
## and three quarters of the pixels, which is what the original's three
## stipples are.
static func _dither(image: Image, where: Vector2i, colour: Color) -> void:
	var every := 4 - int(colour.a * 4.0)
	var flat := Color(colour, 1.0)
	var drawn := 0
	for y in CELL.y:
		for x in CELL.x:
			drawn += 1
			if every <= 1 or drawn % every == 0:
				image.set_pixel(where.x + x, where.y + y, flat)


## One of the terminal's colours, or how much of the tint it becomes.
static func _colour(index: int, bold: bool, tint: Color) -> Color:
	var at := (index + 8) if bold and index < 8 else index
	var was: Color = DOS[at % DOS.size()]
	if tint.a <= 0.0:
		return was
	var lit := was.get_luminance()
	if lit <= 0.01:
		return Color(tint, 0.0)
	return Color(tint, clampf(lit + 0.15, 0.0, 1.0))
