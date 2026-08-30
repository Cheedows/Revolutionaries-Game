class_name Event
extends RefCounted
## Something that happened in the simulation.
##
## This is the seam that replaces the original's ~8,400 direct screen writes.
## A system never draws and never formats: it returns Events, and ui/adapters/
## decides how to render them. Display text lives in data/text/, keyed by
## [member type], so a new UI never requires touching core/.
##
## Events carry data, not prose: no colour codes, no cursor positions, no
## pre-built sentences. "creature_trained" with a skill and an amount, not
## "Patty peruses some sewing magazines."
##
## The vocabulary below is the starting set. Each system adds its own types as
## it is ported; the rule is that a type is only added when a system emits it.

## What happened. One of the constants below.
var type: StringName

## Typed payload. Keys are documented per type in data/text/events.json.
var data: Dictionary

## Ordering within a turn, assigned by app/session.gd when it collects them.
var sequence: int = 0


func _init(event_type: StringName, event_data: Dictionary = {}) -> void:
	type = event_type
	data = event_data


func _to_string() -> String:
	return "Event(%s, %s)" % [type, data]


# --- Creatures -------------------------------------------------------------

const CREATURE_SPAWNED := &"creature_spawned"
const CREATURE_RECRUITED := &"creature_recruited"
const CREATURE_TRAINED := &"creature_trained"        # {creature, skill, amount}
const CREATURE_SKILL_UP := &"creature_skill_up"      # {creature, skill, level}
const CREATURE_JUICE_CHANGED := &"creature_juice_changed"
const CREATURE_WOUNDED := &"creature_wounded"        # {creature, part, organ}
const CREATURE_SHIELDED := &"creature_shielded"      # {creature, for}
const CREATURE_HEALED := &"creature_healed"
const CREATURE_DIED := &"creature_died"              # {creature, cause}
const CREATURE_ARRESTED := &"creature_arrested"
const CREATURE_CONVERTED := &"creature_converted"
const CREATURE_LEFT := &"creature_left"
const CREATURE_AUGMENTED := &"creature_augmented"

# --- Items and money -------------------------------------------------------

const ITEM_ACQUIRED := &"item_acquired"              # {creature, item, count}
const ITEM_LOST := &"item_lost"
const ITEM_EQUIPPED := &"item_equipped"
const ITEM_DAMAGED := &"item_damaged"                # {item, quality}
const ITEM_DESTROYED := &"item_destroyed"
const ITEM_FENCED := &"item_fenced"                  # {item, amount}
const FUNDS_GAINED := &"funds_gained"                # {amount, source}
const FUNDS_SPENT := &"funds_spent"                  # {amount, purpose}

# --- The daily and monthly turn -------------------------------------------

const DAY_ADVANCED := &"day_advanced"                # {day, month, year}
const MONTH_ADVANCED := &"month_advanced"
const ACTIVITY_RESOLVED := &"activity_resolved"      # {creature, activity, outcome}
const RECRUIT_MET := &"recruit_met"
const SLEEPER_REPORTED := &"sleeper_reported"
const FINANCES_REPORTED := &"finances_reported"

# --- Politics and news -----------------------------------------------------

const LAW_CHANGED := &"law_changed"                  # {law, from, to}
const AMENDMENT_PROPOSED := &"amendment_proposed"
const ELECTION_HELD := &"election_held"              # {body, results}
const OPINION_SHIFTED := &"opinion_shifted"          # {view, amount, cause}
const NEWS_PUBLISHED := &"news_published"            # {story, prominence}
const MAJOR_EVENT := &"major_event"

# --- Justice ---------------------------------------------------------------

const TRIAL_STARTED := &"trial_started"
const TRIAL_VERDICT := &"trial_verdict"              # {creature, charge, verdict}
const SENTENCE_PASSED := &"sentence_passed"

# --- Sites, combat and chases ---------------------------------------------

const SITE_ENTERED := &"site_entered"                # {location, squad, mapped}
const SITE_LEFT := &"site_left"                      # {location}
const SITE_ALARM_RAISED := &"site_alarm_raised"
const SQUAD_MOVED := &"squad_moved"                  # {x, y, z}
const SQUAD_BLOCKED := &"squad_blocked"              # {x, y, z}
const DOOR_OPENED := &"door_opened"                  # {x, y, z, forced}
const DOOR_LOCKED := &"door_locked"                  # {x, y, z, pickable}
const DOOR_UNLOCKED := &"door_unlocked"              # {creature, x, y, z}
const DOOR_JAMMED := &"door_jammed"                  # {creature}
const DOOR_IMPENETRABLE := &"door_impenetrable"      # {x, y, z}
const STAIRS_TAKEN := &"stairs_taken"                # {z, up}
const ENCOUNTER_STARTED := &"encounter_started"
const ATTACK_MADE := &"attack_made"                  # {attacker, target, weapon, sneak}
const ATTACK_INCAPABLE := &"attack_incapable"        # {attacker}
const SPECIAL_ATTACK_MADE := &"special_attack_made"  # {attacker, target, kind, line}
const CREATURE_STUNNED := &"creature_stunned"        # {creature, turns}
const ATTACK_RELOADED := &"attack_reloaded"          # {attacker}
const ATTACK_HIT := &"attack_hit"                    # {attacker, target, damage, part}
const ATTACK_MISSED := &"attack_missed"
const CHASE_STARTED := &"chase_started"
const CHASE_ENDED := &"chase_ended"                  # {escaped}
const SIEGE_STARTED := &"siege_started"
const SIEGE_ENDED := &"siege_ended"

# --- Game lifecycle --------------------------------------------------------

const GAME_STARTED := &"game_started"
const GAME_WON := &"game_won"                        # {condition}
const GAME_LOST := &"game_lost"                      # {condition}
