class_name Rng
extends RefCounted
## Bit-exact port of the Liberal Crime Squad random number generator.
##
## The original is a 32-bit xorshift with a 128-bit state space (George
## Marsaglia's), seeded through a linear congruential generator — see
## [code]r_num()[/code] in [code]src/compat.cpp[/code]. The RNG state is part of
## the save game in the original, and reproducing it exactly is what makes the
## golden-trace parity harness possible. Do not "improve" this.
##
## GDScript integers are 64-bit and signed; every operation below masks back to
## 32 bits to match the original's [code]unsigned long[/code] arithmetic on both
## 32- and 64-bit platforms (the C++ masks explicitly for the same reason).

const _MASK := 0xffffffff
const _STATE_WORDS := 4

## Multiplier and increment of the seeding LCG, from L'Ecuyer via compat.cpp.
const _LCG_MULT := 32310901
const _LCG_INC := 433494437

var _state: PackedInt64Array = PackedInt64Array([0, 0, 0, 0])
var _lcg_seed: int = 0

## How many numbers have been drawn. Not part of the simulation: the parity
## tests compare it against the original's own count, which turns "the fight
## went differently" into "the fight took one roll fewer, here".
var draws: int = 0


func _init(seed_value: int = 0) -> void:
	seed_from(seed_value)


## Seeds the generator reproducibly from a single 32-bit value.
##
## Mirrors [code]initMainRNG()[/code], with the entropy-gathering
## [code]getSeed()[/code] replaced by [param seed_value] so that runs are
## repeatable. The original's own seeding differs only in where that first
## number comes from.
func seed_from(seed_value: int) -> void:
	_lcg_seed = seed_value & _MASK
	_state[0] = _lcg_seed
	for i in range(_STATE_WORDS - 1, -1, -1):
		_state[i] = _next_lcg()


## The generator's whole state, for a save.
##
## The original writes its four seed words straight into the save file, which
## is what makes a reloaded game roll the same numbers a continued one would.
func export_state() -> Dictionary:
	return {"state": Array(_state), "lcg": _lcg_seed, "draws": draws}


## Puts a saved generator state back.
func import_state(recorded: Dictionary) -> void:
	_state = SaveNumbers.longs(recorded["state"])
	_lcg_seed = int(recorded["lcg"])
	draws = int(recorded.get("draws", 0))


## Returns the raw generator output: 1..0xffffffff, never zero.
##
## Mirrors [code]r_num()[/code], including its recovery path for a state that
## has collapsed to all zeroes.
func next() -> int:
	draws += 1
	while true:
		var t: int = _state[0] ^ ((_state[0] << 11) & _MASK)
		_state[0] = _state[1]
		_state[1] = _state[2]
		_state[2] = _state[3]
		_state[3] = _state[3] ^ (_state[3] >> 19) ^ t ^ (t >> 8)
		if _state[3] != 0:
			return _state[3]
		seed_from(_lcg_seed)
	return 0


## Returns a value in 0..[param max_exclusive] - 1.
##
## Mirrors [code]LCSrandom()[/code]. The original scales the raw draw through a
## division; the mathematically equivalent integer form is used here because it
## cannot round differently between platforms. Proven equal to the C++ over the
## full draw range by [code]tests/unit/test_rng.gd[/code].
##
## A bound of zero or less still draws, and still returns zero or a negative
## number. That is not a nicety: the original's map generator asks for
## [code]LCSrandom(dy - 3)[/code] without checking that dy exceeds three, and
## skipping the draw there rearranges every building.
func below(max_exclusive: int) -> int:
	return (max_exclusive * (next() - 1)) / _MASK


## Returns true with probability 1 / [param one_in]. Reads better than
## [code]below(n) == 0[/code] at call sites, and matches the original's
## pervasive [code]!LCSrandom(n)[/code] idiom exactly.
func one_in(one_in_count: int) -> bool:
	return below(one_in_count) == 0


## Returns a value in [param low]..[param high] inclusive.
func between(low: int, high: int) -> int:
	if high <= low:
		return low
	return low + below(high - low + 1)


## Returns a random element of [param items], or null when empty.
func pick(items: Array) -> Variant:
	if items.is_empty():
		return null
	return items[below(items.size())]


## The four state words, for save games and trace comparison.
func get_state() -> PackedInt64Array:
	return _state.duplicate()


## Restores state captured by [method get_state].
func set_state(state: PackedInt64Array) -> void:
	assert(state.size() == _STATE_WORDS, "RNG state must be 4 words")
	_state = state.duplicate()


func _next_lcg() -> int:
	_state[0] = (_state[0] * _LCG_MULT + _LCG_INC) & _MASK
	return _state[0]
