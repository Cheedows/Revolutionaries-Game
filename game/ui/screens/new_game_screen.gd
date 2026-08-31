extends Control
## Starting a game: the difficulty switches, then the founder's ten questions.
##
## The original asks these across three terminal screens and a menu of
## single-letter keys. Here they are the same questions rendered by the same
## [IntentDialog] every other decision in the game goes through, so there is
## one place that knows how to ask something.

## What the first screen offers, in the original's order.
const SWITCHES: Array[Dictionary] = [
	{&"id": &"classic", &"label": "Classic mode",
			&"note": "No Conservative Crime Squad"},
	{&"id": &"strong_ccs", &"label": "A strong Conservative Crime Squad",
			&"note": "They come for you"},
	{&"id": &"nightmare_laws", &"label": "Nightmare laws",
			&"note": "The country has already lost"},
	{&"id": &"multiple_cities", &"label": "More than one city"},
	{&"id": &"no_court_purge", &"label": "No court purge, no term limits"},
	{&"id": &"stalin", &"label": "Stalin mode"},
]

const WIN_CONDITIONS: Array[Dictionary] = [
	{&"id": &"elite_liberal", &"label": "Win by making the country Liberal"},
	{&"id": &"easy", &"label": "Win by passing the Liberal agenda"},
]

const SKILL_RATES: Array[Dictionary] = [
	{&"id": &"fast", &"label": "Learn quickly in the field"},
	{&"id": &"classic", &"label": "Learn as the original does"},
	{&"id": &"hard", &"label": "Learn slowly"},
]

signal started(session: Session)

var _session: Session
var _dialog: IntentDialog
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
	theme = UiTheme.build()
	_build()
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
	options.append({"id": &"done", "label": "Begin"})
	_show("How hard should it be?", Intent.new(Intent.CONFIRM_NEW_GAME,
			options, {}, false))


func _ask_from(list: Array[Dictionary], heading: String) -> void:
	var options: Array[Dictionary] = []
	for entry: Dictionary in list:
		options.append({"id": entry[&"id"], "label": entry[&"label"]})
	_show(heading, Intent.new(Intent.CONFIRM_NEW_GAME, options, {}, false))


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
				_ask_from(WIN_CONDITIONS, "What counts as winning?")
				return
			_chosen[id] = not bool(_chosen.get(id, false))
			_ask_switches()
		1:
			_chosen[&"win_condition"] = id
			_stage = 2
			_ask_from(SKILL_RATES, "How fast does anybody learn?")
		2:
			_chosen[&"field_skill_rate"] = id
			_stage = 3
			NewGame.choose(_session.state, _session.rng, _chosen)
			_choosing = Founder.begin(_session.rng)
			_ask_background()
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

	var page := VBoxContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 12)
	page.offset_left = 24
	page.offset_top = 24
	page.offset_right = -24
	page.offset_bottom = -24
	add_child(page)

	var title := Label.new()
	title.text = Branding.GAME_TITLE
	title.add_theme_color_override("font_color", Palette.ACCENT)
	page.add_child(title)

	_heading = Label.new()
	_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_heading)

	_dialog = IntentDialog.new()
	_dialog.chosen.connect(_on_chosen)
	page.add_child(_dialog)
