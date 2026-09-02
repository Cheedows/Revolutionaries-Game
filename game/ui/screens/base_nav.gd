class_name BaseNav
extends RefCounted
## Where the things a player can look at live, and how they are reached.
##
## Split out of base_layout.gd because it is a subject of its own: eleven
## buttons on a desk are a row along the bottom, and on a phone they are one
## button and a list. The rest of the layout does not care which.
##
## The measurement that decided it: on a 400x800 phone the row wrapped onto
## five lines and took 327 pixels — two fifths of the screen, spent saying what
## could be looked at rather than showing any of it. Behind one button it is
## 90, and the content goes from 374 pixels to 611.

## What the row offers, in the original's own order and words.
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


## Builds the row of controls along the bottom of the screen.
static func controls(parts: Dictionary) -> Control:
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

	var more := Atoms.button("More", false)
	parts["more"] = more
	row.add_child(more)

	var menu := Card.new()
	menu.card()
	menu.title(Branding.ORG_NAME)
	menu.visible = false
	parts["menu"] = menu
	return row


## Puts the buttons where there is room for them.
##
## The same [Button] objects move between the row and the card, with whatever
## is connected to them: building two sets and keeping them in step is how a
## button ends up doing nothing.
static func reflow(parts: Dictionary, narrow: bool) -> void:
	var row: Control = parts["controls"]
	var menu: Card = parts["menu"]
	(parts["more"] as Button).visible = narrow
	var home: Control = menu.get("_body") if narrow else row

	var moving: Array[Button] = []
	for which: Variant in parts["buttons"]:
		moving.append((parts["buttons"] as Dictionary)[which])
	moving.append(parts["country"])
	for button in moving:
		if button.get_parent() != home:
			if button.get_parent() != null:
				button.get_parent().remove_child(button)
			home.add_child(button)
		# Full width in the card, so the list reads as a list; sized to their
		# labels in the row, so they fit on one line on a desk.
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if narrow \
				else Control.SIZE_SHRINK_BEGIN
	if narrow:
		# Read top to bottom, the way the country is looked at comes first.
		home.move_child(parts["country"], 0)
	else:
		row.move_child(parts["country"], 2)
