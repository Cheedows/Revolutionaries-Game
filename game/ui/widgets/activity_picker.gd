class_name ActivityPicker
extends Card
## What one Liberal will be doing, asked the way the original asks it.
##
## Two questions rather than one list. The original draws a column of
## categories and, once one is chosen, the jobs inside it beside them; see
## [ActivityMenu], which carries both sets of names. The port had all
## forty-two jobs in a single drop-down — longer than a phone, in a control
## whose own scrollbar a thumb cannot catch, and flat, so choosing between
## Prostituting and Public Policy looked like the same kind of decision as
## choosing between two classes.
##
## The category is a step, not a mode: pressing one goes forward, and the head
## goes back. Three categories hold a single job and settle it on the spot,
## which is what the original does with them too.

## Emitted when the player has settled on something.
signal chosen(who: Creature, activity: StringName)

var _session: Session
var _creature: Creature
var _group: StringName = &""


func _ready() -> void:
	_build()


## Asks what [param creature] will be doing. Starts at the categories.
func show_creature(session: Session, creature: Creature) -> void:
	_build()
	_session = session
	_creature = creature
	visible = creature != null
	_group = &""
	if creature != null:
		_refresh()


func _build() -> void:
	card()


func _refresh() -> void:
	empty()
	if _group == &"":
		_ask_which_kind()
	else:
		_ask_which_job()


## The first question: what sort of thing are they going to be doing.
func _ask_which_kind() -> void:
	_head.set_title("Taking Action: What will %s be doing today?"
			% _creature.name)
	var doing := ActivityMenu.group_of(_creature.activity)
	for group: Dictionary in ActivityMenu.GROUPS:
		var key: StringName = group["key"]
		var row := ListRow.new(group["name"])
		# The one they are already on says what they are already doing, so the
		# list answers "what is this person up to" without being opened twice.
		if key == doing:
			row.aside(ActivityText.of(_creature.activity))
		var button := Icons.on(Atoms.button("Choose", false), &"choose")
		button.pressed.connect(func() -> void: _went_for(key))
		row.act(button)
		_body.add_child(row)


## The second question: which of them.
func _ask_which_job() -> void:
	_head.set_title(ActivityMenu.name_of(_group))
	var back := Icons.on(Atoms.quiet("Back"), &"back", Palette.TEXT_DIM)
	back.pressed.connect(func() -> void:
		_group = &""
		_refresh())
	_body.add_child(back)
	for job: StringName in ActivityMenu.jobs_in(_group):
		# The one they are on already is the filled button, which is how the
		# original marks it — set_color(...,cr->activity.type==ACTIVITY_X) is a
		# highlight on the line they are on.
		var button := Atoms.primary(ActivityText.of(job)) \
				if job == _creature.activity \
				else Atoms.wrapped_button(Atoms.button(ActivityText.of(job)))
		button.pressed.connect(func() -> void: _settle(job))
		_body.add_child(button)


## A category was pressed. One that holds a single job is that job.
func _went_for(key: StringName) -> void:
	if ActivityMenu.settles_it(key):
		_settle(ActivityMenu.jobs_in(key)[0])
		return
	_group = key
	_refresh()


func _settle(job: StringName) -> void:
	chosen.emit(_creature, job)
	closed.emit()
