class_name OrganText
extends RefCounted
## Original fullstatus special wounds from common/commondisplay.cpp.

const INJURIES := {
	&"heart": "Heart Punctured", &"rightlung": "R. Lung Collapsed",
	&"leftlung": "L. Lung Collapsed", &"neck": "Broken Neck",
	&"upperspine": "Broken Up Spine", &"lowerspine": "Broken Lw Spine",
	&"righteye": "No Right Eye", &"lefteye": "No Left Eye",
	&"nose": "No Nose", &"tongue": "No Tongue", &"liver": "Liver Damaged",
	&"rightkidney": "R. Kidney Damaged", &"leftkidney": "L. Kidney Damaged",
	&"stomach": "Stomach Injured", &"spleen": "Busted Spleen",
}

static func wounds(body: Body) -> Array[String]:
	var lines: Array[String] = []
	for organ: StringName in INJURIES:
		if body.get_special(organ) != 1:
			lines.append(INJURIES[organ])
	var teeth := body.get_special(&"teeth")
	if teeth < Body.TEETH:
		lines.append("No Teeth" if teeth == 0 else
				("Missing a Tooth" if teeth == Body.TEETH - 1 else "Missing Teeth"))
	var ribs := body.get_special(&"ribs")
	if ribs < Body.RIBS:
		lines.append("All Ribs Broken" if ribs == 0 else
				("Broken Rib" if ribs == Body.RIBS - 1 else "Broken Ribs"))
	return lines
