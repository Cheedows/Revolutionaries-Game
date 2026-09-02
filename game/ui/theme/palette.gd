class_name Palette
extends RefCounted
## The colours the interface is built from, and the schemes they come in.
##
## Every colour in the game is named here for the job it does — the surface a
## panel sits on, the text you read, the side somebody is on — and never for
## what it looks like. A widget asks for [member CONSERVATIVE] and gets
## whatever the current scheme says that is. Nothing below a screen names a
## colour, so a scheme can be swapped in one call and the whole interface
## follows.
##
## They are variables rather than constants for exactly that reason. See
## [method use].
##
## Three rules run through all of it, and they are not taste:
##
## The ground is dark grey, never black. Light text on pure black is a harsher
## contrast than the eye wants to read for long, and a grey ground can carry
## depth — a raised surface is visible against grey and invisible against
## black. Material's dark theme puts the floor at about #121212 and these sit
## near it.
##
## Accents are desaturated. A colour that reads well on white vibrates against
## a dark ground, and the fix is to drop both saturation and intensity rather
## than to pick a different hue.
##
## Depth is a lighter surface, not a shadow. There is no drop shadow anywhere
## in this interface. A panel is one step up from the page, a control is one
## step up from the panel, and that is the whole vocabulary.

## The scheme the game opens with.
const DEFAULT := &"terminal"

# ---------------------------------------------------------------- the schemes

## The original is a sixteen-colour terminal and leans on that palette for
## meaning: green for the player's people, red for the opposition, white for
## structure. This is a modern reading of it rather than a departure — cool
## near-black, and the two sides where they have always been.
const TERMINAL := {
	&"background": "14161a", &"surface": "1c1f26", &"raised": "252932",
	&"border": "343a46",
	&"text": "e6e8ec", &"dim": "9aa1ad", &"faint": "6b7280",
	&"liberal": "6ee7a8", &"conservative": "f08c8c", &"moderate": "d7c98b",
	&"accent": "8ab4f8", &"hover": "2e3440", &"pressed": "39435a",
	&"disabled": "22262e",
	&"income": "6ee7a8", &"expense": "f08c8c",
}

## The game is written in the register of a local newspaper's metro desk, and
## this is that: warm charcoal rather than cool, ink-white rather than blue-
## white, and an amber accent that reads as a desk lamp rather than a hyperlink.
## The two sides stay green and red, but muted the way ink on cheap paper is.
const NEWSPRINT := {
	&"background": "17150f", &"surface": "201d16", &"raised": "2a261d",
	&"border": "3d3729",
	&"text": "ece6d9", &"dim": "a89f8d", &"faint": "746c5d",
	# Tuned rather than picked: the first pair here was a muted green and a
	# muted red that a protanope sees as one colour, which the contrast audit
	# said so. Deepening the red and lifting the green puts them 50 apart in
	# hue and 2.28:1 apart in brightness, so they are two colours either way.
	&"liberal": "b3d69c", &"conservative": "c96b52", &"moderate": "cbb069",
	&"accent": "e0a458", &"hover": "302b20", &"pressed": "3d372a",
	&"disabled": "241f18",
	# Money is not the faction colour here: the brick red that tells a
	# Conservative from a Liberal is too dark to read as a number on a
	# button, so the ledger gets a lighter one.
	&"income": "b3d69c", &"expense": "d4795f",
}

## About one man in twelve cannot reliably tell the green from the red, which
## is the pair this game puts the most meaning on. Blue and orange is the way
## out: blue survives every common kind of colour blindness, and orange sits
## where the confusion lines do not cross. The hues are from Wong's palette,
## lightened for a dark ground.
##
## The green is kept for money, where nothing is being told apart from a red —
## income and expense never appear in the same column.
const SIGNAL := {
	&"background": "121417", &"surface": "1a1d21", &"raised": "23272d",
	&"border": "343941",
	&"text": "e8eaed", &"dim": "9ba2ac", &"faint": "6c7480",
	&"liberal": "6fb8e8", &"conservative": "f0a65c", &"moderate": "9aa2ad",
	# Lavender, which is neither of the two sides. The first draft made this a
	# lighter blue and a Liberal's name sat next to a panel heading in the same
	# hue, so the colour that means "somebody is on our side" and the colour
	# that means "this is a heading" were the same colour.
	&"accent": "b39ddb", &"hover": "2b3138", &"pressed": "36404a",
	&"disabled": "202429",
	&"income": "6ee7a8", &"expense": "f08c8c",
}

