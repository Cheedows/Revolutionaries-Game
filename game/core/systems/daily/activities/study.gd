class_name StudyActivity
extends RefCounted
## Paying for lessons.
##
## Ports doActivityLearn() from src/daily/activities.cpp. Nothing here rolls:
## a day's tuition is bought, and how much of it sticks depends only on how
## much the student already knows.

## What a day of lessons costs, and what it is worth before the student's own
## ability is taken into account.
const TUITION := 60
const EFFECTIVENESS := 20

## What each course teaches.
const TEACHES: Dictionary = {
	&"study_debating": &"persuasion",
	&"study_martial_arts": &"handtohand",
	&"study_driving": &"driving",
	&"study_psychology": &"psychology",
	&"study_first_aid": &"firstaid",
	&"study_law": &"law",
	&"study_disguise": &"disguise",
	&"study_science": &"science",
	&"study_business": &"business",
	&"study_gymnastics": &"dodge",
	&"study_locksmithing": &"security",
	&"study_music": &"music",
	&"study_art": &"art",
	&"study_teaching": &"teaching",
	&"study_writing": &"writing",
	&"study_computers": &"computers",
}


## The day's classes. Returns the events.
##
## Walked from the back of the list forwards, and the money runs out rather
## than being shared: once the organisation cannot afford one more day of
## tuition, everybody still waiting simply does not go.
static func run(state: GameState, rng: Rng, students: Array[Creature]) -> Array[Event]:
	var events: Array[Event] = []
	var order := students.duplicate()
	order.reverse()

	for student: Creature in order:
		if not state.ledger.can_afford(TUITION):
			break
		state.ledger.subtract(TUITION, &"training")
		events.append(Event.new(Event.FUNDS_SPENT,
				{"amount": TUITION, "purpose": &"training"}))

		var skill: StringName = TEACHES.get(student.activity, &"")
		if skill == &"":
			continue
		# The better they are, the less a day is worth — sharply so.
		var worth := maxi(EFFECTIVENESS / (student.skills.get_value(skill) + 1), 1)
		TrainRules.train(student, skill, worth)
		events.append(Event.new(Event.CREATURE_TRAINED,
				{"creature": student.id, "skill": skill, "amount": worth}))

		if student.skills.get_value(skill) >= TrainRules.skill_cap(student, skill, true):
			student.activity = &"none"
			events.append(Event.new(Event.STUDY_FINISHED,
					{"creature": student.id, "skill": skill}))
	return events
