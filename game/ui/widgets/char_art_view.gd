class_name CharArtView
extends Control
## Draws the original's character art as pixels.
##
## The old game's newspaper is drawn out of terminal cells: a masthead in block
## characters across the top, a headline set in a five-by-seven block-capital
## font, and a picture beside the story. All three are in [CharArt], lifted
## from the files the original itself loads. The port had the words and none of
## the paper.
##
## The cells are drawn rather than typed. Every character the art uses is a
## block or a shade — a full block, a half block on one of four sides, or one
## of three dither patterns — so each one is a rectangle or two and needs no
## font at all. That is what makes this an honest port of the art rather than
## an approximation: the shapes are the original's shapes, at whatever size
## they are given, and they do not depend on the player having a code page 437
## font installed.
##
## The handful of cells that are letters — the price on a masthead, the
## Guardian's "ALWAYS FREE TRUTH IS" — are drawn with the interface's own font,
## because a letter is a letter.

## Which part of each cell the character fills, as a rectangle in cell space.
## Everything the art uses is one of these.
const SHAPES := {
	219: Rect2(0.0, 0.0, 1.0, 1.0),      # full block
	220: Rect2(0.0, 0.5, 1.0, 0.5),      # lower half
	223: Rect2(0.0, 0.0, 1.0, 0.5),      # upper half
	221: Rect2(0.0, 0.0, 0.5, 1.0),      # left half
	222: Rect2(0.5, 0.0, 0.5, 1.0),      # right half
	205: Rect2(0.0, 0.35, 1.0, 0.3),     # the double rule under a masthead
	186: Rect2(0.35, 0.0, 0.3, 1.0),     # and standing up
}

## The dithers, as how much of the cell they cover. The original draws them as
## a stipple; at a few pixels a cell that reads as a tint, which is what a
## stipple is for.
const SHADES := {176: 0.25, 177: 0.5, 178: 0.75}

## The sixteen colours a DOS terminal had, in the order the art numbers them.
## Written without the leading hash, as the palette writes its own.
## The bright half is the same hue lifted, which is what "bold" did.
const DOS := [
	Color("000000"), Color("0000aa"), Color("00aa00"), Color("00aaaa"),
	Color("aa0000"), Color("aa00aa"), Color("aa5500"), Color("aaaaaa"),
	Color("555555"), Color("5555ff"), Color("55ff55"), Color("55ffff"),
	Color("ff5555"), Color("ff55ff"), Color("ffff55"), Color("ffffff"),
]

## How wide a cell is drawn, before the view is asked to be any particular
## size. Two pixels wide to one tall is the shape a terminal cell had, and the
## art is drawn for it: at square cells every masthead is twice as tall as it
## should be.
const CELL := Vector2(6.0, 12.0)

## And how big one block capital is drawn: five cells by seven, at a size that
## fits a thirteen-letter headline across a phone.
const LETTER := Vector2(20.0, 28.0)

var _cells: PackedByteArray = PackedByteArray()
var _wide := 0
## How many of the columns to draw, when the original draws fewer than the
## file holds. The apostrophe is the only one: displaycenterednewsfont() gives
## it four columns where a letter gets six.
var _columns := 0
var _tall := 0
var _ink := Color.WHITE


## Shows picture [param index] out of one of [CharArt]'s sets.
##
## [param tint] recolours the art to one of the palette's own colours instead
## of the terminal's, for the places where sixteen-colour DOS beside a modern
## palette would only look like a mistake.
func show_art(art: Dictionary, index: int, tint: Color = Color.TRANSPARENT) -> void:
	_wide = int(art["wide"])
	_tall = int(art["tall"])
	var all := Marshalls.base64_to_raw(String(art["cells"]))
	var each := _wide * _tall * 4
	var at := index * each
	if at < 0 or at + each > all.size():
		_cells = PackedByteArray()
		queue_redraw()
		return
	_cells = all.slice(at, at + each)
	_columns = _wide
	_ink = tint
	# Height only. A masthead is eighty cells across, and asking for eighty
	# times a cell's width is asking for four hundred and eighty pixels on a
	# four hundred pixel phone — which does not wrap, it drags the whole page
	# out from under itself. Given a width, [method _draw] divides it by the
	# number of cells and draws smaller ones.
	custom_minimum_size = Vector2(0.0, _tall * CELL.y)
	queue_redraw()


