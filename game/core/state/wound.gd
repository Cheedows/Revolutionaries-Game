class_name Wound
extends RefCounted
## Wound flags stored per body part. Mirrors the WOUND_ bits in
## src/creature/creature.h; the numeric values are what the traces record.

const SHOT := 1 << 0
const CUT := 1 << 1
const BRUISED := 1 << 2
const BURNED := 1 << 3
const BLEEDING := 1 << 4
const TORN := 1 << 5
const NASTY_OFF := 1 << 6
const CLEAN_OFF := 1 << 7

## Either kind of severed limb.
const SEVERED := NASTY_OFF | CLEAN_OFF
