extends TestCase
## The newspaper's own art: the masthead, the block capitals, the pictures.
##
## The original draws its paper out of terminal cells and ships the cells in
## art/*.cpc. The port had the words and none of the paper. These check that
## every picture came across whole and that the view draws them.

## What the extractor read out of each file.
const SETS := [
	[CharArt.CAPITALS, "the block capitals", 27, 5, 7],
	[CharArt.MASTHEADS, "the mastheads", 6, 80, 5],
	[CharArt.PICTURES, "the story pictures", 13, 78, 18],
]


func test_every_picture_came_across_whole() -> void:
	for entry: Array in SETS:
		var art: Dictionary = entry[0]
		var what: String = entry[1]
		equal(int(art["count"]), int(entry[2]), "%s: how many" % what)
		equal(int(art["wide"]), int(entry[3]), "%s: how wide" % what)
		equal(int(art["tall"]), int(entry[4]), "%s: how tall" % what)
		var cells := Marshalls.base64_to_raw(String(art["cells"]))
		equal(cells.size(), int(entry[2]) * int(entry[3]) * int(entry[4]) * 4,
				"%s: four bytes a cell, all of them" % what)


func test_the_block_capitals_are_all_there() -> void:
	# A to Z and the apostrophe, and every one of them has ink in it: a letter
	# that came across as an empty five-by-seven would draw as a space and
	# nothing would say so.
	#
	# What counts as ink differs between them. A to Z are drawn the way the
	# mastheads are, as spaces on a coloured ground, so their shape is in the
	# background colour; the apostrophe is drawn the other way round, as block
	# characters on one ground. So the check is neither of those: a letter has
	# ink if any of its cells differs from the first one at all.
	var art: Dictionary = CharArt.CAPITALS
	var cells := Marshalls.base64_to_raw(String(art["cells"]))
	var each := int(art["wide"]) * int(art["tall"]) * 4
	for letter in int(art["count"]):
		var marked := 0
		var first := PackedByteArray()
		for cell in int(art["wide"]) * int(art["tall"]):
			var at := letter * each + cell * 4
			var this := cells.slice(at, at + 4)
			if first.is_empty():
				first = this
			elif this != first:
				marked += 1
		if marked == 0:
			fail("letter %d of the headline font is blank" % letter)
			return


func test_a_headline_is_set_in_them() -> void:
	var set_in := CharArtView.headline("LET'S FRY", Palette.TEXT)
	# Eight letters and an apostrophe are drawn; the space is a gap.
	var drawn := 0
	for child in set_in.get_children():
		if child is CharArtView:
			drawn += 1
	# Seven letters and an apostrophe. The space between the words is a gap,
	# not a letter, which is what the original does with it too.
	equal(drawn, 8, "every letter of the headline is set, got %d" % drawn)
	set_in.free()


func test_a_masthead_asks_for_no_width_of_its_own() -> void:
	# Eighty cells at their natural width is wider than a phone, and a control
	# that insists on that drags the whole page out from under itself.
	var view := CharArtView.new()
	view.show_art(CharArt.MASTHEADS, 0)
	equal(view.custom_minimum_size.x, 0.0, "it fits whatever it is given")
	check(view.custom_minimum_size.y > 0.0, "and stands its own height")
	view.free()


func test_asking_for_a_picture_that_is_not_there_draws_nothing() -> void:
	var view := CharArtView.new()
	view.show_art(CharArt.PICTURES, 99)
	equal(view.custom_minimum_size.y, 0.0, "and does not crash asking")
	view.free()
