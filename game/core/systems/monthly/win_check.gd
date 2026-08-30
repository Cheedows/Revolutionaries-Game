class_name WinCheck
extends RefCounted
## Whether the Liberal agenda has actually been achieved.
##
## Ports wincheck() from src/politics/politics.cpp. Winning takes all three
## branches at once, which is why the game is long: the executive entirely, the
## laws, both chambers, and the court.
##
## Two win conditions. The strict one demands every law and every branch at the
## Elite Liberal end. The relaxed one accepts Liberal laws provided at least
## half are Elite Liberal, and counts Liberal seats as half an Elite Liberal one
## — a country persuaded rather than converted.

const HOUSE_MAJORITY := 218
const HOUSE_COMFY_MAJORITY := 261
const HOUSE_SUPERMAJORITY := 290
const SENATE_MAJORITY := 51
const SENATE_COMFY_MAJORITY := 60
const SENATE_SUPERMAJORITY := 67
const COURT_MAJORITY := 5
const COURT_SUPERMAJORITY := 6


## Whether the game has been won.
static func is_won(state: GameState) -> bool:
	var elite := state.win_condition == &"elite_liberal"

	# The executive, entirely.
	for post in state.government.executive:
		if post < Alignment.ELITE_LIBERAL:
			return false

	if not _laws_won(state, elite):
		return false
	if not _house_won(state, elite):
		return false
	if not _senate_won(state, elite):
		return false
	return _court_won(state, elite)


## Whether the laws are where the win condition wants them.
##
## This reproduces a dangling-else bug in the original, deliberately. The source
## reads:
##
##     if(wincondition==WINCONDITION_ELITE)
##        for(int l=0;l<LAWNUM;l++) if(law[l]<ALIGN_ELITELIBERAL) return 0;
##     else { ...the relaxed check... }
##
## The [code]else[/code] binds to the inner [code]if[/code], not the outer one.
## So under the relaxed win condition the laws are never examined at all — a
## player can win it with the country's laws untouched, provided they hold the
## executive, both chambers and the court. Under the strict condition the
## relaxed block runs *inside* the loop, as a redundant extra check.
##
## Reproduced because parity comes first. It is recorded in
## docs/port/PHASE2-STATUS.md as a bug to decide about, not to keep by default.
static func _laws_won(state: GameState, elite: bool) -> bool:
	if not elite:
		return true  # the original never gets here — see above

	for value in state.law.values:
		if value < Alignment.ELITE_LIBERAL:
			return false
		if not _relaxed_laws_won(state):
			return false
	return true


## The check the original meant to run for the relaxed condition, and which in
## fact only ever runs nested inside the strict one.
static func _relaxed_laws_won(state: GameState) -> bool:
	var liberal := 0
	var elite_liberal := 0
	for value in state.law.values:
		if value < Alignment.LIBERAL:
			return false
		if value == Alignment.LIBERAL:
			liberal += 1
		else:
			elite_liberal += 1
	# At least half the won laws must be Elite Liberal, not merely Liberal.
	return elite_liberal >= liberal


static func _house_won(state: GameState, elite: bool) -> bool:
	var seats := _tally(state.government.house)
	var combined: int = seats[Alignment.ELITE_LIBERAL] + seats[Alignment.LIBERAL] / 2
	if combined < (HOUSE_SUPERMAJORITY if elite else HOUSE_COMFY_MAJORITY):
		return false
	var elite_seats: int = seats[Alignment.ELITE_LIBERAL]
	return elite_seats >= (HOUSE_COMFY_MAJORITY if elite else HOUSE_MAJORITY)


static func _senate_won(state: GameState, elite: bool) -> bool:
	var seats := _tally(state.government.senate)
	var combined: int = seats[Alignment.ELITE_LIBERAL] + seats[Alignment.LIBERAL] / 2
	if combined < (SENATE_SUPERMAJORITY if elite else SENATE_COMFY_MAJORITY):
		return false
	if not elite:
		# Under the relaxed condition the Vice President counts as a senator,
		# but only for breaking a tie — so after the halving, not before.
		var vice: int = state.government.executive[1]
		seats[vice] = seats.get(vice, 0) + 1
	var elite_seats: int = seats[Alignment.ELITE_LIBERAL]
	return elite_seats >= (SENATE_COMFY_MAJORITY if elite else SENATE_MAJORITY)


static func _court_won(state: GameState, elite: bool) -> bool:
	var seats := _tally(state.government.court)
	var elite_seats: int = seats[Alignment.ELITE_LIBERAL]
	if elite_seats >= COURT_MAJORITY:
		return true
	if elite:
		return false
	var liberal_seats: int = seats[Alignment.LIBERAL]
	return elite_seats + liberal_seats / 2 >= COURT_SUPERMAJORITY


## Seats by alignment.
static func _tally(chamber: PackedInt32Array) -> Dictionary:
	var counts := {}
	for alignment in Alignment.NAMES:
		counts[alignment] = 0
	for seat in chamber:
		counts[seat] = counts.get(seat, 0) + 1
	return counts
