class_name FlirtText
extends RefCounted
## Chatting somebody up, in the forty-seven ways the original offers.
##
## None of them is good. A country that has abolished free speech is down to
## three, and those are worse. The line is chosen before the roll that decides
## whether it works — [Flirting] says so, and now carries which — so this says
## what was actually said rather than that somebody tried their luck.
##
## Word for word from doYouComeHereOften() in src/sitemode/talk.cpp.

const LINES: Array[String] = [
	"\"Hey baby, you're kinda ugly.  I like that.\"",
	"\"I lost my phone number.  Could I have yours?\"",
	"\"Hey, you wanna go rub one off?\"",
	"\"Hot damn.  You're built like a brick shithouse, honey.\"",
	"\"I know I've seen you on the back of a milk carton, cuz you've been missing from my life.\"",
	"\"I'm big where it counts.\"",
	"\"Daaaaaamn girl, I want to wrap your legs around my face and wear you like a feed bag!\"",
	"\"Let's play squirrel.  I'll bust a nut in your hole.\"",
	"\"You know, if I were you, I'd have sex with me.\"",
	"\"You don't sweat much for a fat chick.\"",
	"\"Fuck me if I'm wrong but you want to kiss me, right?\"",
	"\"Your parents must be retarded, because you are special.\"",
	"\"Let's play trains...  you can sit on my face and I will chew chew chew.\"",
	"\"Is it hot in here or is it just you?\"",
	"\"I may not be Fred Flintstone, but I can make your bed rock!\"",
	"\"What do you say we go behind a rock and get a little boulder?\"",
	"\"Do you have stars on your panties?  Your ass is outta this world!\"",
	"\"Those pants would look great on the floor of my bedroom.\"",
	"\"If I said you had a nice body, would you hold it against me?\"",
	"\"Are you tired?  You've been running around in my thoughts all day.\"",
	"\"If I could change the alphabet baby, I would put the U and I together!\"",
	"\"Your lips look sweet.  Can I taste them?\"",
	"\"Nice shoes.  Wanna fuck?\"",
	"\"Your sexuality makes me nervous and this frustrates me.\"",
	"\"Are you Jamaican?  Cuz Jamaican me horny.\"",
	"\"Hey pop tart, fancy coming in my toaster of love?\"",
	"\"Wanna play army?  You lie down and I'll blow you away.\"",
	"\"Can I lick your forehead?\"",
	"\"I have a genital rash.  Will you rub this ointment on me?\"",
	"\"What's your sign?\"",
	"\"Do you work for the post office? Because I could have sworn you were checking out my package.\"",
	"\"I'm not the most attractive person in here, but I'm the only one talking to you.\"",
	"\"Hi.  I suffer from amnesia.  Do I come here often?\"",
	"\"I'm new in town.  Could you give me directions to your apartment?\"",
	"\"Stand still so I can pick you up!\"",
	"\"Your daddy must have been a baker, cuz you've got a nice set of buns.\"",
	"\"If you were a phaser, you'd be set on 'stunning'.\"",
	"\"Is that a keg in your pants?  Cuz I'd love to tap that ass.\"",
	"\"If I could be anything, I'd love to be your bathwater.\"",
	"\"Stop, drop and roll, baby.  You are on fire.\"",
	"\"Do you want to see something swell?\"",
	"\"Excuse me.  Do you want to fuck or should I apologize?\"",
	"\"Say, did we go to different schools together?\"",
	"\"You smell...  Let's go take a shower.\"",
	"\"Roses are red, violets are blue,All my base, are belong to you.\"",
	"\"Did it hurt when you fell from heaven?\"",
	"\"Holy shit you're hot!  I want to have sex with you RIGHT NOW.\"",
]

## What is left of the repertoire once free speech has been legislated away.
const CENSORED: Array[String] = [
	"\"[What church do you go to?]\"",
	"\"[Will you marry me?]\"",
	"\"[Do you believe in abstinence education?]\"",
]


## What was said.
static func said(data: Dictionary) -> String:
	var lines: Array[String] = CENSORED \
			if bool(data.get("censored", false)) else LINES
	return lines[int(data.get("line", 0)) % lines.size()]
