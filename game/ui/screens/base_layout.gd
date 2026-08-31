class_name BaseLayout
extends RefCounted
## The shape of the safehouse screen.
##
## Building the widgets and deciding what they do are separate jobs, and the
## screen only stays readable if they are kept apart. This makes the tree and
## hands back the pieces; base_screen.gd wires them up.

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

## How tall each of the panels that share the right-hand column stands.
const ROSTER_HEIGHT := 170
const SQUAD_HEIGHT := 150


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
	parts["status"] = StatusBar.new()
	page.add_child(parts["status"])

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 12)
	page.add_child(columns)

	parts["laws"] = LawList.new()
	columns.add_child(parts["laws"])

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	columns.add_child(right)

	parts["roster"] = Roster.new()
	(parts["roster"] as Control).custom_minimum_size = Vector2(0, ROSTER_HEIGHT)
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
	(parts["squad"] as Control).custom_minimum_size = Vector2(0, SQUAD_HEIGHT)
	right.add_child(parts["squad"])

	parts["log"] = LogView.new()
	(parts["log"] as Control).size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(parts["log"])

	parts["dialog"] = IntentDialog.new()
	right.add_child(parts["dialog"])

	page.add_child(_controls(parts))
	return parts


## The row along the bottom: waiting, running, and one button per panel.
static func _controls(parts: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var wait := Button.new()
	wait.text = "Wait a day"
	parts["wait"] = wait
	row.add_child(wait)

	var run := Button.new()
	run.text = "Let it run"
	run.toggle_mode = true
	parts["run"] = run
	row.add_child(run)

	var buttons := {}
	for entry: Array in PANEL_BUTTONS:
		var button := Button.new()
		button.text = String(entry[1])
		buttons[entry[0]] = button
		row.add_child(button)
	parts["buttons"] = buttons
	return row
