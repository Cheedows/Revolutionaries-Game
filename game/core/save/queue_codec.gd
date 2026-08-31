class_name QueueCodec
extends RefCounted
## The things the game is part-way through: tomorrow's paper, the evenings out
## the squad has arranged, and the people it has agreed to meet.

const STORY_PLAIN: Array[StringName] = [
	&"location", &"priority", &"page", &"guardian_page", &"politics_level",
	&"violence_level", &"claimed", &"positive", &"siege_type",
]

const DATE_PLAIN: Array[StringName] = [
	&"dater_id", &"time_left", &"city", &"over",
]

const MEETING_PLAIN: Array[StringName] = [
	&"recruit_id", &"recruiter_id", &"time_left", &"level", &"eagerness",
]


static func news_to_array(game: GameState) -> Array:
	var encoded := []
	for story: NewsStory in game.news:
		encoded.append(story_to_dict(story))
	return encoded


static func news_from_array(recorded: Array) -> Array[NewsStory]:
	var stories: Array[NewsStory] = []
	for entry: Dictionary in recorded:
		stories.append(story_from_dict(entry))
	return stories


static func story_to_dict(story: NewsStory) -> Variant:
	if story == null:
		return null
	var recorded := {}
	for field: StringName in STORY_PLAIN:
		recorded[String(field)] = story.get(field)
	recorded["type"] = String(story.type)
	recorded["view"] = String(story.view)
	recorded["creature_ids"] = Array(story.creature_ids)
	recorded["crimes"] = Array(story.crimes)
	return recorded


static func story_from_dict(recorded: Variant) -> NewsStory:
	if recorded == null:
		return null
	var fields: Dictionary = recorded
	var story := NewsStory.new()
	for field: StringName in STORY_PLAIN:
		if fields.has(String(field)):
			story.set(field, fields[String(field)])
	story.type = StringName(fields["type"])
	story.view = StringName(fields["view"])
	story.creature_ids = SaveNumbers.ints(fields["creature_ids"])
	story.crimes = SaveNumbers.ints(fields["crimes"])
	return story


## Where the story being written now sits in the queue, or -1 when there is
## none. Written as an index so that loading restores the same object the queue
## holds rather than a copy of it.
static func current_story_index(game: GameState) -> int:
	if game.current_story == null:
		return -1
	return game.news.find(game.current_story)


static func dates_to_array(game: GameState) -> Array:
	var encoded := []
	for plan: DatePlan in game.dates:
		var recorded := {}
		for field: StringName in DATE_PLAIN:
			recorded[String(field)] = plan.get(field)
		recorded["date_ids"] = Array(plan.date_ids)
		encoded.append(recorded)
	return encoded


static func dates_from_array(recorded: Array) -> Array[DatePlan]:
	var plans: Array[DatePlan] = []
	for entry: Dictionary in recorded:
		var plan := DatePlan.new()
		for field: StringName in DATE_PLAIN:
			if entry.has(String(field)):
				plan.set(field, entry[String(field)])
		plan.date_ids = SaveNumbers.ints(entry["date_ids"])
		plans.append(plan)
	return plans


static func meetings_to_array(game: GameState) -> Array:
	var encoded := []
	for meeting: RecruitState in game.recruit_meetings:
		var recorded := {}
		for field: StringName in MEETING_PLAIN:
			recorded[String(field)] = meeting.get(field)
		recorded["task"] = String(meeting.task)
		encoded.append(recorded)
	return encoded


static func meetings_from_array(recorded: Array) -> Array[RecruitState]:
	var meetings: Array[RecruitState] = []
	for entry: Dictionary in recorded:
		var meeting := RecruitState.new()
		for field: StringName in MEETING_PLAIN:
			if entry.has(String(field)):
				meeting.set(field, entry[String(field)])
		meeting.task = StringName(entry["task"])
		meetings.append(meeting)
	return meetings
