class_name NewspaperPanel
extends PanelContainer
## The morning's paper.
##
## The original draws it as a page of a newspaper with a block-letter headline,
## columns of story and advertisements down the sides. This lays out the same
## paper as text: the headline over each story, the story, the padding it was
## printed with, and the advertisements around it.

## Emitted when the panel should close.
signal closed

## What the padding is drawn as, since it is only tildes in the original.
const FILLER_MARK := "~"

var _body: VBoxContainer
var _head: PanelHeader


func _ready() -> void:
	_build()


## Shows the paper [param events] describe, out of [param state].
func show_paper(state: GameState, events: Array[Event]) -> void:
	_build()
	visible = true
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()

	var printed := 0
	for event: Event in events:
		match event.type:
			Event.HEADLINE_RUN:
				_headline(state, event)
				printed += 1
			Event.NEWS_PUBLISHED:
				_story(state, event)
				printed += 1
			Event.NEWS_SEGMENT:
				_segment(event)
				printed += 1
	# The original names the paper "the monthly Liberal Guardian newspaper";
	# a phone has room for the paper's name and no more.
	_head.set_title("Liberal Guardian")
	if printed == 0:
		_line("Unfortunately, nobody seems interested.", Palette.TEXT_FAINT)


func _headline(state: GameState, event: Event) -> void:
	var lines := HeadlineText.lines(state, event.data.get("headline", &""))
	for line: String in lines:
		_line(line, Palette.ACCENT)
	var major: Dictionary = event.data.get("major", {})
	if major.is_empty():
		return
	if String(major.get("shape", &"")) == "story":
		var view: StringName = event.data.get("view", &"")
		# Which side the story went to is the event's, not the page's: reading
		# it off the page defaulted every story to the Liberal version, and a
		# Conservative one then came out with the wrong slots entirely.
		_line(MajorEventText.describe(state, view,
				bool(event.data.get("positive", true)),
				major.get("slots", {})).replace("&r", "\n"), Palette.TEXT)
		return
	var caption := MajorEventPageText.caption(state,
			major.get("headline", &""), major)
	var picture := MajorEventPageText.picture(major.get("headline", &""))
	if picture != &"":
		_line("[%s]" % String(picture).replace("_", " "),
				Palette.TEXT_FAINT)
	if caption != "":
		_line(caption, Palette.TEXT)


func _story(state: GameState, event: Event) -> void:
	var kind := String(event.data.get("story", &"")).replace("_", " ")
	_line("Page %d — %s" % [int(event.data.get("page", 0)), kind],
			Palette.TEXT_DIM)
	var slogan := String(event.data.get("slogan", &""))
	if slogan != "" and state.slogan != "":
		_line("The slogan, \"%s\" was found painted on the walls."
				% state.slogan, Palette.TEXT)
	var padding: Dictionary = event.data.get("filler", {})
	if not padding.is_empty():
		_line(_filler(padding), Palette.TEXT_FAINT)
	for advertisement: Dictionary in event.data.get("advertisements", []):
		_line("  [%s]" % " / ".join(AdText.lines(advertisement)),
				Palette.TEXT_FAINT)


func _segment(event: Event) -> void:
	_line("Cable News", Palette.ACCENT)
	var card := BroadcastText.title_card(event.data)
	if card != "":
		_line(card, Palette.TEXT_DIM)
	for line: String in BroadcastText.lines(event.data):
		_line(line, Palette.TEXT)
	for who: Dictionary in BroadcastText.cast(event.data):
		_line("  %s, %s" % [who["name"], who["place"]], Palette.TEXT_FAINT)


## The grey block the original pads a story out with, as words of tildes.
func _filler(padding: Dictionary) -> String:
	var text := "%s — " % padding.get("city", "")
	var words: PackedInt32Array = padding.get("words", PackedInt32Array())
	var written := 0
	for length in words:
		if length == 0:
			text += "\n"
			continue
		text += FILLER_MARK.repeat(length) + " "
		written += 1
		# A page of tildes is the original's joke, not something to reproduce
		# at length; a line of it says the same thing.
		if written >= 24:
			break
	return text.strip_edges() + " …"


func _build() -> void:
	if _body != null:
		return
	add_theme_stylebox_override("panel", UiTheme.panel())
	var column := Atoms.column(Metrics.TIGHT)
	add_child(column)

	_head = PanelHeader.new()
	_head.closed.connect(func() -> void: closed.emit())
	column.add_child(_head)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	_body = Atoms.column(0)
	scroll.add_child(_body)


func _line(text: String, colour: Color) -> void:
	var label := Atoms.wrapped(Atoms.tinted(text, colour))
	_body.add_child(label)
