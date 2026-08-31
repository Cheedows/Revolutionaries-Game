class_name SiteJury
extends RefCounted
## Talking to the jury.
##
## Ports special_courthouse_jury() from src/sitemode/mapspecials.cpp. Whoever
## in the squad is best at being listened to tries it: charisma, intelligence,
## persuasion and law added together decide who, and then two checks decide
## whether it works. A failure fills the room with twelve angry jurors.

## What the attempt teaches whoever makes it, win or lose.
const LESSON := 20

## What talking a jury round is worth.
const JUICE := 25
const JUICE_CAP := 200

## How many jurors there are, and what being caught at it costs.
const JURORS := 12
const CAUGHT_CRIME := 10


## Tries the jury. A squad that has already been noticed does not get the
## chance. Returns the events.
static func sway(state: GameState, rng: Rng, squad: Squad,
		catalog: Catalog) -> Array[Event]:
	var events: Array[Event] = []
	if state.site.alarm or state.site.alienated != 0:
		return events
	SiteSpecials.spend(state)

	# Whoever the jury is most likely to listen to. The original's best-so-far
	# starts at zero, so a squad of the entirely unpersuasive sends nobody.
	var best := 0
	var speaker: Creature = null
	for member: Creature in state.squad_members(squad):
		if not member.alive:
			continue
		var standing := AttributeRules.effective(member, &"charisma", true) \
				+ AttributeRules.effective(member, &"intelligence", true) \
				+ member.skills.get_value(&"persuasion") \
				+ member.skills.get_value(&"law")
		if standing > best:
			best = standing
			speaker = member
	if speaker == null:
		return events

	TrainRules.train(speaker, &"persuasion", LESSON)
	TrainRules.train(speaker, &"law", LESSON)

	# Both checks have to land, and the second is only rolled if the first
	# does.
	var swayed := CheckRules.skill_check(rng, speaker, &"persuasion",
			Difficulty.HARD) \
			and CheckRules.skill_check(rng, speaker, &"law",
					Difficulty.CHALLENGING)

	if swayed:
		# What the defendant was accused of, which the original rolls for.
		rng.below(16)
		events.append_array(Alienation.check(state, rng, false))
		events.append_array(Suspicion.noticed(state, rng, squad,
				Difficulty.EASY, null, catalog))
		JuiceRules.add(state, speaker, JUICE, JUICE_CAP)
		events.append(Event.new(Event.JURY_SWAYED, {"creature": speaker.id}))
		return events

	PrisonerRescue.fill_the_room(state, rng, JURORS, catalog, &"CREATURE_JUROR")
	state.site.alarm = true
	state.site.alienated = 2
	state.site.crime_level += CAUGHT_CRIME
	NewsQueue.record(state, &"jurytampering")
	events.append_array(CrimeRules.charge_squad(state, &"jury"))
	events.append(Event.new(Event.JURY_SWAYED,
			{"creature": speaker.id, "caught": true}))
	return events
