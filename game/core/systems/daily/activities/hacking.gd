class_name HackingActivities
extends RefCounted
## Breaking into things from a safehouse.
##
## Ports doActivityHacking() from src/daily/activities.cpp. Four different jobs
## share one pass: real hacking, which is done by the whole team together, and
## credit-card fraud, denial-of-service attacks and the protection racket built
## on them, which are done one Liberal at a time.

## What each job teaches, per day.
const LESSON: Dictionary = {
	&"ccfraud": 2, &"dos_attacks": 2, &"dos_racket": 4, &"hacking": 4,
}

## The eleven things a successful break-in can turn up, in the original's
## order. Each names what it leaves behind, how hard it is to trace, what the
## squad is charged with, what it is worth, and whose mind it changes.
const BREAK_INS: Array = [
	{&"loot": &"LOOT_CORPFILES", &"trace": Difficulty.SUPERHEROIC, &"juice": 10},
	{&"trace": Difficulty.IMPOSSIBLE, &"juice": 25,
			&"shifts": [[&"intelligence", 10, 0, 75]]},
	{&"trace": Difficulty.SUPERHEROIC, &"juice": 10,
			&"shifts": [[&"genetics", 2, 0, 75]]},
	{&"loot_either": [&"LOOT_CABLENEWSFILES", &"LOOT_AMRADIOFILES"],
			&"trace": Difficulty.SUPERHEROIC, &"juice": 10},
	{&"trace": Difficulty.IMPOSSIBLE, &"juice": 10,
			&"shifts": [[&"liberalcrimesquad", 5, 0, 75]]},
	{&"loot": &"LOOT_RESEARCHFILES", &"trace": Difficulty.SUPERHEROIC, &"juice": 10},
	{&"loot": &"LOOT_JUDGEFILES", &"trace": Difficulty.SUPERHEROIC, &"juice": 10},
	{&"trace": Difficulty.SUPERHEROIC, &"juice": 10,
			&"shifts": [[&"gay", 2, 0, 75], [&"women", 2, 0, 75]]},
	{&"trace": Difficulty.SUPERHEROIC, &"juice": 10,
			&"shifts": [[&"policebehavior", 2, 0, 75],
					[&"civilrights", 2, 0, 75]]},
	{&"trace": Difficulty.SUPERHEROIC, &"juice": 10,
			&"shifts": [[&"ceosalary", 2, 0, 75], [&"taxes", 2, 0, 75]]},
	{&"trace": Difficulty.SUPERHEROIC, &"juice": 10,
			&"shifts": [[&"immigration", 2, 0, 75], [&"freespeech", 2, 0, 75]]},
]

## What a lesser job is charged as, by what was done to the site.
const DEFACEMENT_CRIMES: Array[StringName] = [
	&"information", &"commerce", &"speech", &"information",
]
const DEFACEMENT_SITES := 5

## Standing for a break-in and for a defacement.
const BREAK_IN_JUICE_CAP := 200
const DEFACE_JUICE := 5
const DEFACE_JUICE_CAP := 100

## The luck in a trace: five wide, centred two below the roll.
const TRACE_SPREAD := 5
const TRACE_OFFSET := 2

## Credit-card fraud pays this much to start, and this much more for every two
## points of skill above the bar.
const FRAUD_BASE := 101
const FRAUD_STEP := 51
const FRAUD_PER_CHECK := 2

## How much stolen money it takes to get noticed, per point of skill.
const FRAUD_NOTICED_PER := 25


## The day's hacking, for everybody doing any of it. Returns the events.
static func run(state: GameState, rng: Rng, hackers: Array[Creature],
		catalog: Catalog) -> Array[Event]:
	var events: Array[Event] = []
	var teams := {&"ccfraud": [], &"dos_attacks": [], &"dos_racket": [],
			&"hacking": []}

	# Everybody practises first, whatever they are doing.
	for hacker: Creature in hackers:
		if not teams.has(hacker.activity):
			continue
		TrainRules.train(hacker, &"computers", int(LESSON[hacker.activity]))
		(teams[hacker.activity] as Array).append(hacker)

	events.append_array(_break_in(state, rng, teams[&"hacking"], hackers))
	for defrauder: Creature in teams[&"ccfraud"]:
		events.append_array(_credit_cards(state, rng, defrauder,
				(teams[&"ccfraud"] as Array).size()))
	return events


