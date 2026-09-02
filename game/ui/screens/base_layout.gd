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
	[PanelStack.AGENDA, "Liberal Agenda"],
	[PanelStack.HOUSE, "Safehouse"],
	[PanelStack.PAPER, "The paper"],
	[PanelStack.STORES, "Assets"],
	[PanelStack.JUSTICE, "Justice System"],
	[PanelStack.SQUAD, "The squad"],
	[PanelStack.SLEEPERS, "Sleepers"],
	[PanelStack.SETTINGS, "Save File"],
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

	var page := Atoms.column(Metrics.SNUG)
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override(&"separation", Metrics.SNUG)
	page.offset_left = 16
	page.offset_top = 16
	page.offset_right = -16
	page.offset_bottom = -16
	screen.add_child(page)

	var parts := {}
	parts["page"] = page
	parts["status"] = StatusBar.new()
	page.add_child(parts["status"])

	# The one scroller a phone gets. On a desk it is switched off and each
	# pane keeps its own, which is what a pointer expects; on a phone it is
	# the only thing that moves. See Metrics.unscroll().
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	parts["scroll"] = scroll

	var columns := Atoms.row(Metrics.ROOM)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(columns)
	parts["columns"] = columns

	parts["laws"] = LawList.new()
	(parts["laws"] as Control).custom_minimum_size = Vector2(LAWS_WIDTH, 0)
	columns.add_child(parts["laws"])

	var right := Atoms.column(Metrics.ROOM)
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
			parts["dialog"], parts["status"], parts["log"], parts["panels"]]:
		if (part as Object).has_method(&"compact"):
			(part as Object).call(&"compact", narrow)

	# One scroller, or fifteen. See Metrics.unscroll() for why a phone gets one.
	var scroll: ScrollContainer = parts["scroll"]
	var columns: Control = parts["columns"]
	if narrow:
		Metrics.page_scroller(scroll)
		columns.size_flags_vertical = Control.SIZE_FILL
	else:
		if scroll.has_meta(&"page_scroller"):
			scroll.remove_meta(&"page_scroller")
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		# Auto rather than off. A desk usually has room for the whole
		# safehouse at once and shows no bar, but opening a panel in a 1280x800
		# window does not fit — and with scrolling off the page simply grew
		# past the bottom of the window, taking the row of panel buttons with
		# it. A bar that appears only when it is needed costs nothing on the
		# days it is not.
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	Metrics.unscroll(columns, narrow)

	# A phone reads the column top to bottom, so whatever the game is asking
	# goes first and everything else is below it. On a desk the question sits
	# where it always has, under the log it is about.
	var right: Control = parts["right"]
	var dialog: Control = parts["dialog"]
	right.move_child(dialog, 0 if narrow else right.get_child_count() - 1)


## The row along the bottom: waiting, running, and one button per panel.
##
## An [HFlowContainer] rather than a row, so that eleven buttons that sit on
## one line on a desk sit on three on a phone instead of running off the edge.
static func _controls(parts: Dictionary) -> Control:
	var row := Atoms.flow(Metrics.SNUG)
	parts["controls"] = row

	var wait := Atoms.button("Wait a day", false)
	parts["wait"] = wait
	row.add_child(wait)

	# Not "Wait a day" a second time, which is what both of these said. One
	# waits a day; this one keeps waiting until something happens, and a player
	# looking at two identical buttons has no way to know which is which.
	var run := Atoms.button("Keep waiting", false)
	run.toggle_mode = true
	parts["run"] = run
	row.add_child(run)

	# On a wide screen the law column is simply there. On a narrow one there is
	# no room beside anything, so it becomes another thing to open.
	var country := Atoms.button("The country", false)
	country.toggle_mode = true
	parts["country"] = country
	row.add_child(country)

	var buttons := {}
	for entry: Array in PANEL_BUTTONS:
		var button := Atoms.button(str(entry[1]), false)
		buttons[entry[0]] = button
		row.add_child(button)
	parts["buttons"] = buttons
	return row


## Decides what is on screen at once.
##
## Nearly everything, which is the whole point of not being a terminal any
## more — and on a phone too, now that the column scrolls: things used to take
## turns being hidden because the column was a fixed height and there was no
## room, and taking turns is worse than reading downwards. What is hidden here
## is only what would be wrong to show: the floor plan outside a building, the
## roster inside one.
##
## [param country] is whether the player has asked for the law column on a
## screen too narrow to keep it up all the time.
static func focus(parts: Dictionary, inside: bool, reading: bool,
		narrow: bool, country: bool) -> void:
	var laws_up := true if not narrow else country
	(parts["laws"] as Control).visible = laws_up
	# On a phone the law column is the whole width when it is up at all, so
	# everything it would have sat beside stands down while it is.
	(parts["right"] as Control).visible = not (narrow and laws_up)

	(parts["map"] as Control).visible = inside and not reading
	(parts["roster"] as Control).visible = not inside and not reading
	(parts["squad"] as Control).visible = not inside and not reading
	(parts["log"] as Control).visible = true
	var fight: Control = parts["fight"]
	fight.visible = fight.visible and not reading
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
