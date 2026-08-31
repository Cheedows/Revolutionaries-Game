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
const SQUAD_DISBANDED := &"squad_disbanded"          # {year}
const SAFEHOUSE_UPGRADED := &"safehouse_upgraded"    # {location, upgrade}
const COMPUTER_HACKED := &"computer_hacked"          # {creature, machine}
const COMPUTER_RESISTED := &"computer_resisted"      # {creature, machine}
const PRISONERS_FREED := &"prisoners_freed"          # {count, wing}
const CREATURE_AUGMENTED := &"creature_augmented"

# --- Dating ----------------------------------------------------------------

const DATE_CONTINUES := &"date_continues"            # {creature, date}
const DATE_ENDED := &"date_ended"                    # {creature, date, reason}
const DATE_JOINED := &"date_joined"                  # {creature, date}
const DATE_WARMED := &"date_warmed"                  # {creature, date}
const DATE_TALKED := &"date_talked"                  # {creature, date, location}
const DATE_CURSED := &"date_cursed"                  # {creature, date}
const DATE_INFORMED := &"date_informed"              # {creature, date}
const DATE_DISASTER := &"date_disaster"              # {creature, dates}
const DATE_HOLIDAY := &"date_holiday"                # {creature, date, days}
const DATE_KIDNAPPED := &"date_kidnapped"            # {creature, date}
const DATE_KIDNAP_FAILED := &"date_kidnap_failed"    # {creature, date, caught}

# --- Stealing a car --------------------------------------------------------

const CAR_FOUND := &"car_found"                      # {creature, wanted, found}
const CAR_OPENED := &"car_opened"                    # {creature, vehicle, how}
const CAR_ALARM := &"car_alarm"                      # {vehicle, proximity}
const CAR_STARTED := &"car_started"                  # {creature, vehicle, how}
const CAR_SEARCHED := &"car_searched"                # {creature, tries}
const CAR_NERVES := &"car_nerves"                    # {creature}
const CAR_STOLEN := &"car_stolen"                    # {creature, vehicle}
const CAR_THEFT_SPOTTED := &"car_theft_spotted"      # {creature}

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
const HACK_SUCCEEDED := &"hack_succeeded"            # {story, team}
const STUDY_FINISHED := &"study_finished"            # {creature, skill}
const CLASS_TAUGHT := &"class_taught"                # {creature, course, places, cost}
const BODY_BURIED := &"body_buried"                  # {creature, by}
const TROUBLE_CAUSED := &"trouble_caused"            # {stunt, power, activists}
const MOB_CORNERED := &"mob_cornered"                # {creature}
const MOB_SCATTERED := &"mob_scattered"              # {creature}
const MOB_EXCHANGE := &"mob_exchange"                # {creature, won, manner}
const MOB_BEAT_THEM := &"mob_beat_them"              # {creature}
const MOB_BEATEN := &"mob_beaten"                    # {creature, injury}
const LETTER_WRITTEN := &"letter_written"            # {creature, issue, guardian, good}
const COMMUNITY_SERVED := &"community_served"        # {creature}
const CREATURE_HOSPITALIZED := &"creature_hospitalized" # {creature, location, months}
const SLEEPER_SURFACED := &"sleeper_surfaced"        # {creature, location}
const ARMOR_REPAIRED := &"armor_repaired"            # {creature, armor, outcome}
const ARMOR_TIDIED := &"armor_tidied"                # {creature, way}
const ARMOR_MADE := &"armor_made"                    # {creature, armor, quality, wasted, cloth}
const ARMOR_UNAFFORDABLE := &"armor_unaffordable"    # {creature, armor}
const ARMOR_NO_CLOTH := &"armor_no_cloth"            # {creature, armor}
const WHEELCHAIR_SOUGHT := &"wheelchair_sought"      # {creature, found}
const POLLS_SURVEYED := &"polls_surveyed"            # {creature, approval, concern, survey}
const RECRUIT_FOUND := &"recruit_found"              # {creature, candidates}
const TREATMENT_NEEDED := &"treatment_needed"        # {creature}
const CREATURE_PROMOTED := &"creature_promoted"      # {creature, replacing, founder}
const LEADERSHIP_LOST := &"leadership_lost"          # {creature}
const CONTACT_LOST := &"contact_lost"                # {creature, hiding}
const CONTACT_REGAINED := &"contact_regained"        # {creature}
const CREATURE_TRANSFERRED := &"creature_transferred" # {creature, location}
const SLEEPER_LEAKED := &"sleeper_leaked"            # {creature, what, location}
const SLEEPER_EXPOSED := &"sleeper_exposed"          # {creature, doing}
const SLEEPER_STOLE := &"sleeper_stole"              # {creature, items}
const SLEEPER_RECRUITED := &"sleeper_recruited"      # {creature, recruit}
const CREATURE_ABANDONED := &"creature_abandoned"    # {creature}
const HACK_DEFACED := &"hack_defaced"                # {what, target, issue, team}
const GRAFFITI_TAGGED := &"graffiti_tagged"          # {creature}
const GRAFFITI_MURAL_STARTED := &"graffiti_mural_started" # {creature, issue}
const GRAFFITI_MURAL_WORKED := &"graffiti_mural_worked"   # {creature}
const GRAFFITI_MURAL_DONE := &"graffiti_mural_done"  # {creature, issue, power}
const GRAFFITI_SPOTTED := &"graffiti_spotted"        # {creature, mural}
const SPRAYCAN_TAKEN := &"spraycan_taken"            # {creature, from_base}
const SPRAYCAN_BOUGHT := &"spraycan_bought"          # {creature}
const SPRAYCAN_MISSING := &"spraycan_missing"        # {creature}
const RECRUIT_MET := &"recruit_met"                  # {creature, recruit}
const RECRUIT_MISSED := &"recruit_missed"            # {creature, recruit}
const RECRUIT_DISCUSSED := &"recruit_discussed"      # {creature, recruit, topic, with_props}
const RECRUIT_PERSUADED := &"recruit_persuaded"      # {recruit, warmly}
const RECRUIT_LOST := &"recruit_lost"                # {creature, recruit, politely}
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
const SENTENCE_PASSED := &"sentence_passed"          # {creature, outcome, sentence, death}
const JURY_SEATED := &"jury_seated"                  # {jury, manner}
const TRIAL_ARGUED := &"trial_argued"                # {creature, jury, defense}
const CONFESSED := &"confessed"                      # {creature, against}
const DEPORTED := &"deported"                        # {creature, executed}
const REPOLLUTED := &"repolluted"                    # {creature}
const PRISON_SCENE := &"prison_scene"                # {creature, kind, effect}
const PRISON_ESCAPE := &"prison_escape"              # {creature, manner, others}
const EXECUTED := &"executed"                        # {creature, method}
const RELEASED := &"released"                        # {creature}

