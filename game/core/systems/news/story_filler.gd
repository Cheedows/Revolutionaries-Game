class_name StoryFiller
extends RefCounted
## The column inches nobody reads.
##
## Ports generatefiller() from src/news/news.cpp. The original pads every
## printed story out to a fixed length with rows of tildes, so that a story on
## a page looks like a story. That is presentation — but it draws from the
## sequence while it does it, hundreds of times per story, so the draws have to
## happen here whether or not anything is ever rendered from them.
##
## Returns [code]{"city": String, "words": PackedInt32Array}[/code]: the
## dateline the padding opens with, and the word lengths with a zero where the
## original starts a new paragraph, so a caller that wants to draw the same
## grey block can.

## Every printed story is padded to this many words.
const WORDS := 200

## A word is three to twelve characters long — see [method run] for why that
## is not one roll.
const LENGTH_MIN := 3
const LENGTH_SPREAD := 10

## A new paragraph is possible every fifty words, at one chance in five, and
## never within twenty words of the end.
const PARAGRAPH_EVERY := 50
const PARAGRAPH_ODDS := 5
const PARAGRAPH_MARGIN := 20


## Draws [param amount] words' worth of filler.
##
## **Original quirk, reproduced, and the reason this is not one roll a word.**
## The inner loop is written `for(i=0;i<LCSrandom(10)+3;i++)`, so its bound is
## rolled afresh on every pass — the length of a word is a walk that ends the
## first time the roll comes in at or below the letters written so far. It
## costs several draws a word instead of one, which is most of what the
## newspaper takes out of the sequence.
static func run(rng: Rng, amount: int = WORDS) -> Dictionary:
	# The padding opens with its own dateline, from somewhere else entirely.
	var city := Dateline.city(rng)
	var words := PackedInt32Array()
	var paragraph := 0
	var left := amount
	while left > 0:
		paragraph += 1
		var letters := 0
		while letters < rng.below(LENGTH_SPREAD) + LENGTH_MIN:
			letters += 1
		words.append(letters)
		if paragraph >= PARAGRAPH_EVERY and rng.one_in(PARAGRAPH_ODDS) \
				and left > PARAGRAPH_MARGIN:
			paragraph = 0
			words.append(0)
		left -= 1
	return {"city": city, "words": words}