const SCHEMES := {
	&"terminal": TERMINAL, &"newsprint": NEWSPRINT, &"signal": SIGNAL,
}

# ----------------------------------------------------------------- the colours

## The page itself.
static var BACKGROUND := Color(TERMINAL[&"background"])

## A panel on the page, one step up.
static var SURFACE := Color(TERMINAL[&"surface"])

## A control on a panel, one step up again.
static var SURFACE_RAISED := Color(TERMINAL[&"raised"])

## The line around a thing.
static var BORDER := Color(TERMINAL[&"border"])

## What you are reading.
static var TEXT := Color(TERMINAL[&"text"])

## What is there for reference — a price, a date, the line under an option.
static var TEXT_DIM := Color(TERMINAL[&"dim"])

## What is there but cannot be used, or is not the point.
static var TEXT_FAINT := Color(TERMINAL[&"faint"])

## The player's organisation, and the opposition.
static var LIBERAL := Color(TERMINAL[&"liberal"])
static var CONSERVATIVE := Color(TERMINAL[&"conservative"])
static var MODERATE := Color(TERMINAL[&"moderate"])

## Money in and money out. These stay green and red in every scheme, tuned to
## it: they never appear in the same column as each other, so nothing is being
## told apart by hue and the convention is worth more than the consistency.
static var INCOME := Color(TERMINAL[&"income"])
static var EXPENSE := Color(TERMINAL[&"expense"])

## Emphasis for headings and the active selection.
static var ACCENT := Color(TERMINAL[&"accent"])

## The keyboard is here. Bright and wide: a focus ring nobody can see is not a
## focus ring.
static var FOCUS := Color(TERMINAL[&"accent"])

## The pointer is over it, or a finger is resting on it.
static var HOVER := Color(TERMINAL[&"hover"])

## It is being pressed right now.
static var PRESSED := Color(TERMINAL[&"pressed"])

## It is switched on.
static var ON := Color(TERMINAL[&"liberal"])

## It cannot be used, and the reason is elsewhere on screen.
static var DISABLED := Color(TERMINAL[&"disabled"])


## Switches the whole interface to [param scheme].
##
## Everything drawn after this reads the new colours. A screen has to rebuild
## its [Theme] to pick them up, which every screen already does on resize —
## see UiTheme.build().
static func use(scheme: StringName) -> void:
	var said: Dictionary = SCHEMES.get(scheme, TERMINAL)
	BACKGROUND = Color(said[&"background"])
	SURFACE = Color(said[&"surface"])
	SURFACE_RAISED = Color(said[&"raised"])
	BORDER = Color(said[&"border"])
	TEXT = Color(said[&"text"])
	TEXT_DIM = Color(said[&"dim"])
	TEXT_FAINT = Color(said[&"faint"])
	LIBERAL = Color(said[&"liberal"])
	CONSERVATIVE = Color(said[&"conservative"])
	MODERATE = Color(said[&"moderate"])
	ACCENT = Color(said[&"accent"])
	FOCUS = Color(said[&"accent"])
	HOVER = Color(said[&"hover"])
	PRESSED = Color(said[&"pressed"])
	ON = Color(said[&"liberal"])
	DISABLED = Color(said[&"disabled"])
	INCOME = Color(said[&"income"])
	EXPENSE = Color(said[&"expense"])


## The colour for a political alignment on the -2..+2 scale.
##
## Colour is never the only thing saying this — see [AlignmentText], which puts
## the word beside it. A player who cannot tell the two hues apart can still
## read the row.
static func for_alignment(value: int) -> Color:
	if value >= Alignment.LIBERAL:
		return LIBERAL
	if value <= Alignment.CONSERVATIVE:
		return CONSERVATIVE
	return MODERATE
