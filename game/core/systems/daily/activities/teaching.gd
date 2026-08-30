class_name TeachingActivity
extends RefCounted
## Running a class at the safehouse.
##
## Ports doActivityTeach() from src/daily/activities.cpp. Nothing rolls: what a
## student learns is the gap between them and the teacher, and what it costs is
## how many turned up.

## What each class covers, and what a head costs to teach.
const COURSES: Dictionary = {
	&"teach_politics": {
		&"cost": 2,
		&"skills": [&"law", &"persuasion", &"writing", &"religion", &"business",
				&"science", &"streetsense", &"music", &"art"],
	},
	&"teach_covert": {
		&"cost": 6,
		&"skills": [&"security", &"computers", &"disguise", &"tailoring",
				&"stealth", &"seduction", &"psychology", &"driving"],
	},
	&"teach_fighting": {
		&"cost": 10,
		&"skills": [&"knife", &"sword", &"club", &"pistol", &"rifle", &"shotgun",
				&"heavyweapons", &"axe", &"smg", &"throwing", &"handtohand",
				&"dodge", &"firstaid"],
	},
}

## Past this many students a class stops costing more and starts teaching less.
const FULL_CLASS := 10

## How a crowded class dilutes a lesson: five eighths as fast at twice the size.
const CROWD_NUMERATOR := 30
const CROWD_DIVISOR := 4

## A lesson is worth at least this and at most this.
const LEAST := 1
const MOST := 10

## A student has to be this far behind the teacher to learn anything, and the
## teacher's own teaching skill sets how far behind is too far to help.
const BEHIND := 1
const REACH := 2


## The day's classes. Returns the events.
static func run(state: GameState, rng: Rng, teachers: Array[Creature]) -> Array[Event]:
	var events: Array[Event] = []
	for teacher: Creature in teachers:
		var course: Dictionary = COURSES.get(teacher.activity, {})
		if course.is_empty():
			continue
		var subjects: Array = course[&"skills"]
		var cost := int(course[&"cost"])

		# Counted first, because the bill is for the whole room and a class
		# nobody can pay for does not happen at all.
		var places := 0
		for student: Creature in _class_of(state, teacher):
			for subject: StringName in subjects:
				if _has_something_to_learn(student, teacher, subject):
					places += 1
		if not state.ledger.can_afford(mini(places, FULL_CLASS) * cost):
			continue

		for student: Creature in _class_of(state, teacher):
			for subject: StringName in subjects:
				if not _has_something_to_learn(student, teacher, subject):
					continue
				var lesson := teacher.skills.get_value(subject) \
						+ teacher.skills.get_value(&"teaching") \
						- student.skills.get_value(subject)
				if places > FULL_CLASS:
					lesson = (lesson * CROWD_NUMERATOR / places + lesson) / CROWD_DIVISOR
				lesson = clampi(lesson, LEAST, MOST)
				TrainRules.train(student, subject, lesson)

		var billed := cost * mini(places, FULL_CLASS)
		state.ledger.subtract(billed, &"training")
		TrainRules.train(teacher, &"teaching", mini(places, FULL_CLASS))
		events.append(Event.new(Event.CLASS_TAUGHT, {
			"creature": teacher.id, "course": teacher.activity,
			"places": places, "cost": billed,
		}))
	return events


## Everybody at the teacher's safehouse who might sit in.
##
## Note this counts the teacher too — they are at their own location, alive and
## Liberal — but they can never be behind themselves, so nothing comes of it.
static func _class_of(state: GameState, teacher: Creature) -> Array[Creature]:
	var room: Array[Creature] = []
	for person: Creature in state.creatures.values():
		if person.alive and person.alignment == &"liberal" \
				and person.location == teacher.location:
			room.append(person)
	return room


## Whether this student can learn this subject from this teacher today.
static func _has_something_to_learn(student: Creature, teacher: Creature,
		subject: StringName) -> bool:
	var known := student.skills.get_value(subject)
	return known < teacher.skills.get_value(subject) - BEHIND \
			and known < teacher.skills.get_value(&"teaching") + REACH \
			and known < TrainRules.skill_cap(student, subject, true)
