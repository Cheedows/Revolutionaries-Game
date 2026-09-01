extends TestCase
## Everything the simulation reports, the interface has to say.
##
## `core/` emits structured Events and never words; `EventText` turns them into
## the lines the log shows. An event type with no branch there falls through
## and returns "", so the simulation reports something and the player is never
## told — which is not a crash, a failing assertion or anything else that shows
## up on its own.
##
## So this plays the game, collects every kind of event it actually produced,
## and requires each to have words. Anything deliberately silent is listed
## below with the reason, and the list is the audit.

const SEEDS: Array[int] = [1, 777, 12345]
const DAYS := 400
const PATIENCE := 400

## How long the raids are followed for afterwards: long enough for the arrests
## to reach a courtroom and the heat to bring the police to the door.
const AFTERMATH := 120

## What the player always says yes to, so the recruitment events happen.
const ALWAYS_TAKE: Array = [RecruitMeeting.OFFER_TO_JOIN]

## Every kind of event this case produced. Each case asserts a floor on it, so
## a change that quietly stops the run reaching the fighting, or the courts, or
## the recruiting, fails here rather than passing on an empty sweep.
var _kinds := {}

## What the log deliberately keeps quiet about, and why. A kind of event that
## is only silent in some of its shapes is listed by the shape, so adding a new
## one is still caught.
const SILENT := {
	"game_started": "there is nothing to say about a game beginning",
	"day_advanced": "the date is already on screen",
	"headline_run": "the paper is a panel; the log would only repeat it",
	"news_published": "as above",
	"news_segment": "as above — the television is read in the paper panel",
	"opinion_shifted:0": "opinion did not move",
	"law_changed:held": "the law did not move and nothing said why",
	"major_event:crime_suspected": "the heat readout says this better",
	"major_event:moved_house": "their record says where they live",
	"major_event:crime_unprosecuted": "nothing was booked, so nothing happened",
	"squad_moved": "the floor plan shows where they are",
	"creature_trained": "practice is constant and says nothing; the skill "
			+ "going up is what the log reports",
	"attack_resolved": "a marker the rules read, not a blow: the swing that "
			+ "caused it has already been described",
}


func test_everything_the_day_reports_has_words() -> void:
	var silent := {}
	var seen := 0
	for seed_value in SEEDS:
		var session := Session.new(seed_value)
		Commands.start_new_game(session, PackedInt32Array(),
				{&"win_condition": &"elite_liberal",
				&"field_skill_rate": &"fast"})
		_gather(session, session.drain_events(), silent)

		for day in DAYS:
			_put_everybody_to_work(session, day)
			Commands.advance_day(session, false)
			var asked := 0
			while session.is_waiting() and asked < PATIENCE:
				asked += 1
				session.answer(_pick(session.pending().intent))
			if session.is_waiting():
				fail("seed %d day %d would not stop asking" % [seed_value, day])
				return
			seen += _gather(session, session.drain_events(), silent)

	check(seen > 100, "the run produced something to look at, got %d" % seen)
	check(_kinds.size() >= 40,
			"the year reached most of what the day can report, got %d kinds"
					% _kinds.size())
	var unexplained: Array[String] = []
	for shape: String in silent:
		if not SILENT.has(shape):
			unexplained.append(shape)
	unexplained.sort()
	check(unexplained.is_empty(),
			"the log says nothing about: %s" % ", ".join(unexplained))


## And the modes a run cannot be steered into: a hostage in the basement, a
## date in the diary, and a Liberal in the cells.
##
## These are fixtures rather than play, because a scripted run reaches them
## only by luck: somebody has to be kidnapped, somebody has to be flirted with
## at a site, and somebody has to be arrested and charged with enough to stand
## trial. Each is set up directly and then the days are run.
func test_everything_the_other_modes_report_has_words() -> void:
	var silent := {}
	var seen := 0
	for seed_value in SEEDS:
		var session := Session.new(seed_value)
		Commands.start_new_game(session, PackedInt32Array(),
				{&"win_condition": &"elite_liberal",
				&"field_skill_rate": &"fast"})
		session.drain_events()
		var founder: Creature = session.state.members()[0]
		founder.juice = 1000
		_take_a_hostage(session, founder)
		_arrange_a_date(session, founder)
		_get_somebody_arrested(session, founder)

		for day in AFTERMATH:
			Commands.advance_day(session, false)
			var asked := 0
			while session.is_waiting() and asked < PATIENCE:
				asked += 1
				session.answer(_pick(session.pending().intent))
			if session.is_waiting():
				fail("seed %d day %d would not stop asking" % [seed_value, day])
				return
			seen += _gather(session, session.drain_events(), silent)

	check(seen > 100, "the fixtures produced something to look at, got %d" % seen)
	check(_kinds.size() >= 25,
			"they reached the cells, the diary and the basement, got %d kinds"
					% _kinds.size())
	var unexplained: Array[String] = []
	for shape: String in silent:
		if not SILENT.has(shape):
			unexplained.append(shape)
	unexplained.sort()
	check(unexplained.is_empty(),
			"the log says nothing about: %s" % ", ".join(unexplained))