## The team's joint attempt on something worth breaking into.
##
## Only the best roll counts, but every extra pair of hands helps: the team's
## size is added to it. A very good result gets into somewhere that matters; a
## merely good one defaces a website.
static func _break_in(state: GameState, rng: Rng, team: Array,
		everyone: Array[Creature]) -> Array[Event]:
	var events: Array[Event] = []
	if team.is_empty():
		return events

	# MAX() is a macro in the original, so `MAX(best, skill_roll(...))` rolls
	# once to compare and rolls again when the first roll won — and it is the
	# second roll that is kept, which can be lower than the best so far. A
	# team of good hackers therefore costs far more draws than it looks like,
	# and can end up with a worse number than it had. Reproduced.
	var best := 0
	for hacker: Creature in team:
		if best < CheckRules.skill_roll(rng, hacker, &"computers"):
			best = CheckRules.skill_roll(rng, hacker, &"computers")
	var reach := best + team.size() - 1

	if reach >= Difficulty.HEROIC:
		var found: Dictionary = BREAK_INS[rng.below(BREAK_INS.size())]
		if found.has(&"loot_either"):
			var pair: Array = found[&"loot_either"]
			_leave_loot(state, everyone, pair[0] if rng.below(2) != 0 else pair[1])
		elif found.has(&"loot"):
			_leave_loot(state, everyone, found[&"loot"])
		for shift: Array in found.get(&"shifts", []):
			events.append(OpinionChangeRules.change(state, shift[0], shift[1],
					shift[2], shift[3]))

		# Traced only if the job was beyond them. Note the whole team is
		# charged, and note it is the whole hacking list that is charged rather
		# than the team — the original indexes the wrong array here.
		if int(found[&"trace"]) > best + rng.below(TRACE_SPREAD) - TRACE_OFFSET:
			for index in team.size():
				events.append(CrimeRules.charge(state, everyone[index],
						&"information"))
		for hacker: Creature in team:
			JuiceRules.add(state, hacker, int(found[&"juice"]),
					BREAK_IN_JUICE_CAP)
		events.append(Event.new(Event.HACK_SUCCEEDED,
				{"story": BREAK_INS.find(found), "team": team.size()}))
		return events

	if reach >= Difficulty.FORMIDABLE:
		var issue := Ids.VIEWS[rng.below(Ids.VIEWS.size() - 5)]
		var what := rng.below(DEFACEMENT_CRIMES.size())
		var target := rng.below(DEFACEMENT_SITES)
		events.append(OpinionChangeRules.change(state, issue, 1))
		if Difficulty.HEROIC > best + rng.below(TRACE_SPREAD) - TRACE_OFFSET:
			for hacker: Creature in team:
				events.append(CrimeRules.charge(state, hacker,
						DEFACEMENT_CRIMES[what]))
		for hacker: Creature in team:
			JuiceRules.add(state, hacker, DEFACE_JUICE, DEFACE_JUICE_CAP)
		events.append(Event.new(Event.HACK_DEFACED, {
			"what": what, "target": target, "issue": issue,
			"team": team.size(),
		}))
	return events


## One Liberal's day of credit-card fraud.
##
## A hundred dollars for getting in, and fifty more for every two points of
## skill past the bar — so a good hacker is paid for the margin, not the roll.
static func _credit_cards(state: GameState, rng: Rng, defrauder: Creature,
		team_size: int) -> Array[Event]:
	var events: Array[Event] = []
	var skill := CheckRules.skill_roll(rng, defrauder, &"computers")
	if Difficulty.CHALLENGING > skill:
		return events

	var taken := rng.below(FRAUD_BASE)
	var bar := Difficulty.CHALLENGING
	while bar < skill:
		taken += rng.below(FRAUD_STEP)
		bar += FRAUD_PER_CHECK
	state.ledger.add(taken, &"ccfraud")
	defrauder.income = taken / maxi(team_size, 1)
	events.append(Event.new(Event.FUNDS_GAINED,
			{"amount": taken, "source": &"ccfraud", "creature": defrauder.id}))

	# Taking too much for the skill behind it gets noticed.
	if taken / FRAUD_NOTICED_PER > rng.below(skill + 1):
		events.append(CrimeRules.charge(state, defrauder, &"ccfraud"))
	return events


## Files turn up at the safehouse of whoever the original happened to look at
## first, not of whoever found them.
static func _leave_loot(state: GameState, everyone: Array[Creature],
		type: StringName) -> void:
	if everyone.is_empty():
		return
	var here: Location = state.locations.get(everyone[0].location)
	if here == null:
		return
	var item := Loot.new()
	item.type = type
	here.ground_loot.append(item)
