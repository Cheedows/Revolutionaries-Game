class_name KitButtons
extends VBoxContainer
## The four things that can be done to what somebody is carrying.
##
## A column, because all four are whole sentences — the original writes them as
## lettered lines down the equip screen and they are that long. Side by side
## they are wider than a phone put together; wrapped inside a row they collapse
## to the width of their longest word. One under another, each as wide as the
## panel, is the shape the original already has.
##
## Taking a weapon back, taking the clothes back, handing over ammunition that
## fits, and handing one clip back — the equip screen's own keys, from
## src/common/equipment.cpp. Its own widget because the record it sits under is
## long enough already.

## Emitted when something moved between the person and the kit.
signal changed

## Emitted when a thing could not be done, with the reason.
signal refused(reason: String)


## Builds the row for [param member].
func show_member(session: Session, member: Creature) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	add_theme_constant_override(&"separation", Metrics.TIGHT)

	_add("Drop that Squad member's Conservative weapon", member.weapon == null,
			func() -> String:
				KitCommands.disarm(session, member)
				return "")
	_add("Receive a clip", member.weapon == null,
			func() -> String: return KitCommands.give_ammo(session, member))
	_add("Drop a clip", member.clips.is_empty(),
			func() -> String: return KitCommands.drop_a_clip(session, member))
	_add("Liberally Strip a Squad member", member.armor == null,
			func() -> String:
				KitCommands.strip(session, member)
				return "")


## One button, and what it says when it will not do it.
func _add(text: String, disabled: bool, act: Callable) -> void:
	var button := Atoms.wrapped_button(Atoms.button(text))
	button.disabled = disabled
	button.pressed.connect(func() -> void:
		var why: String = act.call()
		if why != "":
			refused.emit(why)
			return
		changed.emit())
	add_child(button)
