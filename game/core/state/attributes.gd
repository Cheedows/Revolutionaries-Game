class_name Attributes
extends RefCounted
## A creature's seven attributes, indexed by [constant Ids.ATTRIBUTES].
##
## The original caps every attribute at MAXATTRIBUTE and applies a juice-based
## bonus when a check asks for one; the bonus is a rule, so it lives in
## core/systems/creature/, not here.

const MAXIMUM := 20

var values: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	values.resize(Ids.ATTRIBUTES.size())


func get_value(attribute: StringName) -> int:
	return values[Ids.ATTRIBUTES.find(attribute)]


func set_value(attribute: StringName, amount: int) -> void:
	values[Ids.ATTRIBUTES.find(attribute)] = mini(amount, MAXIMUM)


func adjust(attribute: StringName, amount: int) -> void:
	set_value(attribute, get_value(attribute) + amount)


func duplicate_attributes() -> Attributes:
	var copy := Attributes.new()
	copy.values = values.duplicate()
	return copy