## Sets a word in the block capitals, which is what a headline is.
##
## Returns the row of letters, so the caller can put it wherever it wants. The
## original's font holds A to Z and the apostrophe and nothing else, so
## anything else in the word is left as a gap, exactly as a space would be.
## Where the apostrophe sits in the block-capital font, after A to Z, and how
## many of its columns the original draws — four, where a letter gets six.
const APOSTROPHE := 26
const APOSTROPHE_WIDE := 4

static func headline(said: String, tint: Color = Color.TRANSPARENT) -> Control:
	# A flow, so a headline too wide for the room it has goes onto a second
	# line rather than off the side of the page.
	var row := Atoms.flow(0)
	for index in said.length():
		var letter := said[index].to_upper()
		var at := _letter_at(letter)
		if at == -1:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(LETTER.x * 0.4, 0.0)
			row.add_child(gap)
			continue
		var view := CharArtView.new()
		view.show_art(CharArt.CAPITALS, at, tint)
		# A letter is asked for at a fixed size, unlike a masthead: it is five
		# cells wide and has to keep its shape, and a flow hands a child with no
		# width of its own no width at all.
		view.custom_minimum_size = LETTER
		if at == APOSTROPHE:
			view.narrow_to(APOSTROPHE_WIDE)
			view.custom_minimum_size.x = LETTER.x \
					* float(APOSTROPHE_WIDE) / 5.0
		row.add_child(view)
	return row


## Where a letter sits in the block-capital font: A to Z, then the apostrophe.
static func _letter_at(letter: String) -> int:
	if letter == "'":
		return APOSTROPHE
	var code := letter.unicode_at(0)
	if code < 65 or code > 90:
		return -1
	return code - 65


## Draws only the first [param columns] columns of the art.
func narrow_to(columns: int) -> void:
	_columns = columns
	queue_redraw()


func _draw() -> void:
	if _cells.is_empty():
		return
	var across := maxi(mini(_columns, _wide), 1)
	var cell := Vector2(size.x / float(across), size.y / float(_tall)) \
			if size.x > 0.0 and size.y > 0.0 else CELL
	for x in mini(_columns, _wide):
		for y in _tall:
			_draw_cell(x, y, cell)


func _draw_cell(x: int, y: int, cell: Vector2) -> void:
	var at := (x * _tall + y) * 4
	var code := _cells[at]
	var where := Rect2(Vector2(x, y) * cell, cell)
	var back := _colour(_cells[at + 2], false)
	if back.a > 0.0:
		draw_rect(where, back)
	var ink := _colour(_cells[at + 1], _cells[at + 3] != 0)
	if SHADES.has(code):
		draw_rect(where, Color(ink, float(SHADES[code])))
		return
	if SHAPES.has(code):
		var part: Rect2 = SHAPES[code]
		draw_rect(Rect2(where.position + part.position * cell,
				part.size * cell), ink)
		return
	# Whatever is left is a letter or a punctuation mark, and is drawn as one.
	if code <= 32 or code >= 127:
		return
	var font := get_theme_default_font()
	if font == null:
		return
	draw_char(font, where.position + Vector2(0.0, cell.y * 0.85),
			char(code), int(cell.y), ink)


## One of the terminal's colours, or the tint everything is being drawn in.
func _colour(index: int, bold: bool) -> Color:
	var at := (index + 8) if bold and index < 8 else index
	var was: Color = DOS[at % DOS.size()]
	if _ink.a <= 0.0:
		return was
	# Tinted: the art keeps its shape and gives up its palette, and how bright
	# a cell was decides how much of the tint it gets. That has to be by
	# brightness rather than by "is it black", because a masthead's letters are
	# not drawn with characters at all — they are spaces with a background
	# colour, so throwing the backgrounds away leaves a bar where the paper's
	# name should be.
	var lit := was.get_luminance()
	if lit <= 0.01:
		return Color(_ink, 0.0)
	return Color(_ink, clampf(lit + 0.15, 0.0, 1.0))
