class_name SiteReactor
extends RefCounted
## Shutting down a nuclear reactor.
##
## Ports special_nuclear_onoff() from src/sitemode/mapspecials.cpp. Somebody in
## the squad has to understand what they are looking at; anybody else can pull
## levers, which is worth something but not much.
##
## The reading of it depends on the law. Where nuclear power is already banned
## the plant is running illegally and shutting it down is a public service —
## except that the public does not thank the people who did it. Where it is
## legal, it is simply a triumph.

## How much science it takes to do it properly.
const DIFFICULTY := Difficulty.HARD

## What it is worth done properly, under a ban and otherwise.
const BANNED_JUICE := 40
const LEGAL_JUICE := 100
const EXPERT_CAP := 1000

## And what it is worth done by pulling levers.
const AMATEUR_JUICE := 15
const AMATEUR_CAP := 500

## What the country makes of it, and the share of it that will ever agree.
const NUCLEAR_SHIFT := 15
const NUCLEAR_CAP := 95

## Shutting down a reactor that was operating legally costs the organisation
## half of whatever goodwill it had.
const APPROVAL_COST := -50

## How much worse the visit gets: the shutdown itself, and the break-in around
## it.
const BANNED_CRIME := 25
const LEGAL_CRIME := 50
const ENTRY_CRIME := 5


## Pulls the scram. Returns the events.
static func shut_down(state: GameState, rng: Rng, squad: Squad,
		catalog: Catalog) -> Array[Event]:
	var events: Array[Event] = []
	SiteSpecials.spend(state)

	# The first person who can follow the manual does it; the loop stops
	# there, so a squad of physicists costs one roll.
	var expert: Creature = null
	for member: Creature in state.squad_members(squad):
		if not member.alive:
			continue
		if CheckRules.skill_check(rng, member, &"science", DIFFICULTY):
			expert = member
			break

	var banned := state.law.get_value(&"nuclearpower") == Law.ELITE_LIBERAL
	if expert != null:
		events.append(OpinionChangeRules.change(state, &"nuclearpower",
				NUCLEAR_SHIFT, 0, NUCLEAR_CAP))
		if banned:
			# Nobody thanks the people who did it.
			events.append(OpinionChangeRules.change(state,
					&"liberalcrimesquadpos", APPROVAL_COST, 0, 0))
			SiteSpecials.credit(state, BANNED_JUICE, EXPERT_CAP)
			state.site.crime_level += BANNED_CRIME
		else:
			SiteSpecials.credit(state, LEGAL_JUICE, EXPERT_CAP)
			state.site.crime_level += LEGAL_CRIME
		NewsQueue.record(state, &"shutdownreactor")
	else:
		SiteSpecials.credit(state, AMATEUR_JUICE, AMATEUR_CAP)

	state.site.alarm = true
	events.append_array(Alienation.check(state, rng, true))
	SiteSpecials.spend(state)
	state.site.crime_level += ENTRY_CRIME
	events.append_array(CrimeRules.charge_squad(state, &"terrorism"))
	return events
