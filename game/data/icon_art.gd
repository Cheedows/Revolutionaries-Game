class_name IconArt
extends RefCounted
## The icons, drawn as text.
##
## "#" is ink, "+" is half ink, "." is nothing, and one character is one pixel.
## Nine by nine: big enough for a shape that reads at a glance, small enough
## that every pixel has to earn its place. [PixelArt] turns a grid into an
## image and [Icons] hands it out as a texture.
##
## Written here rather than drawn in a paint program because this is a game
## whose art is characters on a grid, and because a picture that can be read in
## the source is a picture the next person can change. Preview them with
## tools/shots/icons.gd, which draws every one of them at once — a grid of
## hashes does not look like anything until it is rasterised.

## How wide and tall every grid is. They are all square and all the same, so a
## row of them lines up without anybody measuring anything.
const GRID := 9

## Every icon, by the name a caller asks for it by.
const ROWS := {
	# The country: a page with lines on it.
	&"agenda": [
		"#########",
		"#.......#",
		"#.##.##.#",
		"#.......#",
		"#.#####.#",
		"#.......#",
		"#.###...#",
		"#.......#",
		"#########",
	],
	# The country itself: a flag on a pole.
	&"country": [
		"##.......",
		"#####....",
		"#######..",
		"#####....",
		"##.......",
		"##.......",
		"##.......",
		"##.......",
		"##.......",
	],
	# The safehouse: a roof over a door.
	&"house": [
		"....#....",
		"...###...",
		"..#####..",
		".#######.",
		"#########",
		"#.......#",
		"#..###..#",
		"#..#.#..#",
		"#..###..#",
	],
	# The paper: a masthead over two columns.
	&"paper": [
		"#########",
		"#.#####.#",
		"#.......#",
		"#.##.##.#",
		"#.##.##.#",
		"#.##.##.#",
		"#.##.##.#",
		"#.......#",
		"#########",
	],
	# What the squad owns: a crate.
	&"assets": [
		".#######.",
		"#########",
		"#.##.##.#",
		"#.##.##.#",
		"#########",
		"#.##.##.#",
		"#.##.##.#",
		"#########",
		".#######.",
	],
	# The courts: a pair of scales.
	&"justice": [
		"....#....",
		"#########",
		"#...#...#",
		"#...#...#",
		"###.#.###",
		".#..#..#.",
		"....#....",
		"..#####..",
		".#######.",
	],
	# The squad: two of them, shoulder to shoulder.
	&"squad": [
		".##...##.",
		".##...##.",
		".........",
		"####.####",
		"####.####",
		"####.####",
		".##...##.",
		".##...##.",
		".##...##.",
	],
	# A sleeper: an eye, open.
	&"sleepers": [
		".........",
		"..#####..",
		".#.....#.",
		"#..###..#",
		"#.#####.#",
		"#..###..#",
		".#.....#.",
		"..#####..",
		".........",
	],
	# Saving: a disk with a shutter.
	&"save": [
		"#########",
		"#.#####.#",
		"#.#...#.#",
		"#.#...#.#",
		"#.......#",
		"#.#####.#",
		"#.#####.#",
		"#.#####.#",
		"#########",
	],
	# Everything else: three of them.
	&"more": [
		".........",
		".........",
		".........",
		".........",
		"##.##.##.",
		"##.##.##.",
		".........",
		".........",
		".........",
	],
	# A day passing: a clock at a quarter to.
	&"wait": [
		"..#####..",
		".#.....#.",
		"#...#...#",
		"#...#...#",
		"#.###...#",
		"#.......#",
		"#.......#",
		".#.....#.",
		"..#####..",
	],
	# Days running by: two chevrons forward.
	&"run": [
		"#....#...",
		"##...##..",
		"###..###.",
		"####.####",
		"#####.###",
		"####.####",
		"###..###.",
		"##...##..",
		"#....#...",
	],
	# Stopping: a square.
	&"stop": [
		".........",
		".#######.",
		".#######.",
		".#######.",
		".#######.",
		".#######.",
		".#######.",
		".#######.",
		".........",
	],
	# The way out.
	&"close": [
		"##.....##",
		"###...###",
		".###.###.",
		"..#####..",
		"...###...",
		"..#####..",
		".###.###.",
		"###...###",
		"##.....##",
	],
	# The way back.
	&"back": [
		"...#.....",
		"..##.....",
		".###.....",
		"########.",
		"#########",
		"########.",
		".###.....",
		"..##.....",
		"...#.....",
	],
	# Reading somebody's record: a glass held over it.
	&"look": [
		"..####...",
		".#....#..",
		"#......#.",
		"#......#.",
		"#......#.",
		".#....#..",
		"..####.#.",
		".......##",
		"........#",
	],
	# Choosing this one.
	&"choose": [
		".........",
		"..#......",
		"..##.....",
		"..###....",
		"..####...",
		"..###....",
		"..##.....",
		"..#......",
		".........",
	],
	# Handing something over.
	&"give": [
		".........",
		"....#....",
		"....##...",
		"#########",
		"#########",
		"#########",
		"....##...",
		"....#....",
		".........",
	],
	# Putting something down.
	&"drop": [
		"...###...",
		"...###...",
		"...###...",
		"...###...",
		"#########",
		".#######.",
		"..#####..",
		"...###...",
		"....#....",
	],
	# Moving somebody up.
	&"promote": [
		"....#....",
		"...###...",
		"..#####..",
		".#######.",
		"#########",
		"...###...",
		"...###...",
		"...###...",
		"...###...",
	],
	# Taking somebody off the list.
	&"remove": [
		".........",
		".........",
		".........",
		".........",
		"#########",
		"#########",
		".........",
		".........",
		".........",
	],
	# The one thing that cannot be undone.
	&"kill": [
		".#######.",
		"#########",
		"##.###.##",
		"##.###.##",
		"#########",
		"####.####",
		"#########",
		".#.#.#.#.",
		".#######.",
	],
	# Going somewhere else: a car, with windows and wheels.
	&"travel": [
		".........",
		"..#####..",
		".#.....#.",
		"#########",
		"#########",
		"#########",
		".##...##.",
		".##...##.",
		".........",
	],
	# Money in, money out.
	&"money": [
		"....#....",
		"..#####..",
		".#..#..#.",
		".#..#....",
		"..#####..",
		"....#..#.",
		".#..#..#.",
		"..#####..",
		"....#....",
	],
	# Somebody being worked on.
	&"surgery": [
		"....#....",
		"....#....",
		"....#....",
		"#########",
		"#########",
		"....#....",
		"....#....",
		"....#....",
		"....#....",
	],
	# Building something into the house: courses of brick.
	&"build": [
		".........",
		"#########",
		"#..#..#..",
		"#########",
		"..#..#..#",
		"#########",
		"#..#..#..",
		"#########",
		".........",
	],
}
