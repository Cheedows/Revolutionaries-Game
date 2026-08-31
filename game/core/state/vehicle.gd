class_name Vehicle
extends RefCounted
## One owned or stolen vehicle. Mirrors the Vehicle class in src/vehicle/.

var id: int = 0

## Idname of the type in data/vehicles/.
var type: StringName = &""

var year: int = 0
var color: StringName = &""

## Body armour rolled at spawn from the type's bounds.
var armor: int = 0

## How well the police know this car: a stolen one carries the theft with it,
## and a fence will not touch anything with any heat on it at all.
var heat: int = 0

## Id of the location where the vehicle is parked.
var location: int = -1
