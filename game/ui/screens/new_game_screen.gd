extends Control
## Starting a game: the difficulty switches, then the founder's ten questions.
##
## The original asks these across three terminal screens and a menu of
## single-letter keys. Here they are the same questions rendered by the same
## [IntentDialog] every other decision in the game goes through, so there is
## one place that knows how to ask something.

## What the first screen offers, in the original's order and its words.
##
## The names are the original's jokes and they are the point: a switch called
## "We Didn't Start The Fire" tells you something about the game you are about
## to play that "a strong Conservative Crime Squad" does not. Carried from
## src/title/newgame.cpp rather than described afresh.
const SWITCHES: Array[Dictionary] = [
	{&"id": &"classic", &"label": "Classic Mode",
			&"note": "No Conservative Crime Squad."},
	{&"id": &"strong_ccs", &"label": "We Didn't Start The Fire",
			&"note": "The CCS starts active and extremely strong."},
	{&"id": &"nightmare_laws", &"label": "Nightmare Mode",
			&"note": "Liberalism is forgotten. Is it too late to fight back?"},
	{&"id": &"multiple_cities", &"label": "National LCS",
			&"note": "Advanced play across multiple cities."},
	{&"id": &"no_court_purge", &"label": "Marathon Mode",
			&"note": "Prevent Liberals from amending the Constitution."},
	{&"id": &"stalin", &"label": "Stalinist Mode",
			&"note": "Enable Stalinist Comrade Squad (not fully implemented)."},
]

const WIN_CONDITIONS: Array[Dictionary] = [
	{&"id": &"elite_liberal", &"label": "No Compromise Classic",
			&"note": "I will make all our laws Elite Liberal!"},
	{&"id": &"easy", &"label": "Democrat Mode",
			&"note": "Most laws must be Elite Liberal, some can be Liberal."},
]

## The original heads this screen "Field Learning" and says underneath it what
## field learning covers, which is worth keeping: the switch is meaningless
## without it.
const FIELD_LEARNING := \
		"Field Learning (affects Security, Stealth, Disguise, & Driving)"

const SKILL_RATES: Array[Dictionary] = [
	{&"id": &"fast", &"label": "Fast skills",
			&"note": "Grinding is Conservative!"},
	{&"id": &"classic", &"label": "Classic",
			&"note": "Excellence requires practice."},
	{&"id": &"hard", &"label": "Hard Mode",
			&"note": "Learn from the best, or face arrest!"},
]

signal started(session: Session)

var _session: Session
var _dialog: IntentDialog
var _scroll: ScrollContainer

## Where a player types their own name, shown only while that is being asked.
var _typed: LineEdit
var _heading: Label
var _chosen := {}
var _choosing: Dictionary
var _outcome := {}
var _stage := 0
var _question := 0


func _ready() -> void:
	build()


## Builds the screen on a seed of the moment. See title_screen.gd's build()
## for why this is public.
func build() -> void:
	begin(int(Time.get_unix_time_from_system()) & 0xffffffff)


## Builds the screen and asks the first question.
func begin(seed_value: int) -> void:
	_session = Session.new(seed_value)
	_build()
	_adapt()
	_ask_switches()


## The session the answers built, once the last question is done.
func session() -> Session:
	return _session


func _ask_switches() -> void:
	var options: Array[Dictionary] = []
	for switch: Dictionary in SWITCHES:
		var on := bool(_chosen.get(switch[&"id"], false))
		options.append({
			"id": switch[&"id"],
			"label": "%s  %s" % ["[x]" if on else "[ ]", switch[&"label"]],
			"note": switch.get(&"note", ""),
		})
	options.append({"id": &"done", "label": "Continue"})
	_show("Advanced Gameplay Options", Intent.new(Intent.CONFIRM_NEW_GAME,
			options, {}, false))


func _ask_from(list: Array[Dictionary], heading: String) -> void:
	var options: Array[Dictionary] = []
	for entry: Dictionary in list:
		options.append({"id": entry[&"id"], "label": entry[&"label"],
				"note": entry.get(&"note", "")})
	_show(heading, Intent.new(Intent.CONFIRM_NEW_GAME, options, {}, false))


