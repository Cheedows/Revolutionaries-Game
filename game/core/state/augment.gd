class_name Augment
extends RefCounted
## One installed augmentation. Mirrors the Augmentation class in
## src/creature/augmentation.h.

## Idname of the type in data/augments/.
var type: StringName = &""

## Whether the augment is working; the original can damage them.
var functional: bool = true
