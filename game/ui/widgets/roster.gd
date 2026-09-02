class_name Roster
extends PanelContainer
## Who the organisation has, and what they are doing.
##
## The original lists six at a time in a fixed grid because that is what fits a
## terminal. This scrolls, so the limit is the squad size rather than the screen.

## Emitted when the player puts someone on a different activity.
signal activity_chosen(creature: Creature, activity: StringName)

## Emitted when the player wants to look at somebody properly.
signal dossier_wanted(creature: Creature)

## Emitted when a guard has been put on a particular prisoner.
signal hostage_chosen(keeper: Creature, hostage: Creature)

## Emitted when a recruiter has been told what kind of person to look for.
signal recruit_chosen(recruiter: Creature, type: StringName)

var _rows: VBoxContainer

## The garments a tailor could be told to make, worked out from the state and
## the catalog as the roster is drawn. Kept as a list rather than as the state
## itself, because a widget has no business holding onto [GameState].
var _garment_choices: Array[StringName] = []

## Who a recruiter could be told to look for, hardest last, with how hard each
## one is. Set the same way, and for the same reason.
var _recruit_choices: Array[Dictionary] = []

## Whether a row has to fold onto more than one line to fit.
var _compact := false


func _ready() -> void:
	_build()

## Builds the widget's children.
##
## Called from _ready(), and again from refresh(), because a screen may fill a
## widget in before it reaches the tree — and a view that silently drops what
## it was given is worse than one that builds early.
func _build() -> void:
	if _rows != null:
		return
	add_theme_stylebox_override("panel", UiTheme.panel())
	var column := Atoms.column(Metrics.SNUG)
	add_child(column)

	var heading := Atoms.heading(Branding.ORG_MEMBERS)
	column.add_child(heading)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	_rows = Atoms.column(Metrics.SNUG)
	scroll.add_child(_rows)


## What a tailor can be told to make. The screen works it out, because doing so
## needs the catalog and the law and a widget should hold neither.
func offer_garments(choices: Array[StringName]) -> void:
	_garment_choices = choices


## Who a recruiter can be sent to look for, with how hard each one is.
func offer_recruits(choices: Array[Dictionary]) -> void:
	_recruit_choices = choices


## Folds each row onto as many lines as it needs, or back onto one.
##
## A row is a name, a condition, what the person is doing and a way in to their
## record, lined up in columns — which is what makes twenty of them readable at
## a glance, and which does not fit across a phone. Compact keeps every part of
## the row and lets it wrap instead of dropping any of it: a member of the
## squad the player cannot reassign is worse than one who takes two lines.
func compact(on: bool) -> void:
	_compact = on


## Redraws from [param state].
func refresh(state: GameState) -> void:
	_build()
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()

	var members := state.members()
	if members.is_empty():
		var empty := Atoms.nothing("Nobody yet.")
		_rows.add_child(empty)
		return

	for creature in members:
		_rows.add_child(_row(creature, HostageWatch.candidates(state, creature)))