## The founder's name and how the world reads them, which the original asks
## before the questions and lets you roll again as often as you like.
##
## Ports the naming half of makecharacter() from src/title/newgame.cpp: another
## first name, another surname, step the gender round, or type your own.
func _ask_name() -> void:
	var founder: Creature = _choosing["creature"]
	var options: Array[Dictionary] = [
		{"id": &"first", "label": "Another first name"},
		{"id": &"last", "label": "Another surname"},
		{"id": &"gender", "label": "Read differently"},
		{"id": &"done", "label": "This will do"},
	]
	_typed.visible = true
	_typed.placeholder_text = "or type a name"
	_show("%s — %s" % [Founder.chosen_name(_choosing),
			StrangerText.gender(founder)],
			Intent.new(Intent.CHOOSE_FOUNDER_NAME, options, {}, false))


## What the naming screen does with each answer.
func _name_chosen(id: Variant) -> void:
	match id:
		&"first":
			Founder.another_first_name(_session.rng, _choosing)
		&"last":
			Founder.another_last_name(_session.rng, _choosing)
		&"gender":
			Founder.cycle_gender(_choosing)
		_:
			var typed := _typed.text.strip_edges()
			if typed != "":
				var founder: Creature = _choosing["creature"]
				founder.name = typed
				founder.named = true
			_typed.visible = false
			_stage = 4
			_ask_background()
			return
	_ask_name()


func _ask_background() -> void:
	var options: Array[Dictionary] = []
	for index in FounderBackgrounds.OPTIONS:
		options.append({"id": index,
				"label": FounderText.answer(_question, index)})
	_show(FounderText.question(_question),
			Intent.new(Intent.CHOOSE_FOUNDER_BACKGROUND, options, {}, false))


func _show(heading: String, intent: Intent) -> void:
	_heading.text = heading
	_dialog.ask(intent, _session.state)


func _on_chosen(id: Variant) -> void:
	match _stage:
		0:
			if id == &"done":
				_stage = 1
				_ask_from(WIN_CONDITIONS, "Your Agenda")
				return
			_chosen[id] = not bool(_chosen.get(id, false))
			_ask_switches()
		1:
			_chosen[&"win_condition"] = id
			_stage = 2
			_ask_from(SKILL_RATES, FIELD_LEARNING)
		2:
			_chosen[&"field_skill_rate"] = id
			_stage = 3
			NewGame.choose(_session.state, _session.rng, _chosen)
			_choosing = Founder.begin(_session.rng)
			_ask_name()
		3:
			_name_chosen(id)
		_:
			# The original rolls a suggestion for every question whether or not
			# it uses it, so the roll happens either way.
			Founder.suggestion(_session.rng)
			Founder.answer(_session.state, _choosing, _question, int(id),
					_outcome)
			_question += 1
			if _question < FounderBackgrounds.QUESTIONS:
				_ask_background()
				return
			_dialog.dismiss()
			NewGame.begin(_session.state, _session.rng, _choosing, _outcome,
					_session.catalog)
			started.emit(_session)


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Palette.BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	# The whole screen scrolls as one thing on a phone, rather than the list
	# of options scrolling inside it. See Metrics.unscroll().
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_left = 24
	_scroll.offset_top = 24
	_scroll.offset_right = -24
	_scroll.offset_bottom = -24
	add_child(_scroll)

	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 12)
	_scroll.add_child(page)

	var title := Label.new()
	title.text = Branding.GAME_TITLE
	title.add_theme_color_override("font_color", Palette.ACCENT)
	page.add_child(title)

	_heading = Label.new()
	_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_heading)

	_typed = LineEdit.new()
	_typed.visible = false
	_typed.custom_minimum_size = Vector2(280, 0)
	page.add_child(_typed)

	_dialog = IntentDialog.new()
	_dialog.chosen.connect(_on_chosen)
	page.add_child(_dialog)


## Lays the screen out for the room it has been given.
##
## The interface is one interface at two sizes; [Metrics] decides which, from
## how wide the surface being drawn on actually is. See ui/theme/metrics.gd.
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _dialog != null:
		_adapt()


func _adapt() -> void:
	theme = UiTheme.build(Metrics.touch(self))
	var narrow := Metrics.narrow(self)
	if _scroll != null:
		if narrow:
			Metrics.page_scroller(_scroll)
		else:
			if _scroll.has_meta(&"page_scroller"):
				_scroll.remove_meta(&"page_scroller")
			_scroll.horizontal_scroll_mode = \
					ScrollContainer.SCROLL_MODE_DISABLED
			_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		Metrics.unscroll(_scroll, narrow)
	if _dialog != null:
		_dialog.compact(Metrics.narrow(self))
	Metrics.enlarge(self, Metrics.touch(self))
