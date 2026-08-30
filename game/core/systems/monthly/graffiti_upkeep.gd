class_name GraffitiUpkeep
extends RefCounted
## What happens to a month's worth of tags on a wall.
##
## Ports the graffiti block of passmonth() from src/monthly/monthly.cpp. A tag
## somewhere secure is scrubbed off within the month, but it is seen by enough
## people on the way out to be worth five times what a lasting one is. A tag
## somewhere nobody polices stays up, quietly influencing passers-by, until
## somebody paints over it — or claims it.

## What a tag is worth to the month's influence: a lasting one, and one that
## was scrubbed off but seen by everybody first.
const LASTING_POWER := 1
const SCRUBBED_POWER := 5

## The odds, per month, that a lasting tag is claimed by somebody else, claimed
## by the Conservative Crime Squad, or simply painted over.
const OTHER_ODDS := 10
const CCS_ODDS := 10
const CLEANED_ODDS := 30

## The three tags, and which side each speaks for.
const OURS := &"graffiti"
const THEIRS := &"graffiti_ccs"
const NOBODY := &"graffiti_other"


## Works over every wall in the world. Returns the events.
static func run(state: GameState, rng: Rng) -> Array[Event]:
	var ours := Tables.SITE_BLOCKS[OURS]
	var theirs := Tables.SITE_BLOCKS[THEIRS]
	var nobody := Tables.SITE_BLOCKS[NOBODY]
	var tags := [ours, theirs, nobody]
	var events: Array[Event] = []

	for id: int in state.locations:
		var site: Location = state.locations[id]
		# Walked from the back, because a tag can be removed as it is read.
		for index in range(site.changes.size() - 1, -1, -1):
			var change: SiteChange = site.changes[index]
			if not tags.has(change.flag):
				continue
			var side := 0
			if change.flag == ours:
				side = 1
			elif change.flag == theirs:
				side = -1
			var power := 0

			if SitePlans.SECURITY.get(site.type, 0) != 0:
				# Somewhere with guards: gone by the end of the month, but
				# everybody who works there saw it.
				site.changes.remove_at(index)
				power = SCRUBBED_POWER
			elif site.renting == Renting.CCS:
				# On their own wall, it is their tag now.
				change.flag = theirs
			elif site.renting == Renting.PERMANENT:
				change.flag = ours
			else:
				power = LASTING_POWER
				if rng.one_in(OTHER_ODDS):
					change.flag = nobody
				if rng.one_in(CCS_ODDS) and _ccs_is_active(state):
					change.flag = theirs
				if rng.one_in(CLEANED_ODDS):
					site.changes.remove_at(index)

			if side != 0:
				# A tag argues for one organisation and against the other, and
				# the same number does both.
				var squad := Ids.VIEWS.find(&"liberalcrimesquad")
				var other := Ids.VIEWS.find(&"conservativecrimesquad")
				state.opinion.background_influence[squad] += power * side
				state.opinion.background_influence[other] += power * side
	return events


## Whether the Conservative Crime Squad is around to claim anything: they have
## to have appeared, and not yet been beaten.
static func _ccs_is_active(state: GameState) -> bool:
	var stage := Ids.ENDGAME_STATES.find(state.endgame_state)
	return stage > 0 and stage < Ids.ENDGAME_STATES.find(&"ccs_defeated")
