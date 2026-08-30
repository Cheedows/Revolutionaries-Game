class_name Intent
extends RefCounted
## A decision the simulation needs from the player.
##
## This replaces the original's 736 blocking getkey() calls. A system never
## waits: when it reaches a choice it returns a PendingIntent describing the
## question and stops. app/session.gd hands the answer back and the system
## resumes from there.
##
## Because intents are data, a whole playthrough is a list of them — which is
## what makes a recorded run replayable against the golden traces.

## What is being asked. One of the constants below.
var type: StringName

## The options, when the choice is a selection: an Array of Dictionaries with
## at least an "id" and enough fields for the UI to describe each option.
var options: Array[Dictionary]

## Context the UI needs to frame the question (whose turn, which site, ...).
var context: Dictionary

## Whether the player may decline entirely.
var cancellable: bool


func _init(intent_type: StringName, intent_options: Array[Dictionary] = [],
		intent_context: Dictionary = {}, is_cancellable: bool = true) -> void:
	type = intent_type
	options = intent_options
	context = intent_context
	cancellable = is_cancellable


func _to_string() -> String:
	return "Intent(%s, %d option(s))" % [type, options.size()]


# --- Base and squad management --------------------------------------------

const CHOOSE_BASE_ACTION := &"choose_base_action"
const ASSIGN_ACTIVITY := &"assign_activity"          # per liberal
const FORM_SQUAD := &"form_squad"
const EQUIP_SQUAD := &"equip_squad"
const CHOOSE_VEHICLE := &"choose_vehicle"
const CHOOSE_DESTINATION := &"choose_destination"

# --- Sites, combat and chases ---------------------------------------------

const CHOOSE_SITE_MOVE := &"choose_site_move"
const CHOOSE_ENCOUNTER_RESPONSE := &"choose_encounter_response"
const CHOOSE_ATTACK_TARGET := &"choose_attack_target"
const CHOOSE_CHASE_ACTION := &"choose_chase_action" # {in_cars, obstacle, can_pull_over, chasers}
const CONFIRM_RETREAT := &"confirm_retreat"
const CONFIRM_NOISY_DOOR := &"confirm_noisy_door"    # {locked, emergency_exit}
const CONFIRM_PICK_LOCK := &"confirm_pick_lock"      # {x, y, z}
const CONFIRM_FORCE_DOOR := &"confirm_force_door"    # {x, y, z, locked}

# --- Interrogation, recruitment and dialogue ------------------------------

const CHOOSE_DIALOGUE := &"choose_dialogue"
const CHOOSE_INTERROGATION_TACTIC := &"choose_interrogation_tactic"
const CONFIRM_RECRUIT := &"confirm_recruit"

# --- Shops and money ------------------------------------------------------

const CHOOSE_SHOP_DEPARTMENT := &"choose_shop_department"
const CHOOSE_PURCHASE := &"choose_purchase"
const CHOOSE_ITEMS_TO_FENCE := &"choose_items_to_fence"

# --- Politics and lifecycle -----------------------------------------------

const CHOOSE_LIBERAL_AGENDA := &"choose_liberal_agenda"
const ACKNOWLEDGE_REPORT := &"acknowledge_report"    # the original's "press any key"
const CONFIRM_NEW_GAME := &"confirm_new_game"
const CHOOSE_FOUNDER_BACKGROUND := &"choose_founder_background"
