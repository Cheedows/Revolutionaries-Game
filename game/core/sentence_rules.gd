class_name SentenceRules
extends RefCounted
## What each crime is worth in months.
##
## Transcribed from penalize() in src/monthly/justice.cpp. Each charge adds
## [code]base + d(spread)[/code] months per count, and a spread of one rolls a
## die with one side — which costs a draw and always comes up zero, so the
## roll is load-bearing even where the number is not.
##
## Marijuana and flag burning are not here: what they cost depends on the law,
## and murder and treason can turn a sentence into a life term, so all three
## are handled in [Sentencing] itself.

## [base, spread] per count, in the order the original adds them.
const PER_COUNT: Array = [
	[&"kidnapping", 36, 18],
	[&"theft", 1, 4],
	[&"cartheft", 6, 7],
	[&"information", 1, 13],
	[&"commerce", 1, 13],
	[&"ccfraud", 6, 25],
	[&"burial", 3, 12],
	[&"prostitution", 1, 6],
	[&"disturbance", 1, 0],
	[&"publicnudity", 1, 0],
	[&"hireillegal", 1, 0],
	[&"racketeering", 12, 100],
]

## The charges added after marijuana, still per count.
const AFTER_DRUGS: Array = [
	[&"breaking", 1, 0],
	[&"terrorism", 60, 181],
	[&"bankrobbery", 30, 61],
	[&"jury", 30, 61],
	[&"helpescape", 30, 61],
	[&"escaped", 3, 16],
	[&"resist", 1, 1],
	[&"extortion", 6, 1],
	[&"speech", 4, 3],
	[&"vandalism", 1, 0],
	[&"arson", 12, 12],
	[&"armedassault", 12, 1],
	[&"assault", 3, 1],
]

## What marijuana costs, by how illegal it is. An Elite Liberal country does
## not prosecute it at all, so there is no entry and no roll.
const DRUGS := {
	-2: [3, 360],
	-1: [3, 120],
	0: [3, 12],
}

## What burning a flag costs. Under the harshest law it is a coin flip between
## a very long sentence and a life term.
const FLAG_BURNING_SPREAD := [120, 241]
const FLAG_BURNING_HARSH := 36
const FLAG_BURNING_MILD := 1

## Murder is a life term unless the roll beats the number of counts, and the
## more counts there are the less likely that is.
const MURDER_MERCY := 4
const MURDER_SPREAD := [120, 241]

## Nobody is charged with more counts of anything than this.
const MAXIMUM_COUNTS := 10

## A sentence longer than this becomes life terms instead.
const LIFE_THRESHOLD := 1200

## Sentences of three years or more are rounded down to whole years.
const WHOLE_YEARS_FROM := 36
const MONTHS_PER_YEAR := 12

## A lenient life sentence becomes this many months instead.
const MERCY_MIN := 240
const MERCY_SPREAD := 120

## How long a condemned prisoner waits.
const DEATH_ROW := 3
