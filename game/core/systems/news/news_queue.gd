class_name NewsQueue
extends RefCounted
## The story being written right now.
##
## Ports the `sitestory` global from src/externs.h. Everything the game does
## that a reporter might care about — a chase through the streets, a body, a
## reactor shut down — is written onto whichever story is currently open, and
## the arrests and raids that start those events are what open one.
##
## The original never closes a story: `sitestory` keeps pointing at it after
## the paper has run and freed it, so the next day's crimes are written into
## freed memory and `attemptarrest()`'s "only if nothing is open" guard never
## fires again. That is a defect rather than a rule, so here the paper closes
## the story it printed. The visible difference is that the catch-all arrest
## story can be opened again on a later day, which is plainly what the guard
## was for.


## Opens a story of [param type] about [param location] and makes it the one
## being written. Returns it.
static func open(state: GameState, type: StringName, location: int = -1,
		claimed: int = -1, positive: int = -1) -> NewsStory:
	var story := NewsStory.new()
	story.type = type
	story.location = location
	if claimed != -1:
		story.claimed = claimed
	if positive != -1:
		story.positive = positive
	state.news.append(story)
	state.current_story = story
	return story


## Opens a story only if nothing is being written, as `attemptarrest()` does.
static func open_if_idle(state: GameState, type: StringName) -> NewsStory:
	if state.current_story != null:
		return state.current_story
	return open(state, type)


## Writes [param crime] onto the open story, if there is one.
static func record(state: GameState, crime: StringName) -> void:
	if state.current_story == null:
		return
	state.current_story.crimes.append(Ids.CRIMES.find(crime))


## The squad admitting to what it is doing, which doubles the story.
static func claim(state: GameState, level: int) -> void:
	if state.current_story != null:
		state.current_story.claimed = level
