class_name Card
extends PanelContainer
## A panel with a title, something to read, and a way out.
##
## Ten panels wrote this out: a stylebox, a column, a [PanelHeader], a
## [ScrollContainer] with horizontal scrolling off and vertical fill on, and a
## body column inside it. Identical every time, because it is the same thing
## every time — a card is what a panel *is* in this interface, and the panels
## differ only in what they put in the body.
##
## So they extend this instead. What a panel now writes is its own content.
##
## Four regions, in the order they are read:
##
##   the head     what this is, and the way out    [PanelHeader]
##   the notice   why the last thing did not work  hidden until there is one
##   the body     the content, and the only thing that scrolls
##   the actions  what can be done here            hidden until something is
##
## The body is the only part that scrolls, so the title stays put and the
## actions stay reachable — the rule the new-game screen's Continue button was
## breaking when it was drawn below the bottom of the phone.

## Emitted when the player is finished with the card.
signal closed

var _head: PanelHeader
var _notice: Label
var _body: VBoxContainer
var _actions: ActionBar


## Builds the card, once. Safe to call from anywhere; a panel calls it at the
## top of whatever fills it in.
func card() -> void:
	if _body != null:
		return
	add_theme_stylebox_override(&"panel", UiTheme.panel())
	var column := Atoms.column(Metrics.TIGHT)
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(column)

	_head = PanelHeader.new()
	_head.closed.connect(func() -> void: closed.emit())
	column.add_child(_head)

	# Kept between the title and the body rather than beside the thing that
	# refused, because the thing that refused is often a button too small to
	# hang a sentence off, and because a message that appears in a different
	# place each time is a message nobody learns where to look for.
	_notice = Atoms.wrapped(Atoms.tinted("", Palette.CONSERVATIVE))
	_notice.visible = false
	column.add_child(_notice)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Off until somebody says otherwise. A card that is not on screen is not a
	# thing that scrolls, and a phone is supposed to have exactly one of those;
	# the [Sheet] switches this on when it brings the card to the front.
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	_body = Atoms.column(0)
	scroll.add_child(_body)

	_actions = ActionBar.new()
	_actions.visible = false
	column.add_child(_actions)


## What this card is called.
func title(said: String) -> void:
	card()
	_head.set_title(said)


## Empties the body, ready to be filled in again.
func empty() -> void:
	card()
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_notice.visible = false


## Puts [param control] in the body.
func hold(control: Control) -> void:
	card()
	_body.add_child(control)


## What this card says when there is nothing in it.
##
## Not a line of the body's prose, which is what three panels were using and is
## why an empty list looked like a list with one thing in it.
func says_nothing(said: String) -> void:
	hold(Atoms.nothing(said))


## Says why the last thing did not work, until the body is emptied again.
func refuse(said: String) -> void:
	card()
	_notice.text = said
	_notice.visible = said != ""


## Puts an action in the bar under the body, where it does not scroll away.
func act(button: Button) -> void:
	card()
	_actions.add(button)
	_actions.visible = true


## Whether the card is being drawn for a fingertip.
func compact(on: bool) -> void:
	card()
	_actions.adapt(on)
