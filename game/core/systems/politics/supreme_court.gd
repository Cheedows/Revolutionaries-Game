class_name SupremeCourtRules
extends RefCounted
## The Supreme Court hearing cases and changing its own membership.
##
## Ports supremecourt() from src/politics/politics.cpp, minus its presentation.
##
## Justices, unlike legislators, do not consult public opinion at all — they
## vote their alignment plus a constitutional bias: extra Liberal on speech and
## flag burning, extra Conservative on gun control.
##
## Not ported: the replacement justice's name. The original generates one, which
## consumes randomness, so a full-game replay will diverge from this point until
## the name generator is ported.

const SEATS := 9
const MAJORITY := 5

## Cases heard in a session: two to six.
const MINIMUM_CASES := 2
const CASE_SPREAD := 5

## A justice leaves the bench roughly this often.
const RETIREMENT_ROLL := 10
const RETIREMENT_THRESHOLD := 6

## Laws the court reads through a constitutional lens rather than a political
## one.
const LIBERAL_BIAS: Array[StringName] = [&"freespeech", &"flagburning"]
const CONSERVATIVE_BIAS: Array[StringName] = [&"guncontrol"]


## Hears a session's cases and may replace a justice.
static func run(state: GameState, rng: Rng) -> Array[Event]:
	var events: Array[Event] = []
	var case_count := rng.below(CASE_SPREAD) + MINIMUM_CASES
	var heard := {}

	var cases := []
	for slot in case_count:
		var law_index := rng.below(Ids.LAWS.size())
		while heard.has(law_index):
			law_index = rng.below(Ids.LAWS.size())
		heard[law_index] = true
		cases.append([law_index, _direction(state, rng, law_index)])

	for entry in cases:
		events.append_array(_hear(state, entry[0], entry[1]))

	if rng.below(RETIREMENT_ROLL) >= RETIREMENT_THRESHOLD:
		events.append(_replace_justice(state, rng))
	return events


## Which way a case pulls the law.
static func _direction(state: GameState, rng: Rng, law_index: int) -> int:
	var law_name: StringName = Ids.LAWS[law_index]
	var current: int = state.law.values[law_index]
	if current == Law.ELITE_LIBERAL:
		return -1
	if current == Law.ARCH_CONSERVATIVE:
		return 1
	var bias := _bias(law_name)
	if bias != 0:
		return bias
	return 1 if rng.one_in(2) else -1


## Nine justices vote; a majority moves the law.
static func _hear(state: GameState, law_index: int, direction: int) -> Array[Event]:
	var law_name: StringName = Ids.LAWS[law_index]
	var current: int = state.law.values[law_index]
	var bias := _bias(law_name)

	var yes := 0
	for seat in state.government.court:
		var vote := seat
		if vote == Alignment.STALINIST:
			vote = Alignment.ELITE_LIBERAL \
					if OpinionRules.stalinist_agrees_on_law(law_name) \
					else Alignment.ARCH_CONSERVATIVE
		# The bias sways the middle of the bench, not its poles.
		if vote >= -1 and vote <= 1:
			vote += bias
		if current > vote and direction == -1:
			yes += 1
		elif current < vote and direction == 1:
			yes += 1

	var upheld := yes >= MAJORITY
	if upheld:
		state.law.set_value(law_name, current + direction)

	return [Event.new(Event.LAW_CHANGED, {
		"law": law_name,
		"from": current,
		"to": state.law.values[law_index],
		"outcome": &"court_ruling" if upheld else &"court_declined",
		"direction": direction,
		"votes": yes,
	})]


## Seats a new justice, chosen by where the President and Senate sit together.
static func _replace_justice(state: GameState, rng: Rng) -> Event:
	var seat := rng.below(SEATS)

	# A Stalinist counts as further out than an Arch-Conservative here.
	var president := float(state.government.executive[0])
	if state.government.executive[0] == Alignment.STALINIST:
		president = -3.0

	var senate_total := 0.0
	for member in state.government.senate:
		senate_total += -3.0 if member == Alignment.STALINIST else float(member)
	var consensus := (president + senate_total / float(state.government.senate.size())) * 0.5

	var alignment := Alignment.ELITE_LIBERAL
	if consensus < -2.1:
		alignment = Alignment.STALINIST
	elif consensus < -1.5:
		alignment = Alignment.ARCH_CONSERVATIVE
	elif consensus < -0.5:
		alignment = Alignment.CONSERVATIVE
	elif consensus < 0.5:
		alignment = Alignment.MODERATE
	elif consensus < 1.5:
		alignment = Alignment.LIBERAL

	state.government.court[seat] = alignment
	return Event.new(Event.MAJOR_EVENT, {
		"kind": &"justice_replaced",
		"seat": seat,
		"alignment": Alignment.name_of(alignment),
	})


static func _bias(law_name: StringName) -> int:
	if law_name in LIBERAL_BIAS:
		return 1
	if law_name in CONSERVATIVE_BIAS:
		return -1
	return 0
