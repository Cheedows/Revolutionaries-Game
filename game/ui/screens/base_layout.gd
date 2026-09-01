class_name BaseLayout
extends RefCounted
## The shape of the safehouse screen.
##
## Building the widgets and deciding what they do are separate jobs, and the
## screen only stays readable if they are kept apart. This makes the tree and
## hands back the pieces; base_screen.gd wires them up.
##
## It makes one tree, not two. A phone and a desk get the same widgets in the
## same order; what changes is how much of it is on screen at once, which is
## [method reflow]'s job and is re-asked every time the window changes size.

## The buttons along the bottom, and what each says.
const PANEL_BUTTONS: Array = [
	[PanelStack.AGENDA, "The agenda"],
	[PanelStack.HOUSE, "The safehouse"],
	[PanelStack.PAPER, "The paper"],
	[PanelStack.STORES, "The stores"],
	[PanelStack.JUSTICE, "The courts"],
	[PanelStack.SQUAD, "The squad"],
	[PanelStack.SLEEPERS, "The sleepers"],
	[PanelStack.SETTINGS, "Save & settings"],
]

## How tall each of the panels that share the right-hand column stands, with
## room to breathe and without.
const ROSTER_HEIGHT := 170
const SQUAD_HEIGHT := 150
const NARROW_ROSTER_HEIGHT := 150
const NARROW_SQUAD_HEIGHT := 96

## How wide the law column stands when it has a column to itself.
const LAWS_WIDTH := 260


## Builds the screen into [param screen] and returns its parts by name.
static func build(screen: Control) -> Dictionary:
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Palette.BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(background)

	var page := VBoxContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 12)
	page.offset_left = 16
	page.offset_top = 16
	page.offset_right = -16
	page.offset_bottom = -16
	screen.add_child(page)

	var parts := {}
	parts["page"] = page
	parts["status"] = StatusBar.new()
	page.add_child(parts["status"])

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 12)
	page.add_child(columns)
	parts["columns"] = columns

	parts["laws"] = LawList.new()
	(parts["laws"] as Control).custom_minimum_size = Vector2(LAWS_WIDTH, 0)
	columns.add_child(parts["laws"])

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	columns.add_child(right)
	parts["right"] = right

	parts["roster"] = Roster.new()
	right.add_child(parts["roster"])

	# Everything that opens over the roster: a person's record, the state of
	# the country, the safehouse, the paper, the stores and the courts.
	parts["panels"] = PanelStack.new()
	(parts["panels"] as Control).visible = false
	right.add_child(parts["panels"])

	parts["map"] = SiteMapView.new()
	(parts["map"] as Control).visible = false
	right.add_child(parts["map"])

	# Who is in the room, or in the cars, while there is a fight on.
	parts["fight"] = FightPanel.new()
	(parts["fight"] as Control).visible = false
	right.add_child(parts["fight"])

	parts["squad"] = SquadPanel.new()
	right.add_child(parts["squad"])

	parts["log"] = LogView.new()
	(parts["log"] as Control).size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(parts["log"])

	parts["dialog"] = IntentDialog.new()
	right.add_child(parts["dialog"])

	page.add_child(_controls(parts))
	reflow(parts, false)
	return parts


## Lays the parts out for the room there is.
##
## Called whenever the window changes size, so this has to be safe to run over
## and over and has to leave nothing behind — it only ever sets sizes and
## flags, and never adds or removes anything.
static func reflow(parts: Dictionary, narrow: bool) -> void:
	var laws: Control = parts["laws"]
	laws.custom_minimum_size = Vector2(0 if narrow else LAWS_WIDTH, 0)
	laws.size_flags_horizontal = Control.SIZE_EXPAND_FILL if narrow \
			else Control.SIZE_FILL

	var roster: Control = parts["roster"]
	roster.custom_minimum_size = Vector2(0,
			NARROW_ROSTER_HEIGHT if narrow else ROSTER_HEIGHT)
	var squad: Control = parts["squad"]
	squad.custom_minimum_size = Vector2(0,
			NARROW_SQUAD_HEIGHT if narrow else SQUAD_HEIGHT)

	var gap := Metrics.TOUCH_GAP if narrow else Metrics.BASE_GAP
	for which in ["page", "columns", "right", "controls"]:
		var box: Control = parts[which]
		box.add_theme_constant_override("separation", gap)
	var page: Control = parts["page"]
	page.offset_left = gap
	page.offset_top = gap
	page.offset_right = -gap
	page.offset_bottom = -gap

	for part: Variant in [parts["roster"], parts["map"], parts["laws"],
			parts["dialog"], parts["status"]]:
		if (part as Object).has_method(&"compact"):
			(part as Object).call(&"compact", narrow)


## The row along the bottom: waiting, running, and one button per panel.
##
## An [HFlowContainer] rather than a row, so that eleven buttons that sit on
## one line on a desk sit on three on a phone instead of running off the edge.
static func _controls(parts: Dictionary) -> Control:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	parts["controls"] = row

	var wait := Button.new()
	wait.text = "Wait a day"
	parts["wait"] = wait
	row.add_child(wait)

	var run := Button.new()
	run.text = "Let it run"
	run.toggle_mode = true
	parts["run"] = run
	row.add_child(run)

	# On a wide screen the law column is simply there. On a narrow one there is
	# no room beside anything, so it becomes another thing to open.
	var country := Button.new()
	country.text = "The country"
	country.toggle_mode = true
	parts["country"] = country
	row.add_child(country)

	var buttons := {}
	for entry: Array in PANEL_BUTTONS:
		var button := Button.new()
		button.text = str(entry[1])
		buttons[entry[0]] = button
		row.add_child(button)
	parts["buttons"] = buttons
	return row


## Decides what is on screen at once.
##
## On a wide screen the answer is "nearly everything", which is the whole point
## of not being a terminal any more. A phone cannot pay for that, so the rule
## there is that whatever the player has been asked gets the room: a question
## on a phone is the screen, and the roster, the squad and the log stand aside
## until it has been answered.
##
## [param country] is whether the player has asked for the law column on a
## screen too narrow to keep it up all the time.
static func focus(parts: Dictionary, inside: bool, reading: bool,
		asking: bool, narrow: bool, country: bool) -> void:
	var laws_up := true if not narrow else country
	(parts["laws"] as Control).visible = laws_up
	# On a phone the law column is the whole width when it is up at all, so
	# everything it would have sat beside stands down while it is.
	var crowded_out := narrow and (laws_up or (asking and not reading))
	(parts["right"] as Control).visible = not (narrow and laws_up)

	(parts["map"] as Control).visible = inside and not reading
	(parts["roster"] as Control).visible = \
			not inside and not reading and not crowded_out
	(parts["squad"] as Control).visible = \
			not inside and not reading and not crowded_out
	(parts["log"] as Control).visible = not crowded_out
	var fight: Control = parts["fight"]
	fight.visible = fight.visible and not reading and not crowded_out
	(parts["country"] as Button).visible = narrow


## Takes one step back out of whatever is open, and says whether it did.
##
## Android's back button is not a key: it arrives as a notification and, left
## alone, closes the game. A player who opens the paper and presses back means
## "shut the paper", so this shuts the topmost thing that is open and reports
## that it handled it. What it does not handle — nothing open at all — is the
## screen's to answer.
static func step_back(parts: Dictionary) -> bool:
	var country: Button = parts["country"]
	if country.visible and country.button_pressed:
		country.button_pressed = false
		return true
	var panels: PanelStack = parts["panels"]
	if panels.is_open():
		panels.open(PanelStack.NONE, null)
		return true
	return false
