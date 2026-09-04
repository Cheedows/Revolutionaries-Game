class_name MajorEventPageText
extends RefCounted
## The half of the world's news that runs as a photograph.
##
## Ports the one-line captions and picture choices of displaymajoreventstory()
## from src/news/majorevent.cpp. Half the major events are a picture and a
## sentence rather than a story, and the picture is named rather than drawn so
## a modern presentation can find its own.

## The picture each caption runs above.
## Where each picture sits in art/newspic.cpc, from the #defines above
## displaymajoreventstory() in src/news/majorevent.cpp. The file holds thirteen
## and the original names twelve of them.
const PICTURE_AT := {
	&"mutant_beast": 0, &"ceo": 1, &"book": 2, &"meltdown": 3,
	&"genetics": 4, &"riverfire": 5, &"dollars": 6, &"tinkywinky": 7,
	&"oil": 8, &"terrorists": 9, &"kkk": 10, &"tshirt": 11,
}

const PICTURES := {
	&"meltdown": &"meltdown", &"hell_on_earth": &"mutant_beast",
	&"killer_food": &"genetics", &"childs_plea": &"tshirt",
	&"ring_of_fire": &"riverfire", &"belly_up": &"dollars",
	&"american_ceo": &"ceo", &"kinky_winky": &"tinkywinky",
	&"oil_crunch": &"oil", &"bastards": &"terrorists",
	&"hate_rally": &"kkk", &"they_are_here": &"tshirt",
	&"reagan_flawed": &"book", &"reagan_the_man": &"book",
}

## The fixed captions, by headline.
const CAPTIONS := {
	&"meltdown": "A nuclear power plant suffers a catastrophic meltdown.",
	&"hell_on_earth": "A mutant animal has escaped from a lab and killed "
			+ "thirty people.",
	&"killer_food": "Over a hundred people become sick from genetically "
			+ "modified food.",
	&"childs_plea": "A T-shirt in a store is found scrawled with a message "
			+ "from a sweatshop worker.",
	&"ring_of_fire": "The Ohio River caught on fire again.",
	&"belly_up": "An enormous company files for bankruptcy, shattering the "
			+ "previous record.",
	&"kinky_winky": "Jerry Falwell explains the truth about Tinky Winky.  Again.",
	&"oil_crunch": "OPEC cuts oil production sharply in response to a US "
			+ "foreign policy decision.",
	&"hate_rally": "Free speech advocates fight hard to let a white "
			+ "supremacist rally take place.",
}

## What there is to know about a chief executive.
const CEO_FACTS := [
	"regularly visits prostitutes.",
	"seeks the aid of psychics.",
	"donated millions to the KKK.",
	"hasn't paid taxes in over 20 years.",
	"took out a contract on his wife.",
	"doesn't know what his company does.",
	"has a zoo of imported exotic worms.",
	"paid millions for high-tech bondage gear.",
	"installed a camera in an office bathroom.",
	"owns slaves in another country.",
]

## The months the autumn range is already in the shops.
const AUTUMN_FIRST := 8
const AUTUMN_LAST := 11


## The picture [param headline] runs above, or &"" for a story with words.
static func picture(headline: StringName) -> StringName:
	return PICTURES.get(headline, &"")


## Which picture in [constant CharArt.PICTURES] that is, or -1 for none.
static func picture_at(headline: StringName) -> int:
	return int(PICTURE_AT.get(picture(headline), -1))


## The sentence under it.
static func caption(state: GameState, headline: StringName,
		printed: Dictionary) -> String:
	if CAPTIONS.has(headline):
		return String(CAPTIONS[headline])
	if headline == &"reagan_flawed":
		return "%s: A new book further documenting the other side of Reagan." \
				% printed.get("title", "")
	if headline == &"reagan_the_man":
		return "%s: A new book lauding Reagan and the greatest generation." \
				% printed.get("title", "")
	if headline == &"american_ceo":
		return "This major CEO %s" % _ceo(state, int(printed.get("fact", 0)))
	if headline == &"they_are_here":
		var month := state.calendar.month
		if month >= AUTUMN_FIRST and month <= AUTUMN_LAST:
			return "Fall fashions hit the stores across the country."
		return "Fall fashions are previewed in stores across the country."
	# The police photograph runs without a line under it.
	return ""


## The one fact the law rewrites.
static func _ceo(state: GameState, fact: int) -> String:
	if fact != 0:
		return String(CEO_FACTS[fact])
	var speech := state.law.get_value(&"freespeech")
	var women := state.law.get_value(&"women")
	if speech == -2 and women != -2:
		return "regularly visits [working women]."
	if speech == -2 and women == -2:
		return "regularly [donates to sperm banks]."
	return String(CEO_FACTS[0])
