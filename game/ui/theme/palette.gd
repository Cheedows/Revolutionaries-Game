class_name Palette
extends RefCounted
## The colours the interface is built from.
##
## The original is a 16-colour terminal and leans on that palette for meaning:
## green for the player's people, red for the opposition, white for structure.
## That association is worth keeping even though nothing here is a terminal any
## more, so the palette below is a modern reading of it rather than a departure.

const BACKGROUND := Color("14161a")
const SURFACE := Color("1c1f26")
const SURFACE_RAISED := Color("252932")
const BORDER := Color("343a46")

const TEXT := Color("e6e8ec")
const TEXT_DIM := Color("9aa1ad")
const TEXT_FAINT := Color("6b7280")

## The player's organisation, and the opposition.
const LIBERAL := Color("6ee7a8")
const CONSERVATIVE := Color("f08c8c")
const MODERATE := Color("d7c98b")

## Money in and money out.
const INCOME := Color("6ee7a8")
const EXPENSE := Color("f08c8c")

## Emphasis for headings and the active selection.
const ACCENT := Color("8ab4f8")


## The colour for a political alignment on the -2..+2 scale.
static func for_alignment(value: int) -> Color:
	if value >= Alignment.LIBERAL:
		return LIBERAL
	if value <= Alignment.CONSERVATIVE:
		return CONSERVATIVE
	return MODERATE
