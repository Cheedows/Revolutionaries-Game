extends TestCase
## The log holds its height, and follows the tail without stealing the view.
##
## Both of these were reported as the game being unplayable, and neither showed
## up in any measurement: the log grew without limit inside a page that scrolls
## as one, so every day of play pushed the buttons that run the game further
## down, and there was no way back to them.
##
## Everything here lays the widget out inside a real window and waits for
## frames. A first version of this file added it to a window without anchoring
## it, so it was laid out one pixel wide, every line wrapped to one letter, and
## two hundred lines came to 136,940 pixels of content. Every assertion passed,
## including against the broken code. A log outside a working layout has no
## height and nothing to scroll, and measuring it says nothing at all.

## More lines than fit in LogView.NARROW_HEIGHT, by a lot.
const PLENTY := 60


func test_the_log_holds_its_height_on_a_phone() -> void:
	var held := await _a_log(true)
	var log_view: LogView = held["log"]

	var empty := log_view.get_combined_minimum_size().y
	for line in PLENTY:
		log_view.append("Something happened on day %d of it." % line)
	await _settled()

	equal(log_view.get_combined_minimum_size().y, empty,
			"sixty lines did not make the log ask for more room")
	equal(empty, float(LogView.NARROW_HEIGHT),
			"and what it asks for is the height it was given")
	_drop(held)


## The rule that makes the height mean anything.
##
## A phone stops every widget scrolling and lets it grow instead, so that the
## page can scroll as one thing — [method Metrics.unscroll]. A disabled
## [ScrollContainer] reports its content's height as its own, so the log came
## out as tall as the whole history. This is the exemption that keeps it from
## happening, and it is the part that was actually broken.
func test_a_phone_leaves_the_logs_own_scroller_alone() -> void:
	var held := await _a_log(true)
	var log_view: LogView = held["log"]
	for line in PLENTY:
		log_view.append("Day %d." % line)
	await _settled()

	Metrics.unscroll(log_view, true)
	var scroll: ScrollContainer = log_view.get("_scroll")
	equal(scroll.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_AUTO,
			"the log keeps scrolling when everything else stops")
	equal(log_view.get_combined_minimum_size().y,
			float(LogView.NARROW_HEIGHT),
			"and so it keeps its height instead of growing to its history")
	_drop(held)


func test_a_pane_of_its_own_grows_to_fill_it() -> void:
	# On a desk the log is a pane with a height of its own already, so it asks
	# for no particular height and fills what it is given.
	var held := await _a_log(false)
	var log_view: LogView = held["log"]
	equal(log_view.custom_minimum_size.y, 0.0,
			"a log in its own pane asks for no particular height")
	_drop(held)


func test_it_follows_the_newest_line() -> void:
	var held := await _a_log(true)
	var log_view: LogView = held["log"]
	for line in PLENTY:
		log_view.append("Day %d of it, and this is what happened." % line)
	await _settled()

	var scroll: ScrollContainer = log_view.get("_scroll")
	var bar := scroll.get_v_scroll_bar()
	check(bar.max_value > bar.page, "there is more log than fits, %d of %d"
			% [int(bar.page), int(bar.max_value)])
	check(bar.value + bar.page >= bar.max_value - LogView.AT_THE_END,
			"and the newest line is the one showing, at %d of %d"
			% [int(bar.value), int(bar.max_value)])
	_drop(held)


func test_it_holds_still_while_you_are_reading_further_up() -> void:
	var held := await _a_log(true)
	var log_view: LogView = held["log"]
	for line in PLENTY:
		log_view.append("Day %d of it, and this is what happened." % line)
	await _settled()

	var scroll: ScrollContainer = log_view.get("_scroll")
	# The player drags back up to see what happened in January.
	scroll.scroll_vertical = 0
	await _settled()

	log_view.append("And then something else happened.")
	await _settled()
	equal(scroll.scroll_vertical, 0,
			"a new line did not drag the view off what was being read")

	# Back at the end, it follows again.
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await _settled()
	log_view.append("One more thing happened, later on.")
	await _settled()
	var bar := scroll.get_v_scroll_bar()
	check(bar.value + bar.page >= bar.max_value - LogView.AT_THE_END,
			"and back at the end it follows the tail again, at %d of %d"
			% [int(bar.value), int(bar.max_value)])
	_drop(held)


## A log laid out for real, filling a window of a phone's width.
func _a_log(narrow: bool) -> Dictionary:
	var window := Window.new()
	window.size = Vector2i(400, 800) if narrow else Vector2i(1280, 800)
	(Engine.get_main_loop() as SceneTree).root.add_child(window)
	var log_view := LogView.new()
	window.add_child(log_view)
	log_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	log_view.compact(narrow)
	await _settled()
	return {"window": window, "log": log_view}


func _settled() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for frame in 6:
		await tree.process_frame


func _drop(held: Dictionary) -> void:
	var window: Window = held["window"]
	(Engine.get_main_loop() as SceneTree).root.remove_child(window)
	window.queue_free()
