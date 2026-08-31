class_name Persuasion
extends RefCounted
## Talking somebody round.
##
## Ports wannaHearSomethingDisturbing() and talkAboutIssues() from
## src/sitemode/talk.cpp — the conversation that turns a stranger in a building
## into a recruit. Which issue comes up is random; whether the Liberal can make
## anything of it depends on their own wits, on how far the law has already
## come, and on whether they remembered to get dressed.

## Getting somebody to listen at all: some professions always will, and a
## persuasive Liberal can get a hearing from anybody else.
const OPENING := Difficulty.AVERAGE

## What the pitch has to beat, before everything that makes it harder.
const BASE := Difficulty.VERY_EASY

## A Conservative is a hard sell; so is somebody with no reason to care. A
## fumbled argument, an issue already won, and no clothes each cost as much
## again between them.
const CONSERVATIVE_PENALTY := 7
const UNRECEPTIVE_PENALTY := 7
const FUMBLED_PENALTY := 5
const TOO_LIBERAL_PENALTY := 5
const NAKED_PENALTY := 5

## An argument nobody can follow.
const DIM_INTELLIGENCE := 3

## How many replies there are to choose from, either way.
const REPLIES := 10

## The one name the conversation refuses to have.
const PRISONER := "Prisoner"


## Somebody in the squad tries to start a conversation. Returns
## [code]{listened, recruited, events}[/code].
##
## An animal or a machine cannot follow any of it and says so; a prisoner will
## not talk to anybody; everybody else either hears the pitch or refuses it.
static func approach(state: GameState, rng: Rng, speaker: Creature,
		listener: Creature) -> Dictionary:
	var interested := TalkRules.receptive(listener) \
			and not Encounters.is_enemy(listener)
	# The persuasion roll is only made when they were not going to listen
	# anyway, and it wins them over on its own.
	if not interested and CheckRules.skill_check(rng, speaker, &"persuasion",
			OPENING):
		interested = true

	if (listener.animal_gloss == &"animal"
			and listener.alignment != &"liberal") \
			or listener.animal_gloss == &"tank":
		return {"listened": false, "recruited": false,
				"events": [] as Array[Event]}
	if listener.name != PRISONER and interested:
		return about_issues(state, rng, speaker, listener)
	return {"listened": false, "recruited": false,
			"events": [] as Array[Event]}


## The pitch itself.
static func about_issues(state: GameState, rng: Rng, speaker: Creature,
		listener: Creature) -> Dictionary:
	var events: Array[Event] = []
	var law := Ids.LAWS[rng.below(Ids.LAWS.size())]

	# A Liberal who cannot marshal the argument makes it badly; one who can
	# still has nothing to say about a law that is already as good as it gets.
	var fumbled := not CheckRules.attribute_check(rng, speaker,
			&"intelligence", Difficulty.EASY)
	var too_liberal := not fumbled \
			and state.law.get_value(law) == Alignment.ELITE_LIBERAL \
			and int(state.stats.get(&"newscherrybusted", 0)) != 0

	var difficulty := BASE
	if listener.alignment == &"conservative":
		difficulty += CONSERVATIVE_PENALTY
	if not TalkRules.receptive(listener) or Encounters.is_enemy(listener):
		difficulty += UNRECEPTIVE_PENALTY
	if fumbled:
		difficulty += FUMBLED_PENALTY
	if too_liberal:
		difficulty += TOO_LIBERAL_PENALTY
	if speaker.is_naked() and speaker.animal_gloss != &"animal":
		difficulty += NAKED_PENALTY

	var convinced := CheckRules.skill_check(rng, speaker, &"persuasion",
			difficulty)
	var dim := listener.type == &"CREATURE_MUTANT" \
			and AttributeRules.effective(listener, &"intelligence", true) \
					< DIM_INTELLIGENCE

	if convinced and listener.name != PRISONER:
		if not dim:
			# Which of ten ways they agree.
			rng.below(REPLIES)
		_sign_up(state, rng, speaker, listener)
		Encounters.remove(state, listener)
		events.append(Event.new(Event.RECRUIT_INTERESTED,
				{"creature": listener.id, "by": speaker.id, "issue": law}))
		return {"listened": true, "recruited": true, "events": events}

	_rebuff(state, rng, speaker, listener, fumbled, dim)
	listener.cannot_bluff = 1
	events.append(Event.new(Event.RECRUIT_REFUSED,
			{"creature": listener.id, "by": speaker.id, "issue": law}))
	return {"listened": true, "recruited": false, "events": events}


## What they say when they are not having it. Only the shape matters here: two
## of the three branches roll for a line and the third does not.
static func _rebuff(state: GameState, rng: Rng, speaker: Creature,
		listener: Creature, fumbled: bool, dim: bool) -> void:
	if dim:
		return
	if listener.alignment == &"conservative" and fumbled:
		if listener.type == &"CREATURE_GANGUNIT" \
				or listener.type == &"CREATURE_DEATHSQUAD":
			return
		rng.below(REPLIES)
		return
	# Anybody who is not already a Liberal gets a chance to have an answer of
	# their own, and the roll is made whether or not they find one.
	if listener.alignment != &"liberal":
		CheckRules.attribute_check(rng, listener, &"wisdom", Difficulty.AVERAGE)


## The recruit is copied out of the room and onto the recruiter's list. The
## original keeps the copy and leaves the original standing in the encounter
## until it removes them, so the person who joins is a duplicate with a name of
## their own.
static func _sign_up(state: GameState, rng: Rng, speaker: Creature,
		listener: Creature) -> void:
	# **Original quirk, reproduced.** The recruit is built with `new Creature`
	# and then overwritten by an assignment on the very next line, so a whole
	# blank creature — an age, a gender, a birthday, a shuffled attribute and
	# an alignment — is rolled and thrown away. Those draws are load-bearing:
	# everything after them in the run depends on them having happened.
	CreatureFactory.blank(rng)
	var recruit: Creature = listener.copy()
	Recruiting.name_candidate(rng, recruit)
	state.add_creature(recruit)

	var meeting := RecruitState.new()
	meeting.recruit_id = recruit.id
	meeting.recruiter_id = speaker.id
	# How willing they were before anybody said a word, which the original
	# rolls in the meeting's own constructor.
	meeting.eagerness = Recruiting.initial_eagerness(state, rng)
	state.recruit_meetings.append(meeting)