func _row(creature: Creature, held: Array[Creature]) -> Control:
	var row: Container = HFlowContainer.new() if _compact else HBoxContainer.new()
	row.add_theme_constant_override(&"separation", Metrics.SNUG)
	row.add_theme_constant_override(&"h_separation", Metrics.SNUG)
	row.add_theme_constant_override(&"v_separation", Metrics.TIGHT)

	var name_label := Atoms.body(creature.name)
	name_label.custom_minimum_size = Vector2(_wide(180), 0)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_color_override("font_color",
			Palette.for_alignment(Alignment.value_of(creature.alignment)))
	row.add_child(name_label)

	var juice := Atoms.dim("%d juice" % creature.juice)
	juice.custom_minimum_size = Vector2(_wide(90), 0)
	row.add_child(juice)

	var condition := Atoms.body(_condition(creature))
	condition.custom_minimum_size = Vector2(_wide(130), 0)
	condition.add_theme_color_override("font_color",
			Palette.TEXT_DIM if creature.body.blood > 50 else Palette.CONSERVATIVE)
	row.add_child(condition)

	# What they are doing is a choice, so it is a control rather than a label.
	var activities := OptionButton.new()
	activities.custom_minimum_size = Vector2(_wide(190), 0)
	for index in ActivityAssignment.AVAILABLE.size():
		var activity: StringName = ActivityAssignment.AVAILABLE[index]
		activities.add_item(ActivityText.of(activity), index)
		if creature.activity == activity:
			activities.select(index)
	activities.item_selected.connect(func(index: int):
		activity_chosen.emit(creature, ActivityAssignment.AVAILABLE[index]))
	row.add_child(activities)

	# Sewing needs to be told what to sew, which the original asks on a screen
	# of its own. It is a second picker here, shown only when it applies.
	if AssignmentChoice.needs_more(creature.activity):
		row.add_child(_garments(creature))

	# Tending needs a prisoner named, or the interrogation pass finds no guard.
	if creature.activity == &"hostagetending" and not held.is_empty():
		row.add_child(_hostages(creature, held))

	# Recruiting needs a profession named, or asking around finds nobody.
	if creature.activity == &"recruiting" and not _recruit_choices.is_empty():
		row.add_child(_recruits(creature))

	var look := Atoms.button("Look", false)
	look.tooltip_text = "View Status  %s" % creature.name
	look.pressed.connect(func() -> void: dossier_wanted.emit(creature))
	row.add_child(look)
	return row


## Which garment a tailor is working on.
func _garments(creature: Creature) -> Control:
	var picker := OptionButton.new()
	picker.custom_minimum_size = Vector2(_wide(180), 0)
	var choices := _garment_choices
	for index in choices.size():
		picker.add_item(String(choices[index]).trim_prefix("ARMOR_")
				.capitalize(), index)
		if creature.making == choices[index]:
			picker.select(index)
	picker.item_selected.connect(func(index: int) -> void:
		AssignmentChoice.choose(creature, creature.activity, choices[index])
		activity_chosen.emit(creature, creature.activity))
	return picker


## Who a recruiter is out looking for.
func _recruits(creature: Creature) -> Control:
	var picker := OptionButton.new()
	picker.custom_minimum_size = Vector2(_wide(230), 0)
	var choices := _recruit_choices
	for index in choices.size():
		var type: StringName = choices[index]["type"]
		picker.add_item(ActivityText.recruit_label(
				type, int(choices[index]["difficulty"])), index)
		if creature.recruiting == type:
			picker.select(index)
	picker.item_selected.connect(func(index: int) -> void:
		recruit_chosen.emit(creature, StringName(choices[index]["type"])))
	return picker


## Which prisoner a guard is watching.
func _hostages(creature: Creature, held: Array[Creature]) -> Control:
	var picker := OptionButton.new()
	picker.custom_minimum_size = Vector2(_wide(180), 0)
	for index in held.size():
		picker.add_item(held[index].name, index)
		if creature.tending_id == held[index].id:
			picker.select(index)
	picker.item_selected.connect(func(index: int) -> void:
		hostage_chosen.emit(creature, held[index]))
	return picker


## A column width, shrunk to what the screen can afford.
func _wide(pixels: int) -> int:
	return Metrics.column(self, pixels) if _compact else pixels


## What is currently true of this person, in a word or two.
##
## The original's roster columns, from src/basemode/reviewmode.cpp: months
## left to serve, months until the clinic lets them out, whether they are in
## hiding, and otherwise the health word every screen shows beside a name.
func _condition(creature: Creature) -> String:
	if creature.sentence < -1:
		return "%d Life Sentences" % -creature.sentence
	if creature.sentence == -1:
		return "Life Sentence"
	if creature.sentence > 0:
		return "%d %s" % [creature.sentence,
				"Month" if creature.sentence == 1 else "Months"]
	if creature.clinic > 0:
		return "Out in %d %s" % [creature.clinic,
				"Month" if creature.clinic == 1 else "Months"]
	if creature.hiding > 0:
		return "In Hiding"
	return ConditionText.of(creature)