## Somebody Conservative, tied up in the safehouse, with a guard on them.
func _take_a_hostage(session: Session, founder: Creature) -> void:
	var hostage := session.state.add_creature(Creature.new())
	hostage.name = "The Guest"
	hostage.type = &"CREATURE_CORPORATE_MANAGER"
	hostage.alignment = &"conservative"
	hostage.location = founder.location
	hostage.base = founder.base
	hostage.work_location = founder.location
	hostage.kidnapped = true
	hostage.missing = true
	hostage.interrogation = Interrogation.new()
	Commands.watch_hostage(session, founder, hostage)


## Somebody the founder is seeing, which is how the original starts a date:
## a copy of a stranger, on the founder's own list.
func _arrange_a_date(session: Session, founder: Creature) -> void:
	var date := session.state.add_creature(Creature.new())
	date.name = "The Date"
	date.type = &"CREATURE_TEACHER"
	date.alignment = &"moderate"
	date.location = founder.location
	date.base = founder.base
	var here: Location = session.state.locations.get(founder.location)
	var plan := DatePlan.new()
	plan.dater_id = founder.id
	plan.city = here.city if here != null else -1
	plan.date_ids.append(date.id)
	session.state.dates.append(plan)
	founder.dating = 0


## A Liberal in the cells with enough against them to reach a courtroom.
func _get_somebody_arrested(session: Session, founder: Creature) -> void:
	var caught := session.state.add_creature(Creature.new())
	caught.name = "The Accused"
	caught.alignment = &"liberal"
	caught.enlisted = true
	caught.hire_id = founder.id
	caught.recruiter_id = founder.id
	caught.base = founder.base
	for crime in [&"murder", &"racketeering", &"burglary"]:
		caught.crimes_suspected[Ids.LAW_FLAGS.find(crime)] = 2
	for site: Location in session.state.locations.values():
		if site.type == &"government_policestation":
			caught.location = site.id
			break


## Gives everybody idle something different to do.
##
## One assignment does not exercise the day: graffiti, hacking, busking, the
## clinic, teaching and the rest each report their own things, and a roster all
## doing the same job never produces any of it. The rotation moves with the
## day, so over a year every job on the list is done by somebody.
func _put_everybody_to_work(session: Session, day: int) -> void:
	var jobs := ActivityAssignment.AVAILABLE
	var offered := Recruiting.recruitable(session.state)
	var index := day
	for creature: Creature in session.state.creatures.values():
		if not creature.is_member() or creature.location == -1:
			continue
		# Reassigned every day rather than only when idle: an assignment
		# sticks, so a roster told once spends the whole year doing that one
		# thing and the day never reports anything else.
		if creature.sleeper:
			SleeperOrders.give(session.state, creature, &"sleeper_liberal")
			continue
		index += 1
		# One in three goes recruiting, which is the only job that grows the
		# organisation and so the only one that keeps the rest staffed.
		if index % 3 == 0:
			Commands.recruit_for(session, creature,
					StringName(offered[0]["type"]))
			continue
		var job: StringName = jobs[index % jobs.size()]
		if job == &"none":
			continue
		Commands.assign_activity(session, creature, job)
		if job == &"make_armor":
			var garments := AssignmentChoice.garments(session.state,
					session.catalog)
			if not garments.is_empty():
				AssignmentChoice.choose(creature, job, garments[0])
		elif job == &"hostagetending":
			Commands.watch_hostage(session, creature)