# --- Sites, combat and chases ---------------------------------------------

const SITE_ENTERED := &"site_entered"                # {location, squad, mapped}
const SITE_LEFT := &"site_left"                      # {location}
const SITE_ALARM_RAISED := &"site_alarm_raised"
const SITE_ALIENATED := &"site_alienated"           # {level}
const SQUAD_UNSEEN := &"squad_unseen"
const SQUAD_ACTED_NATURAL := &"squad_acted_natural"
const SQUAD_FUMBLED := &"squad_fumbled"              # {creature, manner}
const SQUAD_SUSPECTED := &"squad_suspected"          # {creature, patience}
const SITE_PANIC_SENSED := &"site_panic_sensed"
const ATTACK_RESOLVED := &"attack_resolved"          # {attacker, target}
const ENEMY_FLED := &"enemy_fled"                    # {creature, crawling}
const BODY_DROPPED := &"body_dropped"                # {creature, holder}
const CREATURE_HAULED := &"creature_hauled"          # {creature, carrier}
const MARTYR_ABANDONED := &"martyr_abandoned"        # {creature}
const CREATURE_BLED := &"creature_bled"              # {creature, amount}
const CREATURE_BURNED := &"creature_burned"          # {creature, amount}
const BLEEDING_STOPPED := &"bleeding_stopped"        # {creature, medic}
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
const CHASE_DRIVER_CHANGED := &"chase_driver_changed" # {creature, vehicle}
const CHASE_CAR_CRASHED := &"chase_car_crashed"      # {vehicle, friendly, manner, victims}
const CHASE_CRASH_SURVIVED := &"chase_crash_survived" # {creature, manner}
const CHASE_PRISONER_KILLED := &"chase_prisoner_killed" # {creature, manner}
const CHASE_DODGED := &"chase_dodged"
const CHASE_OBSTACLE_MET := &"chase_obstacle_met"    # {obstacle}
const CHASE_PULLED_OVER := &"chase_pulled_over"
const CHASE_LOST_PURSUIT := &"chase_lost_pursuit"  # {creature, manner}
const CHASE_STILL_FOLLOWED := &"chase_still_followed" # {creature}
const CHASE_BROKE_AWAY := &"chase_broke_away"        # {creature}
const CHASE_CAUGHT := &"chase_caught"                # {creature, by, fatal}
const CHASE_OUTPACED := &"chase_outpaced"            # {creature, trapped}
const CHASE_UNSTOPPABLE := &"chase_unstoppable"      # {creature, manner}
const HOSTAGE_FREED := &"hostage_freed"              # {creature}
const HOSTAGE_ESCAPED := &"hostage_escaped"          # {creature}
const HOSTAGE_EXECUTED := &"hostage_executed"        # {creature, by}
const HOSTAGE_BEATEN := &"hostage_beaten"            # {creature, tortured}
const HOSTAGE_DRUGGED := &"hostage_drugged"          # {creature, overdose}
const HOSTAGE_TALKED_TO := &"hostage_talked_to"      # {creature, by, result}
const HOSTAGE_CONVERTED := &"hostage_converted"      # {creature, by}
const HOSTAGE_DIED := &"hostage_died"                # {creature, cause}
const CREATURE_KIDNAPPED := &"creature_kidnapped"    # {creature, base}
const SIEGE_STARTED := &"siege_started"              # {location, attacker}
const SIEGE_PLANNED := &"siege_planned"              # {location, attacker}
const SIEGE_WARNED := &"siege_warned"                # {location, escalation}
const SIEGE_RAIDED_EMPTY := &"siege_raided_empty"    # {location}
const SIEGE_ASSAULT := &"siege_assault"              # {location}
const SIEGE_BLACKOUT := &"siege_blackout"            # {location}
const SIEGE_NEAR_MISS := &"siege_near_miss"          # {creature, manner}
const SIEGE_AIR_REPELLED := &"siege_air_repelled"    # {location}
const SIEGE_AIR_MISSED := &"siege_air_missed"        # {location}
const SIEGE_WALLS_BREACHED := &"siege_walls_breached" # {location, what}
const SIEGE_INTERVIEW := &"siege_interview"          # {location, creature, power, outlet, flavour}
const SIEGE_ENDED := &"siege_ended"

# --- Game lifecycle --------------------------------------------------------

const GAME_STARTED := &"game_started"
const AMENDMENT_PASSED := &"amendment_passed"        # {amendment}
const GAME_WON := &"game_won"                        # {condition}
const GAME_LOST := &"game_lost"                      # {condition}
