class_name LogView
extends PanelContainer
## The running account of what has happened.
##
## Replaces the original's message area, which was the same 24-line terminal the
## rest of the game drew into. Here it is its own thing that keeps a history and
## scrolls.

## Lines kept before the oldest are dropped.
const HISTORY := 400

## How tall the log is when it is one thing in a column rather than a pane of
## its own.
##
## The log is the exception to a phone having one scroller. Everything else on
## the page is a list of a known length — the squad has six members, the
## country has twenty-two issues — so letting those grow and scrolling the page
## works. The log grows without limit, and a page that gets taller every day
## you play is a page you cannot get to the bottom of: the buttons that run the
## game end up further down every morning. So it keeps its own height and its
## own scroller, and the page stops growing.
const NARROW_HEIGHT := 200

## How close to the bottom still counts as being at the bottom, in pixels.
## About a line, so a log resting a hair off the end still follows the tail.
const AT_THE_END := 24

var _lines: VBoxContainer
var _scroll: ScrollContainer


func _ready() -> void:
	_build()


## Builds the scroller and the column of lines.
##
## Called from _ready(), but also from anything that writes, because a caller
## may reasonably fill the log before the widget reaches the tree — and a view
## that silently drops what it was given is worse than one that builds early.
func _build() -> void:
	if _lines != null:
		return
	add_theme_stylebox_override("panel", UiTheme.panel())
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Keeps Metrics.unscroll() off it: see NARROW_HEIGHT for why this one holds
	# its own height and does its own scrolling even on a phone.
	_scroll.set_meta(&"own_scroller", true)
	add_child(_scroll)

	_lines = VBoxContainer.new()
	_lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lines.add_theme_constant_override(&"separation", 0)
	_scroll.add_child(_lines)


## Builds the widget without writing to it, so a screen can lay it out before
## anything has happened.
func refresh(_state: GameState) -> void:
	_build()


## Adds one line.
func append(text: String, colour: Color = Palette.TEXT) -> void:
	if text.is_empty():
		return
	_build()
	# Asked before the line is added, because adding it is what moves the end.
	var follow := _at_the_end()
	_lines.add_child(Atoms.wrapped(Atoms.tinted(text, colour)))
	await _settle(follow)


## Whether the log is showing its newest line.
##
## What decides whether the next line drags the view down with it. A log that
## always jumps to the tail cannot be read: the player scrolls up to find what
## happened on the second of March, a day goes by, and they are back at the
## bottom. A log that never jumps has to be scrolled by hand every morning to
## see what just happened. So it follows the tail while the player is at the
## tail, and holds still while they are reading.
func _at_the_end() -> bool:
	if not is_inside_tree():
		return true
	var bar := _scroll.get_v_scroll_bar()
	if bar.max_value <= bar.page:
		# Nothing to scroll, so the end is where we are.
		return true
	return bar.value + bar.page >= bar.max_value - AT_THE_END


## Drops the oldest lines, and puts the view back on the newest one if that is
## where it was.
##
## Only once the widget is on screen: there is nothing to scroll before that,
## and the line has no height until the tree has laid it out, which is what the
## frame is waited for.
func _settle(follow: bool) -> void:
	while _lines.get_child_count() > HISTORY:
		var oldest := _lines.get_child(0)
		_lines.remove_child(oldest)
		oldest.queue_free()
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if follow:
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


## Takes a fixed height when it is one thing in a column, and fills its pane
## when it has one.
func compact(on: bool) -> void:
	_build()
	custom_minimum_size.y = NARROW_HEIGHT if on else 0.0


## Adds a heading, for the start of a day or a report.
func append_heading(text: String) -> void:
	_build()
	var follow := _at_the_end()
	_lines.add_child(Atoms.wrapped(Atoms.heading(text)))
	await _settle(follow)


func clear() -> void:
	_build()
	for child in _lines.get_children():
		_lines.remove_child(child)
		child.queue_free()
