class_name Interrogation
extends RefCounted
## What has been done to a hostage so far. Mirrors the `interrogation` struct
## in src/includes.h, which the original allocates on capture and frees when
## the interrogation ends.

## The techniques, by index. The original's plan starts with the hostage being
## talked to and restrained, and nothing else.
const TALK := 0
const RESTRAIN := 1
const BEAT := 2
const PROPS := 3
const DRUGS := 4
const KILL := 5

## Yesterday's plan, which is what the menu opens on and what the escape check
## reads before today's is chosen.
var techniques: Array[bool] = [true, true, false, false, false, false]

## Total days of hallucinogens, which is what makes them dangerous.
var drug_use: int = 0

## How the hostage feels about each interrogator, by creature id.
var rapport: Dictionary = {}


## The rapport with [param creature_id], which starts at nothing.
func toward(creature_id: int) -> float:
	return float(rapport.get(creature_id, 0.0))


func adjust(creature_id: int, amount: float) -> void:
	rapport[creature_id] = toward(creature_id) + amount
