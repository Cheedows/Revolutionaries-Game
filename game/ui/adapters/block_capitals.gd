class_name BlockCapitals
extends RefCounted
## Sets a line of text in the original's block-capital font.
##
## The font is twenty-seven pictures in [CharArt] — A to Z and the apostrophe,
## five cells by seven — and it is what every headline in the game is set in.
## displaycenterednewsfont() in src/news/news.cpp draws it a letter at a time,
## giving a letter six columns and the apostrophe four, and three columns to
## anything it has no letter for.
##
## Here the line becomes one picture rather than a row of controls, because a
## picture can be put anywhere and a row of controls has to be told how wide
## every one of its children is.

## Where the apostrophe sits, after A to Z, and how many of its columns the
## original draws.
const APOSTROPHE := 26
const APOSTROPHE_WIDE := 4

## How many pixels stand between one letter and the next, and how wide a space
## is: the original gives a letter six columns for five of art, and gives
## anything it cannot set three.
const KERN := 1
const SPACE := PixelArt.CELL.x * 3


## [param said] set in the block capitals, as one image, or null if none of it
## could be set.
static func of(said: String, tint: Color = Color.TRANSPARENT) -> Image:
	var letters: Array[Image] = []
	for index in said.length():
		var at := index_of(said[index].to_upper())
		if at == -1:
			letters.append(_gap())
			continue
		letters.append(PixelArt.from_cells(CharArt.CAPITALS, at, tint,
				APOSTROPHE_WIDE if at == APOSTROPHE else 0))
	return PixelArt.run_together(letters, KERN)


## Where a letter sits in the font, or -1 for one it has no picture for.
static func index_of(letter: String) -> int:
	if letter == "'":
		return APOSTROPHE
	var code := letter.unicode_at(0)
	if code < 65 or code > 90:
		return -1
	return code - 65


## The space between words, which the original leaves blank.
static func _gap() -> Image:
	var gap := Image.create_empty(SPACE, PixelArt.CELL.y, false,
			Image.FORMAT_RGBA8)
	gap.fill(Color.TRANSPARENT)
	return gap
