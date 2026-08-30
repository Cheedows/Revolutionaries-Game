class_name VehicleType
extends Resource
## A vehicle. Mirrors src/vehicle/vehicletype.cpp and art/vehicles.xml.

@export var idname: StringName = &""
@export var longname: String = "UNDEFINED"
@export var shortname: String = ""

@export var price: int = 0
@export var sleeperprice: int = 0
@export var available_at_dealership: bool = false

## Concealment/handling class.
@export var size: int = 0

## Model-year generation rule, evaluated at spawn time.
@export var year_start_at_year: int = 0
@export var year_start_at_current_year: bool = false
@export var year_add: int = 0
@export var year_add_random: int = 0
@export var year_add_random_up_to_current_year: bool = false

## Paint and display colours the vehicle may spawn with.
@export var colors: Array[StringName] = []
@export var display_colors: Array[StringName] = []

## Driving and dodging bonuses scale with the driver's skill, then flatten.
@export var drivebonus_base: int = 0
@export var drivebonus_skillfactor: float = 1.0
@export var drivebonus_softlimit: int = 8
@export var drivebonus_hardlimit: int = 99
@export var dodgebonus_base: int = 0
@export var dodgebonus_skillfactor: float = 1.0
@export var dodgebonus_softlimit: int = 8
@export var dodgebonus_hardlimit: int = 99

## Bonus to attacks made from the vehicle.
@export var attackbonus_driver: int = 0
@export var attackbonus_passenger: int = 0

## Body armor, rolled between the low and high bounds around a midpoint.
@export var armor_low_min: int = 0
@export var armor_low_max: int = 0
@export var armor_high_min: int = 0
@export var armor_high_max: int = 0
@export var armor_midpoint: int = 0

## Car theft parameters.
@export var steal_difficulty_to_find: int = 0
@export var steal_touch_alarm_chance: int = 0
@export var steal_sense_alarm_chance: int = 0
@export var steal_juice: int = 0
@export var steal_extra_heat: int = 0
