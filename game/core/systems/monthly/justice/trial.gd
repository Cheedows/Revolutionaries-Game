class_name Trial
extends RefCounted
## Standing trial.
##
## Ports trial() from src/monthly/justice.cpp. A jury is drawn from the
## country's mood, the prosecution's case is built out of the charge sheet, and
## the defense is whatever the player was willing to pay for. Sleepers matter
## twice over: a sleeper on the bench halves the prosecution and silences the
## informants, and a sleeper at the bar defends for nothing.

## The defense the player may choose. The ace attorney is only offered when
## the money is there, and the sleeper only when one is in the city.
const COURT_APPOINTED := 0
const SELF := 1
const GUILTY_PLEA := 2
const ACE_ATTORNEY := 3
const SLEEPER_ATTORNEY := 4

## What the ace attorney costs.
const ACE_FEE := 5000

## The prosecution's case: a floor, a hundred-and-one-point roll, the weight of
## the charge sheet, and twenty for every former member willing to testify.
const PROSECUTION_FLOOR := 40
const PROSECUTION_SPREAD := 101
const PER_CONFESSION := 20

## What the ace attorney takes off the prosecution before it starts.
const ACE_DISCOUNT := 60

## What each kind of defense is worth.
const DEFENSE_SPREAD := 71
const ACE_BONUS := 80

## Defending yourself: persuasion and law, with law worth half again as much,
## and both of them punished below a middling roll.
const SELF_BASELINE := 3
const SELF_PERSUASION := 5
const SELF_LAW := 10
const SELF_LESSON := 50

## A retrial is certain once the case is serious enough, or once anybody has
## agreed to testify.
const RETRIAL_SCAREFACTOR := 10


## Puts [param defendant] on trial. Returns a [PendingIntent] asking how the
## defense should be conducted.
static func begin(state: GameState, rng: Rng, defendant: Creature,
		catalog: Catalog) -> PendingIntent:
	# A defendant whose safehouse is gone goes back to the shelter instead;
	# where they live is where they go if they walk free.
	var home: Location = state.locations.get(defendant.base)
	if home == null or home.renting < 0:
		var shelter := WorldLookup.homeless_shelter(state, home)
		defendant.base = shelter.id if shelter != null else -1
	defendant.location = defendant.base

	var events: Array[Event] = [Event.new(Event.TRIAL_STARTED,
			{"creature": defendant.id})]
	if not _is_charged(defendant):
		# Nobody stands trial for nothing, so the court finds something.
		events.append(CrimeRules.charge(state, defendant, &"loitering"))

	var scare := 0
	for index in defendant.crimes_suspected.size():
		if defendant.crimes_suspected[index] != 0:
			scare += CrimeRules.heat_of(Ids.LAW_FLAGS[index]) \
					* defendant.crimes_suspected[index]

	var bench := TrialBench.find(state, rng, defendant)
	var judge: Creature = bench["judge"]
	if judge != null:
		# A friendly judge makes the informants think better of it.
		defendant.confessions = 0

	var court := {
		"defendant": defendant, "scare": scare, "judge": judge,
		"lawyer": bench["lawyer"], "events": events,
	}
	return PendingIntent.new(
			Intent.new(Intent.CHOOSE_DEFENSE, _options(state, bench["lawyer"]),
					{"creature": defendant.id, "charges": scare}, false),
			func(answer: Variant) -> Array[Event]:
				return _conduct(state, rng, court, int(answer), catalog),
			events)


## The choices the player is offered, and which of them they can afford.
static func _options(state: GameState, lawyer: Creature) -> Array[Dictionary]:
	var options: Array[Dictionary] = [
		{"id": COURT_APPOINTED, "label": "Use a court-appointed attorney."},
		{"id": SELF, "label": "Defend self!"},
		{"id": GUILTY_PLEA, "label": "Plead guilty."},
		{"id": ACE_ATTORNEY, "label": "Hire an ace Liberal attorney.",
				"cost": ACE_FEE, "enabled": state.ledger.funds >= ACE_FEE},
	]
	if lawyer != null:
		options.append({"id": SLEEPER_ATTORNEY, "enabled": true,
				"label": "Accept a sleeper's offer to assist pro bono.",
				"creature": lawyer.id})
	return options


## Runs the trial once the defense is chosen.
static func _conduct(state: GameState, rng: Rng, court: Dictionary,
		defense: int, catalog: Catalog) -> Array[Event]:
	var defendant: Creature = court["defendant"]
	var lawyer: Creature = court["lawyer"]
	var judge: Creature = court["judge"]
	var events: Array[Event] = []

	if defense == ACE_ATTORNEY:
		state.ledger.subtract(ACE_FEE, &"legal")
	if defense == SLEEPER_ATTORNEY and lawyer == null:
		defense = COURT_APPOINTED

	if defense == GUILTY_PLEA:
		# The plea skips the whole trial; only the judge's mood is left.
		# The judge is checked first, so a friendly one costs no roll at all.
		var merciful := judge != null or rng.below(2) != 0
		events.append_array(Sentencing.penalize(state, rng, defendant, merciful))
		defendant.crimes_suspected.fill(0)
		defendant.heat = 0
		defendant.confessions = 0
		return events + _place(state, defendant, catalog)

	var seated := TrialJury.seat(state, rng, judge != null,
			defense == ACE_ATTORNEY, events)
	var jury: int = seated["jury"]
	# Jury selection can hand the prosecution the attorney's arch-nemesis.
	var prosecution: int = PROSECUTION_FLOOR + rng.below(PROSECUTION_SPREAD) \
			+ int(court["scare"]) + PER_CONFESSION * defendant.confessions \
			+ int(seated["prosecution"])
	if judge != null:
		prosecution >>= 1
	if defense == ACE_ATTORNEY:
		prosecution -= ACE_DISCOUNT
	# The prosecution's own presentation is rolled on top of the jury's bias.
	jury += rng.below(prosecution / 2 + 1) + prosecution / 2

	var power := _defense_power(state, rng, defendant, lawyer, defense,
			prosecution, events)
	var lenient := power / 3 >= jury / 4 or judge != null
	events.append(Event.new(Event.TRIAL_ARGUED, {
		"creature": defendant.id, "jury": jury, "defense": power,
		"prosecution": prosecution, "lenient": 1 if lenient else 0,
	}))

	var keep_charges := false
	if power == jury:
		keep_charges = _hung(state, rng, defendant, court, events)
	elif power > jury:
		_acquitted(state, rng, defendant, judge, lawyer, defense, events)
	else:
		if defense == SLEEPER_ATTORNEY:
			JuiceRules.add(state, lawyer, -5, 0)
		# Being convicted of something is worth a little standing.
		JuiceRules.add(state, defendant, 25, 200)
		events.append_array(Sentencing.penalize(state, rng, defendant, lenient))

	if not keep_charges:
		defendant.crimes_suspected.fill(0)
	defendant.heat = 0
	defendant.confessions = 0
	return events + _place(state, defendant, catalog)


