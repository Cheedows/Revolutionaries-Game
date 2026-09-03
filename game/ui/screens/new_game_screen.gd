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

## Which switches cancel which, both ways round.
##
## One pair: a game with no Conservative Crime Squad cannot also have a strong
## one. The original greys "We Didn't Start The Fire" when Classic Mode is on
## and stops there — turning the strong one on first leaves Classic Mode
## bright, and pressing it then silently wins, because newgame.cpp sets the
## endgame from classicmode and only falls through to strongccs when classicmode
## is off.
##
## A deliberate departure, and a small one: this refuses each of them while the
## other is on, so the contradiction cannot be entered from either side. No
## outcome is lost. The original's fourth state — both flags set — plays out
## exactly as Classic Mode alone does, because that is the branch that wins, so
## the only thing that has gone is a way of asking for one thing and getting
## another.
const CANCELS := {
	&"classic": &"strong_ccs",
	&"strong_ccs": &"classic",
}

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
		# Marked as switches rather than drawn as "[x] " and "[ ] " in front of
		# the label. The brackets are what the original has to draw a checkbox
		# with; a screen that can draw one should draw one. See [ToggleRow].
		var cancelled_by: Variant = CANCELS.get(switch[&"id"])
		var refused := cancelled_by != null \
				and bool(_chosen.get(cancelled_by, false))
		options.append({
			"id": switch[&"id"],
			"label": switch[&"label"],
			"note": switch.get(&"note", ""),
			"toggle": true,
			"on": bool(_chosen.get(switch[&"id"], false)),
			"enabled": not refused,
		})
	# Under the list rather than in it: the six switches are things you flip,
	# and this is the one thing that leaves.
	options.append({"id": &"done", "label": "Continue", "footer": true})
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
		{"id": &"first", "label": "Have your parents reconsider"},
		{"id": &"last", "label": "Be born to a different family"},
		{"id": &"gender", "label": "Change your sex at birth"},
		{"id": &"done", "label": "Ready to begin", "footer": true},
	]
	_typed.visible = true
	_typed.placeholder_text = "FIRST NAME:"
	_show("%s - %s" % [Founder.chosen_name(_choosing),
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
			# A blank code name is not an error — see NewGame.begin(), which
			# falls back to the founder's own name the way the original's
			# enter_name() does.
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
				"label": FounderText.answer(_question, index),
				# What the answer is worth, which the original knows and keeps
				# to itself. See FounderText.bonus().
				"note": FounderText.bonus(_question, index),
				"under": true})
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


## Builds the screen's widgets, once. Guarded for the reason title_screen.gd's
## _build() is guarded: begin() and build() are both public and both callable
## before _ready() has run.
func _build() -> void:
	if _dialog != null:
		return
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Palette.BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	# The page itself does not scroll. What is long here is the list of
	# options, and it is the list that scrolls, inside the dialog, under a bar
	# of actions pinned to the bottom — otherwise the one button that leaves
	# the screen is drawn below the bottom of the screen, which is what
	# shipped.
	var page := VBoxContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.offset_left = Metrics.EDGE
	page.offset_top = Metrics.EDGE
	page.offset_right = -Metrics.EDGE
	page.offset_bottom = -Metrics.EDGE
	page.add_theme_constant_override("separation", Metrics.SNUG)
	add_child(page)

	page.add_child(Atoms.wrapped(Atoms.title(Branding.GAME_TITLE)))

	_heading = Atoms.wrapped(Atoms.body(""))
	page.add_child(_heading)

	_typed = Atoms.field("")
	_typed.visible = false
	_typed.custom_minimum_size = Vector2(280, 0)
	page.add_child(_typed)

	_dialog = IntentDialog.new()
	_dialog.chosen.connect(_on_chosen)
	_dialog.pin(true)
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
	if _dialog != null:
		_dialog.compact(Metrics.narrow(self))
	Metrics.enlarge(self, Metrics.touch(self))
	PressFeel.teach(self)
