class_name BaseOrders
extends RefCounted
## Telling somebody in the safehouse what to do, and closing the book on them.
##
## The roster is a list of people with a picker beside each; this is what the
## picker means. Kept apart from base_screen.gd for the same reason the layout
## is: what the screen looks like, what it does, and what an order actually
## costs are three separate jobs.
##
## Each of these hands back the lines to write in the log rather than writing
## them, so nothing here has to know there is a log.


## How each ending reads, from the high score table in src/title/highscore.cpp.
## The original writes the month and year after each of these; the port writes
## the date on its own line, where a phone can wrap it.
const ENDINGS := {
	&"won": "The Liberal Crime Squad liberalized the country",
	&"police": "The Liberal Crime Squad was brought to justice",
	&"cia": "The Liberal Crime Squad was blotted out",
	&"hicks": "The Liberal Crime Squad was mobbed",
	&"corporate": "The Liberal Crime Squad was downsized",
	&"dead": "The Liberal Crime Squad was KIA",
	&"prison": "The Liberal Crime Squad died in prison",
	&"executed": "The Liberal Crime Squad was executed",
	&"dating": "The Liberal Crime Squad was on vacation",
	&"hiding": "The Liberal Crime Squad was in permanent hiding",
	&"disbanded": "The Liberal Crime Squad was hunted down",
	&"dispersed": "The Liberal Crime Squad was scattered",
	&"ccs": "The Liberal Crime Squad was out-Crime Squadded",
	&"firemen": "The Liberal Crime Squad was burned",
	&"reagan": "The country was Reaganified",
	&"stalin": "The country was Stalinized",
}


## Closes a finished game: the score goes in the book, and the lines to say so
## come back.
##
## [param won] is whether the squad won; when it did not, what finished them is
## worked out here rather than passed in.
static func finish(session: Session, won: bool) -> PackedStringArray:
	var ending: StringName = &"won" if won else EndCheck.cause(session.state)
	var place := ScoreFile.finish(session, ending)
	var said := PackedStringArray()
	said.append(String(ENDINGS.get(ending, ENDINGS[&"dead"])))
	if place >= 0:
		said.append("The Liberal ELITE  %d" % (place + 1))
	return said


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
		# "will be", not "will": every activity name in this game is a gerund
		# — Selling Music, Laying Low, Community Service — so "Scruffy will
		# selling music" is what the other shape produces. This is the same
		# wording the sleeper orders already use.
		said.append("%s will be %s." % [creature.name,
				ActivityText.of(activity)])
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
		said.append("%s will try to meet and recruit %s today." % [recruiter.name,
				String(type).trim_prefix("CREATURE_").to_lower()])
	return said


## Puts [param keeper] on the door of the room [param hostage] is held in.
static func watch(session: Session, keeper: Creature,
		hostage: Creature) -> PackedStringArray:
	var said := PackedStringArray()
	if Commands.watch_hostage(session, keeper, hostage):
		said.append("%s will be watching over %s." % [keeper.name, hostage.name])
	return said


## The game is over: says so in the log and turns the day button into the way
## out.
##
## Here rather than on the screen because it is the last order the session
## takes, and because base_screen.gd is a screen rather than a place to keep
## the rules about what happens at the end of one.
static func finish_up(session: Session, won: bool, log: LogView,
		day: Button, done: Callable) -> void:
	var said := finish(session, won)
	log.append_heading(said[0])
	for line in said.slice(1):
		log.append(line, Palette.ACCENT)
	day.text = "Live to fight EVIL another day"
	for existing in day.pressed.get_connections():
		day.pressed.disconnect(existing["callable"])
	day.pressed.connect(func() -> void: done.call())


## Whether the morning printed anything, and so whether the paper goes up on
## its own.
##
## The original does not wait to be asked. majornewspaper() runs inside the
## day, calls display_newspaper(), and that draws a page per story and holds
## each one until a key is pressed, so the paper is the one thing in this game
## a player cannot walk past. The port had it behind a button, on the
## reasoning that somebody who wants to read it wants to read it when they
## choose. What that produced was a log saying opinion had moved and the other
## side was getting stronger, with nothing anywhere saying why — the paper is
## where this game explains itself.
##
## The screen puts it up and stops the days running while it is there, for the
## same reason the original's page holds: a paper with the next day happening
## behind it would sit showing one morning's stories while the week went past.
static func worth_reading(morning: Array[Event]) -> bool:
	return not morning.is_empty()


## Empties the session's events into the log, and hands back the morning's
## paper.
##
## The paper is kept aside rather than only scrolling past in the log, because
## a player who wants to read it wants to read it when they choose.
static func drain(session: Session, log: LogView) -> Array[Event]:
	var drained := session.drain_events()
	var morning: Array[Event] = []
	for event: Event in drained:
		if event.type == Event.NEWS_PUBLISHED \
				or event.type == Event.HEADLINE_RUN \
				or event.type == Event.NEWS_SEGMENT:
			morning.append(event)
	for event in drained:
		var line := EventText.describe(event, session.state)
		if not line.is_empty():
			log.append(line, EventText.colour_of(event))
	return morning
