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

## The states a control can be in, as colours.
##
## A control has more to say than "here I am". It can be the one the keyboard
## is on, the one the thumb is down on, one of several that are switched on, or
## one that cannot be used at all — and a player who cannot tell those apart is
## playing a screenshot. These are named for the state rather than for the
## widget, so a toggle and a button in the same state look the same.

## The keyboard is here. Wide and bright: a focus ring nobody can see is not a
## focus ring.
const FOCUS := Color("8ab4f8")

## The pointer is over it, or a finger is resting on it.
const HOVER := Color("2e3440")

## It is being pressed right now.
const PRESSED := Color("39435a")

## It is switched on. The same green the player's own people are drawn in,
## because "on" here always means "the Squad is doing this".
const ON := LIBERAL

## It cannot be used, and the reason is elsewhere on screen.
const DISABLED := Color("22262e")


## The colour for a political alignment on the -2..+2 scale.
static func for_alignment(value: int) -> Color:
	if value >= Alignment.LIBERAL:
		return LIBERAL
	if value <= Alignment.CONSERVATIVE:
		return CONSERVATIVE
	return MODERATE
