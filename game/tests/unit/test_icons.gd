extends TestCase
## The pictures on the buttons.
##
## They are written as text and rasterised, so the things that can go wrong are
## a grid that is not the shape it claims, an icon nothing asks for, and a name
## asked for that was never drawn. All three are cheap to check and none of
## them is visible until somebody looks at a screen.


func test_every_grid_is_square_and_the_right_size() -> void:
	for name: StringName in IconArt.ROWS:
		var rows: Array = IconArt.ROWS[name]
		if rows.size() != IconArt.GRID:
			fail("%s is %d rows, not %d" % [name, rows.size(), IconArt.GRID])
			return
		for row: String in rows:
			if row.length() != IconArt.GRID:
				fail("%s has a row %d wide, not %d"
						% [name, row.length(), IconArt.GRID])
				return
			for index in row.length():
				if not [PixelArt.INK, PixelArt.HALF,
						PixelArt.NOTHING].has(row[index]):
					fail("%s uses %s, which means nothing" % [name, row[index]])
					return


func test_every_icon_has_something_in_it_and_room_around_it() -> void:
	# A grid that is all ink is a square, and a grid that is all dots is
	# nothing. Both are mistakes that draw perfectly well.
	for name: StringName in IconArt.ROWS:
		var inked := 0
		for row: String in IconArt.ROWS[name]:
			inked += row.count(PixelArt.INK) + row.count(PixelArt.HALF)
		var cells := IconArt.GRID * IconArt.GRID
		if inked == 0:
			fail("%s is empty" % name)
			return
		if inked == cells:
			fail("%s is a solid block" % name)
			return


func test_an_icon_becomes_a_texture_of_the_right_size() -> void:
	var drawn := Icons.of(&"house")
	check(drawn != null, "the house has a picture")
	if drawn == null:
		return
	var wanted := IconArt.GRID * Icons.SCALE
	equal(drawn.get_width(), wanted, "enlarged by whole numbers")
	equal(drawn.get_height(), wanted, "in both directions")


func test_asking_for_an_icon_nobody_drew_says_so() -> void:
	equal(Icons.of(&"there_is_no_such_icon"), null, "rather than crashing")
	var button := Atoms.button("Press me")
	Icons.on(button, &"there_is_no_such_icon")
	equal(button.icon, null, "and the button goes without one")
	button.free()


func test_the_same_icon_is_only_made_once() -> void:
	Icons.forget()
	var first := Icons.of(&"close")
	var second := Icons.of(&"close")
	check(first == second, "asking twice gives the same texture back")


func test_every_icon_is_used_somewhere() -> void:
	# An icon nothing asks for is dead weight, and this is a directory of
	# pictures that is only worth having if it stays honest.
	var asked := {}
	for where in ["res://ui", "res://data"]:
		_gather(where, asked)
	var unused: Array[String] = []
	for name: StringName in IconArt.ROWS:
		if not asked.has(name):
			unused.append(String(name))
	unused.sort()
	check(unused.is_empty(), "nothing asks for: %s" % ", ".join(unused))


## Every &"name" that appears anywhere under [param where].
func _gather(where: String, found: Dictionary) -> void:
	for file in DirAccess.get_files_at(where):
		if not file.ends_with(".gd"):
			continue
		var text := FileAccess.get_file_as_string("%s/%s" % [where, file])
		if text.is_empty():
			continue
		for name: StringName in IconArt.ROWS:
			# Where the icon is named at the point it is hung on something,
			# rather than where the grid itself is written.
			if file == "icon_art.gd":
				continue
			if text.contains('&"%s"' % name):
				found[name] = true
	for inner in DirAccess.get_directories_at(where):
		_gather("%s/%s" % [where, inner], found)
