class_name SpecialEdition
extends RefCounted
## The Liberal Guardian's monthly special edition.
##
## Ports choosespecialedition() and printnews() from
## src/monthly/lcsmonthly.cpp. With a printing press in a safehouse, the squad
## can publish one of the documents it has stolen. Running a story is worth a
## great deal to the issue it is about — fifty points, where a raid is worth
## one or two — and it makes an enemy of whoever it was about, who then comes
## looking for the press.
##
## The words are ui/adapters/special_edition_text.gd; what is here is which
## documents can be run, what running one costs the other side, and the rolls
## that decide which angle the story takes.

## The documents worth a special edition, in the original's own alphabetical
## order — it binary-searches this list, so the order is the list.
const PUBLISHABLE: Array[StringName] = [
	&"LOOT_AMRADIOFILES", &"LOOT_CABLENEWSFILES", &"LOOT_CCS_BACKERLIST",
	&"LOOT_CEOLOVELETTERS", &"LOOT_CEOPHOTOS", &"LOOT_CEOTAXPAPERS",
	&"LOOT_CORPFILES", &"LOOT_INTHQDISK", &"LOOT_JUDGEFILES",
	&"LOOT_POLICERECORDS", &"LOOT_PRISONFILES", &"LOOT_RESEARCHFILES",
	&"LOOT_SECRETDOCUMENTS",
]

## What every story is worth to how well known the organisation is, and what a
## story about a corporation's own files is worth per press.
const RECOGNITION := 10

## What a story is worth to the issue it is about.
const BIG := 50
const MIDDLING := 25
const SMALL := 15
const SLIGHT := 10
const PRISON_SLIGHT := 20

## And what the exposure of the other side's backers is worth.
const CCS_EXPOSED := 100

## How many angles each document can be run from, and which of them move
## something beyond the story's own issue. Each entry is
## [rolls, {angle: [[view, force], ...]}].
const ANGLES := {
	&"LOOT_CEOPHOTOS": [10, {
		0: [[&"animalresearch", SMALL]],
		2: [[&"policebehavior", SMALL], [&"justices", SLIGHT]],
		5: [[&"genetics", SLIGHT], [&"pollution", SLIGHT]],
		8: [[&"sweatshops", SLIGHT]],
	}],
	&"LOOT_CEOLOVELETTERS": [8, {
		0: [[&"animalresearch", SMALL]],
		1: [[&"justices", SMALL]],
		2: [[&"gay", SMALL]],
		4: [[&"sweatshops", SLIGHT]],
		5: [[&"genetics", SLIGHT], [&"pollution", SLIGHT]],
	}],
	&"LOOT_CEOTAXPAPERS": [1, {0: [[&"taxes", MIDDLING]]}],
	&"LOOT_CORPFILES": [5, {
		0: [[&"genetics", BIG]], 1: [[&"gay", BIG]], 2: [[&"women", BIG]],
		3: [[&"sweatshops", BIG]], 4: [[&"taxes", BIG]],
	}],
	&"LOOT_INTHQDISK": [6, {
		1: [[&"justices", BIG]], 3: [[&"freespeech", BIG]],
		4: [[&"gay", BIG]], 5: [[&"women", BIG]],
	}],
	&"LOOT_POLICERECORDS": [6, {
		0: [[&"torture", SMALL]], 1: [[&"torture", BIG]],
		2: [[&"intelligence", SMALL]],
		5: [[&"deathpenalty", BIG], [&"prisons", PRISON_SLIGHT]],
	}],
	&"LOOT_JUDGEFILES": [2, {}],
	&"LOOT_RESEARCHFILES": [4, {
		0: [[&"animalresearch", BIG]], 1: [[&"animalresearch", BIG]],
		2: [[&"genetics", BIG]], 3: [[&"genetics", BIG]],
	}],
	&"LOOT_PRISONFILES": [4, {1: [[&"torture", BIG]]}],
	&"LOOT_CABLENEWSFILES": [4, {3: [[&"women", BIG]]}],
	&"LOOT_AMRADIOFILES": [3, {}],
}

## What each story is about, over and above whatever angle it takes, and who it
## makes an enemy of.
const SUBJECT := {
	&"LOOT_CEOPHOTOS": [[&"ceosalary", BIG], [&"corporateculture", BIG]],
	&"LOOT_CEOLOVELETTERS": [[&"ceosalary", BIG], [&"corporateculture", BIG]],
	&"LOOT_CEOTAXPAPERS": [[&"ceosalary", BIG], [&"corporateculture", BIG]],
	&"LOOT_CORPFILES": [[&"ceosalary", BIG], [&"corporateculture", BIG]],
	&"LOOT_CCS_BACKERLIST": [[&"intelligence", BIG],
			[&"conservativecrimesquad", CCS_EXPOSED]],
	&"LOOT_INTHQDISK": [[&"intelligence", BIG]],
	&"LOOT_SECRETDOCUMENTS": [[&"intelligence", BIG]],
	&"LOOT_POLICERECORDS": [[&"policebehavior", BIG]],
	&"LOOT_JUDGEFILES": [[&"justices", BIG]],
	&"LOOT_PRISONFILES": [[&"prisons", BIG], [&"deathpenalty", BIG]],
	&"LOOT_CABLENEWSFILES": [[&"cablenews", BIG]],
	&"LOOT_AMRADIOFILES": [[&"amradio", BIG]],
}
const OFFENDS := {
	&"LOOT_CEOPHOTOS": &"corps", &"LOOT_CEOLOVELETTERS": &"corps",
	&"LOOT_CEOTAXPAPERS": &"corps", &"LOOT_CORPFILES": &"corps",
	&"LOOT_INTHQDISK": &"cia", &"LOOT_SECRETDOCUMENTS": &"cia",
	&"LOOT_CABLENEWSFILES": &"cablenews", &"LOOT_AMRADIOFILES": &"amradio",
}

## The two documents whose publication is treason.
const TREASONOUS: Array[StringName] = [
	&"LOOT_INTHQDISK", &"LOOT_SECRETDOCUMENTS",
]

## The story about corporate files is worth its recognition per press rather
## than a flat ten.
const PER_PRESS: Array[StringName] = [&"LOOT_CORPFILES"]
