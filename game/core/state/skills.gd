class_name Skills
extends RefCounted
## A creature's skills and the experience banked toward the next level,
## indexed by [constant Ids.SKILLS].
##
## Training banks experience; the original converts it to levels between turns,
## which is a rule and belongs in core/systems/creature/train.gd.

const MAXIMUM := 99

var values: PackedInt32Array = PackedInt32Array()
var experience: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	values.resize(Ids.SKILLS.size())
	experience.resize(Ids.SKILLS.size())


func get_value(skill: StringName) -> int:
	return mini(values[Ids.SKILLS.find(skill)], MAXIMUM)


func set_value(skill: StringName, amount: int) -> void:
	values[Ids.SKILLS.find(skill)] = mini(amount, MAXIMUM)


func get_experience(skill: StringName) -> int:
	return experience[Ids.SKILLS.find(skill)]


func add_experience(skill: StringName, amount: int) -> void:
	var index := Ids.SKILLS.find(skill)
	experience[index] += amount


func clear_experience(skill: StringName) -> void:
	experience[Ids.SKILLS.find(skill)] = 0


func duplicate_skills() -> Skills:
	var copy := Skills.new()
	copy.values = values.duplicate()
	copy.experience = experience.duplicate()
	return copy
