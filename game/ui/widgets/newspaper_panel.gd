class_name NewspaperPanel
extends Card
## The morning's paper.
##
## The original draws it as a page of a newspaper with a block-letter headline,
## columns of story and advertisements down the sides. This lays out the same
## paper as text: the headline over each story, the story, the padding it was
## printed with, and the advertisements around it.

## What the padding is drawn as, since it is only tildes in the original.
const FILLER_MARK := "~"

## Which of the six mastheads is the Liberal Guardian's. The other five are the
## mainstream papers, and preparepage() picks between them at random.
const GUARDIAN_MASTHEAD := 5

## How tall a story's picture is drawn. It is eighteen cells of art.
const PICTURE_HEIGHT := 160

## Which papers have had their masthead drawn on this page already.
var _shown := {}

## How tall each piece of the paper's own art stands.
const MASTHEAD_HEIGHT := 44
const HEADLINE_HEIGHT := 34




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
	_shown.clear()
	for event: Event in events:
		match event.type:
			Event.HEADLINE_RUN:
				_masthead(event)
				_headline(state, event)
				printed += 1
			Event.NEWS_PUBLISHED:
				_masthead(event)
				_story(state, event)
				printed += 1
			Event.NEWS_SEGMENT:
				_segment(event)
				printed += 1
	# The date, which is what the original's masthead carries: preparepage()
	# in src/news/layout.cpp prints the month, the day and the year across the
	# top of every front page. The papers themselves have no names to print —
	# their mastheads are block letters in art/newstops.cpc and the letters do
	# not spell anything.
	_head.set_title(state.calendar.to_display())
	if printed == 0:
		says_nothing("Nothing in today's paper.")


## Names the Liberal Guardian over its own stories.
##
## Every printed story belongs to one of two papers and the original draws it
## under that paper's masthead — five mainstream ones it picks between, and the
## Liberal Guardian, which the squad only gets once somebody can write. The two
## alternate through a morning, since a major event always runs in the
## mainstream press however good the squad's writers are. Laid out as text with
## no mastheads they run together, and a Guardian story reads as though the
## mainstream press had said it, which inverts the joke the whole system exists
## for.
##
## Every Guardian story is named rather than only the first of a run: the
## mainstream papers have no name to print in the other direction, so an
## unnamed story has to be the one that means "not the Guardian".
func _masthead(event: Event) -> void:
	var guardian := bool(event.data.get("guardian", false))
	# Once per paper, not once per story: the original draws a masthead across
	# the front page and page numbers on the ones after it.
	if _shown.has(guardian):
		return
	_shown[guardian] = true
	# The masthead itself, out of the original's own art, and drawn in its own
	# colours rather than the interface's. It is black block letters on white,
	# because it is a newspaper — a strip of paper across the top of the card
	# is the whole point of it.
	var art := PixelArtRect.new()
	art.show_art(CharArt.MASTHEADS,
			GUARDIAN_MASTHEAD if guardian
			else int(event.data.get("masthead", 0)) % GUARDIAN_MASTHEAD,
			MASTHEAD_HEIGHT)
	_body.add_child(art)
	if guardian:
		_line("Liberal Guardian", Palette.ACCENT)


func _headline(state: GameState, event: Event) -> void:
	var lines := HeadlineText.lines(state, event.data.get("headline", &""))
	for line: String in lines:
		# Set in the original's own block capitals, which is what a headline in
		# this game looks like. displaycenterednewsfont() in src/news/news.cpp
		# draws it a letter at a time out of art/largecap.cpc; so does this.
		# Black block capitals on white, which is what they are: the same
		# sheet of paper the masthead is printed on, not a coloured caption.
		var set_in := PixelArtRect.new()
		set_in.show_image(BlockCapitals.of(line), HEADLINE_HEIGHT)
		_body.add_child(set_in)
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
	# The picture that runs beside the story, which is a picture: the original
	# draws it with displaynewspicture() out of art/newspic.cpc, and the port
	# used to print the name of the file in square brackets.
	var at := MajorEventPageText.picture_at(major.get("headline", &""))
	if at != -1:
		var drawn := PixelArtRect.new()
		drawn.show_art(CharArt.PICTURES, at, PICTURE_HEIGHT)
		_body.add_child(drawn)
	if caption != "":
		_line(caption, Palette.TEXT)


## One printed story, under its page number.
##
## The number and nothing else, which is all the original puts there:
## preparepage() prints the date across the front page and a bare page number
## in the corner of every page after it. The port used to print "Page 1 —
## majorevent" — the story's own internal type, in front of the player, where
## the original prints no such thing.
func _story(state: GameState, event: Event) -> void:
	var page := int(event.data.get("guardian_page", 0)) \
			if bool(event.data.get("guardian", false)) \
			else int(event.data.get("page", 0))
	if page > 1:
		_line(str(page), Palette.TEXT_FAINT)
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
	var text := "%s - " % padding.get("city", "")
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
	card()


func _line(text: String, colour: Color) -> void:
	var label := Atoms.wrapped(Atoms.tinted(text, colour))
	_body.add_child(label)
