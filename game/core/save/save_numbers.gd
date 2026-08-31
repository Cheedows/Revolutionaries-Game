class_name SaveNumbers
extends RefCounted
## Turning the loose arrays a document holds back into packed ones.
##
## A save is written through a format that has one number type and one array
## type, so everything comes back as an [Array] of floats and has to be put
## back into the packed array the state actually uses.


static func ints(values: Array) -> PackedInt32Array:
	var packed := PackedInt32Array()
	for value: Variant in values:
		packed.append(int(value))
	return packed


static func longs(values: Array) -> PackedInt64Array:
	var packed := PackedInt64Array()
	for value: Variant in values:
		packed.append(int(value))
	return packed
