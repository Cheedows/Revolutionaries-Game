class_name Tombstones
extends RefCounted
## Clears out the people the game has finished with.
##
## The original calls delete_and_remove() and the creature is gone from the
## pool that instant. The port marks them `exists = false` instead, because
## several systems read that flag before the turn is over — a prisoner who
## confessed, a body that has been buried, a recruit who was stood up. Nothing
## then took them off the board, so a long game accumulated hundreds of dead
## entries: a recruiter who finds five strangers a day and speaks to one leaves
## four behind every day for the rest of the game.
##
## This is that clean-up, run once at the end of the day, when nothing is left
## that wants to read the flag. It draws no dice and changes no behaviour.
##
## As in the original, a contact id pointing at somebody who is gone is left
## pointing at nothing: delete_and_remove() does not fix those up either, and
## every reader already copes with a contact it cannot find.


## Takes everybody finished with off the board. Returns how many went.
static func sweep(state: GameState) -> int:
	var spared := _still_wanted(state)
	var gone := 0
	for id: int in state.creatures.keys():
		var creature: Creature = state.creatures[id]
		if creature.exists or spared.has(id):
			continue
		state.creatures.erase(id)
		gone += 1
	return gone


## Everybody something still points at, whatever their flag says.
##
## Being marked gone and still being held, or still being on a list the day
## works through, means somebody would go looking for them tomorrow. Those stay
## until whatever holds them lets go.
static func _still_wanted(state: GameState) -> Dictionary:
	var wanted := {}
	for squad: Squad in state.squads.values():
		for id in squad.member_ids:
			wanted[id] = true
	for meeting: RecruitState in state.recruit_meetings:
		wanted[meeting.recruit_id] = true
		wanted[meeting.recruiter_id] = true
	for date: DatePlan in state.dates:
		wanted[date.dater_id] = true
		for id in date.date_ids:
			wanted[id] = true
	for creature: Creature in state.creatures.values():
		if creature.prisoner_id != 0:
			wanted[creature.prisoner_id] = true
		if creature.activity == &"hostagetending" and creature.tending_id != 0:
			wanted[creature.tending_id] = true
	return wanted
