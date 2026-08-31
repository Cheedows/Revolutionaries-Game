class_name NewsAds
extends RefCounted
## The advertisements around a printed story.
##
## Ports displayads() and displaysinglead() from src/news/ads.cpp. The deeper
## into the paper a story runs the more advertisements are packed around it,
## and each one is placed, sized and written by rolling — so a story on page
## forty costs the sequence a great deal more than one on the front.

## Six advertisements, of which the sixth is a personal.
const PERSONAL := 6
const CHOICES := 6

## The most that can fit around one story.
const MOST := 6

## The grid an advertisement lands in: two columns, three rows.
const COLUMNS := 2
const ROWS := 3

## How much the outer edge of a column wanders.
const EDGE_SPREAD := 4

## What the box is drawn out of.
const BORDERS: Array[StringName] = [
	&"light_shade", &"medium_shade", &"dark_shade", &"full_block",
	&"cross", &"asterisk",
]

## The page each paper starts selling space on, and every ten pages after.
const FIRST_PAGE := 10
const FIRST_GUARDIAN_PAGE := 2
const PAGE_STEP := 10

## The headline on a personal, which is coyer in the paper of record.
const COY: Array[StringName] = [
	&"searching_for_love", &"seeking_love", &"are_you_lonely",
	&"looking_for_love", &"soulmate_wanted",
]
const FRANK: Array[StringName] = [
	&"searching_for_sex", &"seeking_sex", &"wanna_have_sex",
	&"looking_for_sex", &"sex_partner_wanted",
]

## What the second-hand furniture and the second-hand car cost, and how long
## the lawyer has been at it.
const CHAIR_BASE := 400
const CHAIR_SPREAD := 201
const CAR_AGE_SPREAD := 15
const CAR_PRICE_BASE := 15
const CAR_PRICE_SPREAD := 16
const LAWYER_BASE := 20
const LAWYER_SPREAD := 11


## Every advertisement around [param story], in the order they are placed.
static func run(rng: Rng, story: NewsStory, guardian: bool,
		year: int) -> Array[Dictionary]:
	var wanted := _how_many(rng, story, guardian)
	var taken := {}
	var placed: Array[Dictionary] = []
	for _index in mini(wanted, MOST):
		placed.append(_one(rng, taken, guardian, year))
	return placed


## How many the page will carry. The first is free; every ten pages after
## that buys one or two more.
static func _how_many(rng: Rng, story: NewsStory, guardian: bool) -> int:
	var page := story.guardian_page if guardian else story.page
	var first := FIRST_GUARDIAN_PAGE if guardian else FIRST_PAGE
	var step := 1 if guardian else PAGE_STEP
	var total := 0
	if page >= first:
		total += 1
	for further in 4:
		if page >= first + step * (further + 1):
			total += rng.below(2) + 1
	return total


## One advertisement: where it goes, which one it is, and what it says.
##
## **Original quirk, reproduced.** The search for an advertisement nobody else
## on the page is already running restarts its whole scan every time it
## collides, so a crowded page can cost a great many draws before it settles.
static func _one(rng: Rng, taken: Dictionary, guardian: bool,
		year: int) -> Dictionary:
	var column := 0
	var row := 0
	while true:
		column = rng.below(COLUMNS)
		row = rng.below(ROWS)
		if not taken.has(Vector2i(column, row)):
			break

	var choice := rng.below(CHOICES) + 1
	while true:
		var clash := false
		for spot: Vector2i in taken:
			if taken[spot] == choice:
				choice = rng.below(CHOICES) + 1
				clash = true
				break
		if not clash:
			break
	taken[Vector2i(column, row)] = choice

	var edge := rng.below(EDGE_SPREAD)
	var border: StringName = BORDERS[rng.below(BORDERS.size())]
	var advertisement := {
		"column": column, "row": row, "choice": choice, "edge": edge,
		"border": border, "guardian": guardian,
	}
	advertisement.merge(_content(rng, choice, guardian, year))
	return advertisement


## The words, and the numbers in them.
static func _content(rng: Rng, choice: int, guardian: bool,
		year: int) -> Dictionary:
	if choice == PERSONAL:
		var headlines: Array[StringName] = FRANK if guardian else COY
		var personal := {"headline": headlines[rng.below(headlines.size())]}
		personal.merge(Personals.advertisement(rng))
		return personal
	if guardian:
		if choice == 2:
			return {"years": rng.below(LAWYER_SPREAD) + LAWYER_BASE}
		return {}
	if choice == 2:
		return {"price": rng.below(CHAIR_SPREAD) + CHAIR_BASE}
	if choice == 4:
		return {
			"model_year": year - rng.below(CAR_AGE_SPREAD),
			"price": rng.below(CAR_PRICE_SPREAD) + CAR_PRICE_BASE,
		}
	return {}
