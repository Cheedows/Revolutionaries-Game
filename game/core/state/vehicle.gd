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

## Whether the police can tie the vehicle to a crime.
var is_hot: bool = false

## Id of the location where the vehicle is parked.
var location: int = -1
