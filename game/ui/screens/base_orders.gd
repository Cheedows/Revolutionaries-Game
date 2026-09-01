class_name BaseOrders
extends RefCounted
## Telling somebody in the safehouse what to do.
##
## The roster is a list of people with a picker beside each; this is what the
## picker means. Kept apart from base_screen.gd for the same reason the layout
## is: what the screen looks like, what it does, and what an order actually
## costs are three separate jobs.
##
## Each of these hands back the lines to write in the log rather than writing
## them, so nothing here has to know there is a log.


## Puts [param creature] on [param activity].
##
## Two of the jobs need somebody or something named as well, which the original
## asks about on a screen of its own and the roster asks with a second picker.
## Both are given a default here so that choosing the job alone is never a
## half-order.
static func assign(session: Session, creature: Creature,
		activity: StringName) -> PackedStringArray:
	var said := PackedStringArray()
	for event in Commands.assign_activity(session, creature, activity):
		said.append("%s will %s." % [creature.name,
				ActivityText.of(activity).to_lower()])
	# Tending is the one job that needs somebody named as well. The original
	# picks for you when there is only one prisoner in the house, and asks
	# otherwise; the roster's picker is the asking.
	if activity == &"hostagetending":
		Commands.watch_hostage(session, creature)
	# So is recruiting: the first name on the list is the one the original
	# leaves the cursor on.
	elif activity == &"recruiting" and creature.recruiting == &"":
		var offered := Recruiting.recruitable(session.state)
		if not offered.is_empty():
			Commands.recruit_for(session, creature,
					StringName(offered[0]["type"]))
	return said


## Tells [param recruiter] what kind of person to go looking for.
static func recruit(session: Session, recruiter: Creature,
		type: StringName) -> PackedStringArray:
	var said := PackedStringArray()
	if Commands.recruit_for(session, recruiter, type):
		said.append("%s will look for %s." % [recruiter.name,
				String(type).trim_prefix("CREATURE_").to_lower()])
	return said


## Puts [param keeper] on the door of the room [param hostage] is held in.
static func watch(session: Session, keeper: Creature,
		hostage: Creature) -> PackedStringArray:
	var said := PackedStringArray()
	if Commands.watch_hostage(session, keeper, hostage):
		said.append("%s will watch over %s." % [keeper.name, hostage.name])
	return said