## What the defense manages to do with the case.
static func _defense_power(state: GameState, rng: Rng, defendant: Creature,
		lawyer: Creature, defense: int, prosecution: int,
		events: Array[Event]) -> int:
	if defense == SELF:
		# Persuasion and law both, with law worth half again as much and both
		# of them punished below a middling roll.
		var power := SELF_PERSUASION * (CheckRules.skill_roll(rng, defendant,
						&"persuasion") - SELF_BASELINE) \
				+ SELF_LAW * (CheckRules.skill_roll(rng, defendant, &"law")
						- SELF_BASELINE)
		TrainRules.train(defendant, &"persuasion", SELF_LESSON)
		TrainRules.train(defendant, &"law", SELF_LESSON)
		if power <= 0:
			JuiceRules.add(state, defendant, -10, -50)
		elif power > 150:
			JuiceRules.add(state, defendant, 50, 1000)
		return power

	if defense == ACE_ATTORNEY:
		return rng.below(DEFENSE_SPREAD) + ACE_BONUS
	if defense == SLEEPER_ATTORNEY:
		var power := rng.below(DEFENSE_SPREAD) \
				+ lawyer.skills.get_value(&"law") * 2 \
				+ lawyer.skills.get_value(&"persuasion") * 2
		TrainRules.train(lawyer, &"law", prosecution / 4)
		TrainRules.train(lawyer, &"persuasion", prosecution / 4)
		return power
	return rng.below(DEFENSE_SPREAD)


## A hung jury. Returns whether the charges survive to next month.
static func _hung(state: GameState, rng: Rng, defendant: Creature,
		court: Dictionary, events: Array[Event]) -> bool:
	# A non-zero roll retries, which is three cases in four alongside the two
	# conditions that force it.
	if rng.below(2) != 0 or int(court["scare"]) >= RETRIAL_SCAREFACTOR \
			or defendant.confessions != 0:
		var courthouse := WorldLookup.courthouse(state,
				state.locations.get(defendant.location))
		defendant.location = courthouse.id if courthouse != null else -1
		events.append(Event.new(Event.TRIAL_VERDICT,
				{"creature": defendant.id, "verdict": &"retrial"}))
		return true
	events.append(Event.new(Event.TRIAL_VERDICT,
			{"creature": defendant.id, "verdict": &"dropped"}))
	_back_to_prison(rng, defendant, court["judge"] != null)
	return false


## An acquittal, which does not undo a sentence already being served.
static func _acquitted(state: GameState, rng: Rng, defendant: Creature,
		judge: Creature, lawyer: Creature, defense: int,
		events: Array[Event]) -> void:
	events.append(Event.new(Event.TRIAL_VERDICT,
			{"creature": defendant.id, "verdict": &"acquitted"}))
	_back_to_prison(rng, defendant, judge != null)
	if defense == SLEEPER_ATTORNEY:
		JuiceRules.add(state, lawyer, 10, 100)
	if defense == SELF:
		JuiceRules.add(state, defendant, 10, 100)


## Somebody who walks free of these charges but not of an older sentence.
static func _back_to_prison(rng: Rng, defendant: Creature,
		merciful: bool) -> void:
	if defendant.sentence == 0:
		return
	# The roll is the last term of the original's && chain, so somebody with a
	# life sentence or a single month left costs no draw at all.
	if defendant.death_penalty == 0 and defendant.sentence > 1 \
			and (rng.below(2) != 0 or merciful):
		defendant.sentence -= 1
	if defendant.death_penalty != 0:
		defendant.sentence = SentenceRules.DEATH_ROW


## Where the defendant goes when the court is finished with them.
static func _place(state: GameState, defendant: Creature,
		catalog: Catalog) -> Array[Event]:
	if defendant.sentence != 0:
		var prison := WorldLookup.site_in_city(state, &"government_prison",
				_city_of(state, defendant))
		defendant.location = prison.id if prison != null else -1
		return []
	defendant.armor = Armor.new(&"ARMOR_CLOTHES")
	return []


static func _city_of(state: GameState, creature: Creature) -> int:
	var here: Location = state.locations.get(creature.location)
	return here.city if here != null else 0


static func _is_charged(defendant: Creature) -> bool:
	for count in defendant.crimes_suspected:
		if count != 0:
			return true
	return false
