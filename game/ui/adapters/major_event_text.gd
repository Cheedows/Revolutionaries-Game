class_name MajorEventText
extends RefCounted
## The words of a major event's story.
##
## Says what core/systems/news/major_event_*.gd rolled. Everything here is
## presentation: the slots carry the names, times and choices, and the clauses
## that turn on the law are decided here, because a law is state the interface
## can read for itself.
##
## The text is the original's, from constructeventstory() in
## src/news/majorevent.cpp, and is compared against it by tests/unit's
## newsprose case. "&r" is the original's paragraph mark and is kept, so the
## comparison is exact and a reader can lay the story out however it likes.

## The original's paragraph mark.
const BREAK := "&r"


## The story for [param view], or "" for an event the original never wrote one
## for.
static func describe(state: GameState, view: StringName, good: bool,
		slots: Dictionary) -> String:
	if slots.is_empty():
		return ""
	if good:
		return MajorEventGoodText.describe(state, view, slots)
	return MajorEventBadText.describe(state, view, slots)
