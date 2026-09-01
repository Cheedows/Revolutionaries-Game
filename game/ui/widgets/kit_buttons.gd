class_name KitButtons
extends HFlowContainer
## The four things that can be done to what somebody is carrying.
##
## A flow rather than a row: four buttons with real sentences on them do not
## fit across a phone, and wrapping onto a second line is the only answer that
## keeps all four reachable.
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
	add_theme_constant_override("separation", 8)

	_add("Take their weapon", member.weapon == null,
			func() -> String:
				KitCommands.disarm(session, member)
				return "")
	_add("Give them ammunition", member.weapon == null,
			func() -> String: return KitCommands.give_ammo(session, member))
	_add("Hand back a clip", member.clips.is_empty(),
			func() -> String: return KitCommands.drop_a_clip(session, member))
	_add("Take their clothes", member.armor == null,
			func() -> String:
				KitCommands.strip(session, member)
				return "")


## One button, and what it says when it will not do it.
func _add(text: String, disabled: bool, act: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.disabled = disabled
	button.pressed.connect(func() -> void:
		var why: String = act.call()
		if why != "":
			refused.emit(why)
			return
		changed.emit())
	add_child(button)
