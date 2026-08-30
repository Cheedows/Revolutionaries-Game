extends Node
## Single source of truth for every player-facing name.
##
## The C++ original hardcodes the organisation's name in 263 places. Nothing in
## this port may hardcode it. All game text in data/text/ uses the tokens below
## and is resolved through [method apply]. Renaming the game is an edit to this
## file plus a reimport — see docs/port/ARCHITECTURE.md §6.

## The game's title, as shown in the window and on the title screen.
const GAME_TITLE := "Revolutionaries"

## The player's organisation. Was "Liberal Crime Squad".
const ORG_NAME := "Revolutionaries"

## Short form / acronym for the organisation. Was "LCS".
const ORG_SHORT := "RVL"

## A single member of the organisation. Was "Liberal".
const ORG_MEMBER := "Revolutionary"

## Plural of [constant ORG_MEMBER].
const ORG_MEMBERS := "Revolutionaries"

## The opposing ideology's adherent. Was "Conservative".
##
## Note: unlike the names above this is *mechanics*, not branding — the game
## models an alignment axis and these words label its poles. It is tokenised so
## the setting can be re-themed, but doing so is a design decision.
const FOE_MEMBER := "Conservative"

## Plural of [constant FOE_MEMBER].
const FOE_MEMBERS := "Conservatives"

const _TOKENS := {
	"{GAME_TITLE}": GAME_TITLE,
	"{ORG_NAME}": ORG_NAME,
	"{ORG_SHORT}": ORG_SHORT,
	"{ORG_MEMBER}": ORG_MEMBER,
	"{ORG_MEMBERS}": ORG_MEMBERS,
	"{FOE_MEMBER}": FOE_MEMBER,
	"{FOE_MEMBERS}": FOE_MEMBERS,
}


## Resolves every branding token in [param text].
static func apply(text: String) -> String:
	var out := text
	for token: String in _TOKENS:
		if out.contains(token):
			out = out.replace(token, _TOKENS[token])
	return out


## Every token this class understands, for validation tooling.
static func tokens() -> Array:
	return _TOKENS.keys()