## Describes each event and notes the ones that came out empty.
func _gather(session: Session, events: Array[Event],
		silent: Dictionary) -> int:
	for event in events:
		_kinds[event.type] = true
		if EventText.describe(event, session.state).strip_edges().is_empty():
			silent[_shape(event)] = true
	return events.size()


## What to call one silent event: its type, and for the kinds that are only
## silent in some shapes, which shape.
func _shape(event: Event) -> String:
	match event.type:
		Event.MAJOR_EVENT:
			return "major_event:%s" % event.data.get("kind", "")
		Event.OPINION_SHIFTED:
			return "opinion_shifted:%d" % int(event.data.get("amount", 0))
		Event.LAW_CHANGED:
			if int(event.data.get("from", 0)) == int(event.data.get("to", 0)):
				return "law_changed:%s" % String(
						event.data.get("outcome", &"held"))
			return "law_changed"
	return String(event.type)


## The same sweep for what happens inside a building, which a year at the
## safehouse never reaches: the encounters, the fighting, the specials and the
## way out.
func test_everything_a_visit_reports_has_words() -> void:
	var visits: Object = (load("res://tests/unit/test_site_visit.gd") as GDScript).new()
	var script: Array[int] = visits.WANDER
	var silent := {}
	var seen := 0
	for building: StringName in visits.BUILDINGS:
		for seed_value: int in visits.SEEDS:
			var session: Session = visits._visit(seed_value, script, false,
					building)
			if session == null:
				fail("a visit to a %s could not be walked" % building)
				return
			seen += _gather(session, session.drain_events(), silent)
	check(seen > 40, "the visits produced something to look at, got %d" % seen)
	check(_kinds.size() >= 15,
			"the visits reached the site loop properly, got %d kinds"
					% _kinds.size())

	var unexplained: Array[String] = []
	for shape: String in silent:
		if not SILENT.has(shape):
			unexplained.append(shape)
	unexplained.sort()
	check(unexplained.is_empty(),
			"the log says nothing about: %s" % ", ".join(unexplained))


## And the same for what a raid sets off: the shooting, the arrests, the trial
## that follows, and the siege the heat brings to the door. None of it happens
## to a squad that stays at home and behaves.
func test_everything_a_raid_reports_has_words() -> void:
	var visits: Object = (load("res://tests/unit/test_site_visit.gd") as GDScript).new()
	var raid: Array[int] = [
		SiteLoop.MOVE_DOWN, SiteLoop.FIGHT, SiteLoop.FIGHT, SiteLoop.MOVE_DOWN,
		SiteLoop.FIGHT, SiteLoop.GRAB, SiteLoop.FIGHT, SiteLoop.MOVE_LEFT,
		SiteLoop.FIGHT, SiteLoop.TAKE,
	]
	var silent := {}
	var seen := 0
	for building: StringName in [&"government_policestation",
			&"corporate_headquarters", &"business_bank"]:
		for seed_value in [1, 7, 99]:
			var session: Session = visits._visit(seed_value, raid, false,
					building, true)
			if session == null:
				fail("a raid on a %s could not be walked" % building)
				return
			seen += _gather(session, session.drain_events(), silent)
			# The months afterwards, which is where the consequences are.
			for day in AFTERMATH:
				Commands.advance_day(session, false)
				var asked := 0
				while session.is_waiting() and asked < PATIENCE:
					asked += 1
					session.answer(_pick(session.pending().intent))
				if session.is_waiting():
					fail("%s seed %d day %d would not stop asking"
							% [building, seed_value, day])
					return
				seen += _gather(session, session.drain_events(), silent)
	check(seen > 200, "the raids produced something to look at, got %d" % seen)
	check(_kinds.size() >= 25,
			"the raids reached the fighting and what follows it, got %d kinds"
					% _kinds.size())

	var unexplained: Array[String] = []
	for shape: String in silent:
		if not SILENT.has(shape):
			unexplained.append(shape)
	unexplained.sort()
	check(unexplained.is_empty(),
			"the log says nothing about: %s" % ", ".join(unexplained))


func _pick(intent: Intent) -> Variant:
	var chosen: Variant = null
	for option: Dictionary in intent.options:
		if not bool(option.get("enabled", true)):
			continue
		if chosen == null or ALWAYS_TAKE.has(option["id"]):
			chosen = option["id"]
	return chosen
