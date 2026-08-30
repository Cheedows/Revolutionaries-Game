class_name GameState
extends RefCounted
## The whole simulation, in one object.
##
## This replaces the 123 globals in src/externs.h. Every system takes a
## GameState and an [Rng] explicitly and never reaches for either, which is what
## makes a system testable without an engine and a run reproducible from a seed.
##
## Nothing here decides anything: no rolls, no rules, no formatting. Behaviour
## lives in core/systems/.

## Save format version. Bumped whenever the shape below changes; migrations
## live in core/save/migrations.gd. The original's raw-struct save format is
## deliberately not ported — see docs/port/GODOT-PORT-PLAN.md section 6.
const SAVE_VERSION := 1

var calendar := Calendar.new()
var ledger := Ledger.new()
var law := Law.new()
var government := Government.new()
var opinion := PublicOpinion.new()
var site := SiteState.new()
var chase := ChaseState.new()

## Everyone the game is tracking, by creature id.
var creatures: Dictionary = {}

## Squads by id, and the one the player is currently commanding.
var squads: Dictionary = {}
var active_squad_id: int = 0

## The world, by location id.
var locations: Dictionary = {}

## Vehicles by id.
var vehicles: Dictionary = {}

## Stories waiting to run in tomorrow's paper.
var news: Array[NewsStory] = []

## Sieges under way, keyed by location id.
var sieges: Dictionary = {}

## Id counters. The original keeps these as globals precisely because ids must
## stay unique across a save.
var next_creature_id: int = 1
var next_squad_id: int = 1
var next_vehicle_id: int = 1

## Difficulty and mode flags chosen at the start of a game.
var win_condition: StringName = &"elite_liberal"
var field_skill_rate: StringName = &"fast"
var multiple_cities: bool = false
var no_term_limits: bool = false
var no_court_purge: bool = false

## Set once a term-limits amendment passes: every seat is then contested
## with no incumbent advantage.
var term_limits: bool = false
var stalin_mode: bool = false
var classic_mode: bool = false

## How much attention the authorities are paying nationally.
var police_heat: int = 0

## Organisations the squad has provoked.
var offended: Dictionary = {}

## How exposed the Conservative Crime Squad is, and how the game ended.
var ccs_exposure: int = 0

## How many of the Conservative Crime Squad's leaders have been killed, which
## decides who is left in charge when one is met.
var ccs_kills: int = 0

## High-score tallies the original keeps: Conservatives killed, Liberals lost,
## and the Conservative Crime Squad's leadership specifically.
var kills: int = 0
var dead: int = 0
var ccs_boss_kills: int = 0

## How many Conservatives the squad has taken home for re-education, and how
## many Liberals it has talked into joining.
var kidnappings: int = 0
var recruits: int = 0

## How hard each kind of person is to track down. Seeded from
## [constant Recruiting.FINDABLE] and only recalculated when the player opens
## the recruitment menu, which is what the original does — see
## [method Recruiting.refresh_difficulties].
var recruit_difficulty: Dictionary = Recruiting.FINDABLE.duplicate()

## Meetings the squad has agreed to, oldest first.
var recruit_meetings: Array[RecruitState] = []
var endgame_state: StringName = &"none"

## Lifetime tallies shown on the high-score screen.
var stats: Dictionary = {}

## The organisation's slogan, once the player writes one.
var slogan: String = ""

## The city the game is being played in.
var city_name: String = ""


## The squad the player is commanding, or null.
func active_squad() -> Squad:
	return squads.get(active_squad_id)


## Registers a creature and assigns it the next id.
func add_creature(creature: Creature) -> Creature:
	creature.id = next_creature_id
	next_creature_id += 1
	creatures[creature.id] = creature
	return creature


## Registers a squad and assigns it the next id.
func add_squad(squad: Squad) -> Squad:
	squad.id = next_squad_id
	next_squad_id += 1
	squads[squad.id] = squad
	return squad


## Registers a vehicle and assigns it the next id.
func add_vehicle(vehicle: Vehicle) -> Vehicle:
	vehicle.id = next_vehicle_id
	next_vehicle_id += 1
	vehicles[vehicle.id] = vehicle
	return vehicle


## Scraps a vehicle. A crashed car is gone for good, not parked somewhere.
func remove_vehicle(vehicle_id: int) -> void:
	vehicles.erase(vehicle_id)


## Every living member of the player's organisation.
func members() -> Array[Creature]:
	var found: Array[Creature] = []
	for creature: Creature in creatures.values():
		if creature.alive and creature.is_member():
			found.append(creature)
	return found


## The creatures making up [param squad], in order.
func squad_members(squad: Squad) -> Array[Creature]:
	var found: Array[Creature] = []
	for member_id in squad.member_ids:
		var creature: Creature = creatures.get(member_id)
		if creature != null:
			found.append(creature)
	return found
