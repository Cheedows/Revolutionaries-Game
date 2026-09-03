class_name FounderText
extends RefCounted
## What the founder's ten questions say.
##
## The words are the original's, from makecharacter() in
## src/title/newgame.cpp; what an answer is worth is
## [FounderBackgrounds], which carries no prose at all.

## The ten questions, in order.
const QUESTIONS: Array[String] = [
	"The day I was born in 1984...",
	"When I was bad...",
	"In elementary school...",
	"When I turned 10...",
	"In junior high school...",
	"Things were getting really bad...",
	"Well, I knew it had reached a crescendo when...",
	"I was only 15 when I ran away, and...",
	"Life went on.  On my 18th birthday...",
	"For the past few years, I've been...",
]

## The five answers to each, in order.
const ANSWERS: Array[Array] = [
	[
		"the Polish priest Popieluszko was kidnapped by government agents.",
		"was the 3rd anniversary of the assassination attempt on Ronald Reagan.",
		"the Macintosh was introduced.",
		"the Nobel Peace Prize went to Desmond Tutu for opposition to apartheid.",
		"the Sandanista Front won the elections in Nicaragua.",
	],
	[
		"my parents grounded me and hid my toys, but I knew where they put them.",
		"my father beat me.  I learned to take a punch earlier than most.",
		"I was sent to my room, where I studied quietly by myself, alone.",
		"my parents argued with each other about me, but I was never punished.",
		"my father lectured me endlessly, trying to make me think like him.",
	],
	[
		"I was mischievous, and always up to something.",
		"I had a lot of repressed anger.  I hurt animals.",
		"I was at the head of the class, and I worked very hard.",
		"I was unruly and often fought with the other children.",
		"I was the class clown.  I even had some friends.",
	],
	[
		"my parents divorced.  Whenever I talked, they argued, so I stayed quiet.",
		"my parents divorced.  Violently.",
		"my parents divorced.  Acrimoniously.  I once tripped over the paperwork!",
		"my parents divorced.  Mom slept with the divorce lawyer.",
		"my parents divorced.  It still hurts to read my old diary.",
	],
	[
		"I was into chemistry.  I wanted to know what made the world tick.",
		"I played guitar in a grunge band.  We sucked, but so did life.",
		"I drew things, a lot.  I was drawing a world better than this.",
		"I played violent video games at home.  I was a total outcast.",
		"I was obsessed with swords, and started lifting weights.",
	],
	[
		"when I stole my first car.  I got a few blocks before I totaled it.",
		"and I went to live with my dad.  He had been in Nam and he still drank.",
		"and I went completely goth.  I had no friends and made costumes by myself.",
		"when I was sent to religious counseling, just stressing me out more.",
		"and I tried being a teacher's assistant.  It just made me a target.",
	],
	[
		"I stole a cop car when I was only 14.  I went to juvie for 6 months.",
		"my step mom shot her ex-husband, my dad, with a shotgun.  She got off.",
		"I tried wrestling for a quarter, desperate to fit in.",
		"I got caught making out, and now I needed to be 'cured' of homosexuality.",
		"I resorted to controlling people.  Had my own clique of outcasts.",
	],
	[
		"I started robbing houses:  rich people only.  I was fed up with their crap.",
		"I hung out with thugs and beat the shit out of people.",
		"I got a horrible job working fast food, smiling as people fed the man.",
		"I let people pay me for sex.  I needed the money to survive.",
		"I volunteered for a left-wing candidate. It wasn't *real*, though, you know?",
	],
	[
		"I got my hands on a sports car. The owner must have been pissed.",
		"I bought myself an assault rifle.",
		"I celebrated.  I'd saved a thousand bucks!",
		"I went to a party and met a cool law student.  We've been dating since.",
		"I managed to acquire secret maps of several major buildings downtown.",
	],
	[
		"stealing from Corporations.  I know they're still keeping more secrets.",
		"a violent criminal.  Nothing can change me, or stand in my way.",
		"taking college courses.  I can see how much the country needs help.",
		"surviving alone, just like anyone.  But we can't go on like this.",
		"writing my manifesto and refining my image.  I'm ready to lead.",
	],
]


## What question [param index] asks.
static func question(index: int) -> String:
	return QUESTIONS[index] if index < QUESTIONS.size() else ""


## What answer [param option] to question [param index] says.
static func answer(index: int, option: int) -> String:
	if index >= ANSWERS.size() or option >= ANSWERS[index].size():
		return ""
	return ANSWERS[index][option]


## What answer [param option] to question [param index] is worth, in words.
##
## A deliberate departure, and the only one on this screen. The original knows
## exactly what each answer gives — it is written down the side of
## makecharacter() in newgame.cpp — and it writes it in a C++ comment:
##
##     addstr("A - the Polish priest Popieluszko was kidnapped...");
##     //ATTRIBUTE_AGILITY 2
##
## So the numbers exist and the player has never been allowed to see them. That
## is a terminal-era choice about screen space as much as about mystery, and
## ten questions answered blind is ten questions answered at random the first
## time and from a wiki every time after.
##
## Only attributes and skills. The eighth question hands out a car, a rifle, a
## thousand dollars, a lawyer or a set of maps, and its own answers already say
## so — "I got my hands on a sports car" needs no footnote.
static func bonus(index: int, option: int) -> String:
	if index >= FounderBackgrounds.TABLE.size():
		return ""
	var answers: Array = FounderBackgrounds.TABLE[index]
	if option >= answers.size():
		return ""
	var worth: Dictionary = answers[option]
	var said := PackedStringArray()
	for names: Array in [Ids.ATTRIBUTES, Ids.SKILLS]:
		var key: StringName = &"attributes" if names == Ids.ATTRIBUTES \
				else &"skills"
		var given: Dictionary = worth.get(key, {})
		# In the game's own order rather than the dictionary's, so the same
		# answer reads the same way every time it is drawn.
		for name: StringName in names:
			if not given.has(name):
				continue
			var called := StatText.attribute(name) if key == &"attributes" \
					else StatText.skill(name)
			said.append("%s%d %s" % ["+" if int(given[name]) > 0 else "",
					int(given[name]), called])
	return ", ".join(said)
