class_name ConditionText
extends RefCounted
## The one word the original uses for how somebody is holding up.
##
## Ports printhealthstat() from src/common/commondisplay.cpp. The original
## draws this beside every name on the roster and in the squad bar, in a
## short form where the column is eight characters wide and a long form
## everywhere else. Both forms are here because both are the original's.


## How [param creature] is, in a word.
##
## [param small] picks the eight-character form the original squeezes into a
## squad column. The order of the tests is the original's: blood first, then
## the wounds that never heal, worst first, and if nothing is wrong the word
## is which side they are on.
static func of(creature: Creature, small: bool = false) -> String:
	var body := creature.body
	if not creature.alive:
		return "Deceased"
	if body.blood <= 20:
		return "NearDETH" if small else "Near Death"
	if body.blood <= 50:
		return "BadWound" if small else "Badly Wounded"
	if body.blood <= 75:
		return "Wounded"
	if body.blood < 100:
		return "LtWound" if small else "Lightly Wounded"

	var arms := 2
	if body.is_severed(&"arm_right"):
		arms -= 1
	if body.is_severed(&"arm_left"):
		arms -= 1
	var legs := 2
	if body.is_severed(&"leg_right"):
		legs -= 1
	if body.is_severed(&"leg_left"):
		legs -= 1
	var right_eye := body.get_special(&"righteye")
	var left_eye := body.get_special(&"lefteye")
	var nose := body.get_special(&"nose")

	if body.get_special(&"neck") == 2:
		return "NckBroke" if small else "Neck Broken"
	if body.get_special(&"upperspine") == 2:
		return "Quadpleg" if small else "Quadraplegic"
	if body.get_special(&"lowerspine") == 2:
		return "Parapleg" if small else "Paraplegic"
	if right_eye == 0 and left_eye == 0 and nose == 0:
		return "FaceGone" if small else "Face Gone"
	if legs == 0 and arms == 0:
		return "No Limbs"
	if (legs == 1 and arms == 0) or (arms == 1 and legs == 0):
		return "One Limb"
	if legs == 2 and arms == 0:
		return "No Arms"
	if legs == 0 and arms == 2:
		return "No Legs"
	if legs == 1 and arms == 1:
		return "1Arm1Leg" if small else "One Arm, One Leg"
	if arms == 1:
		return "One Arm"
	if legs == 1:
		return "One Leg"
	if right_eye == 0 and left_eye == 0:
		return "Blind"
	if (right_eye == 0 or left_eye == 0) and nose == 0:
		return "FaceMutl" if small else "Face Mutilated"
	if nose == 0:
		return "NoseGone" if small else "Missing Nose"
	if right_eye == 0 or left_eye == 0:
		return "One Eye" if small else "Missing Eye"
	if body.get_special(&"tongue") == 0:
		return "NoTongue" if small else "No Tongue"
	if body.get_special(&"teeth") == 0:
		return "No Teeth"
	if body.get_special(&"teeth") < Body.TEETH:
		return "MisTeeth" if small else "Missing Teeth"

	match Alignment.value_of(creature.alignment):
		Alignment.CONSERVATIVE, Alignment.ARCH_CONSERVATIVE:
			return "Consrvtv" if small else "Conservative"
		Alignment.MODERATE:
			return "Moderate"
	return "Animal" if creature.animal_gloss == &"animal" else "Liberal"
