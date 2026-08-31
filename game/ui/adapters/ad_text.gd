class_name AdText
extends RefCounted
## The advertisements around a printed story.
##
## Says what [NewsAds] placed. The words are the original's, from
## displaysinglead() in src/news/ads.cpp, where they are drawn centred inside a
## box of shading characters; here they are lines, and where the box went is in
## the advertisement itself.

## The headline on a personal, coy in the paper of record and not in the other.
const PERSONAL_HEADLINE := {
	&"searching_for_love": "Searching For Love",
	&"seeking_love": "Seeking Love",
	&"are_you_lonely": "Are You Lonely?",
	&"looking_for_love": "Looking For Love",
	&"soulmate_wanted": "Soulmate Wanted",
	&"searching_for_sex": "Searching For Sex",
	&"seeking_sex": "Seeking Sex",
	&"wanna_have_sex": "Wanna Have Sex?",
	&"looking_for_sex": "Looking For Sex",
	&"sex_partner_wanted": "Sex Partner Wanted",
}

## What the paper of record sells, by the choice that was rolled. An empty
## line is the original's blank between paragraphs.
const REGULAR := {
	1: ["No Fee", "Consignment Program", "", "Call for Details"],
	3: ["Paris Flea Market", "", "Sale", "50% Off"],
	5: ["Spa", "Health, Beauty", "and Fitness", "", "7 Days a Week"],
}

## And what the Liberal Guardian sells.
const GUARDIAN := {
	1: ["Want Organic?", "", "Visit The Vegan", "Co-Op"],
	3: ["Abortion Clinic", "", "Walk-in, No", "Questions Asked", "Open 24/7"],
	4: ["Marijuana Dispensary", "", "No ID Or Prescription Needed!",
			"Please Pay In Cash."],
	5: ["Got Slack?", "", "Visit Your Local", "SubGenius Clench",
			"For More Info"],
}

## The one the original prints when its own numbering has gone wrong. It
## cannot come up — the choice is rolled from one to six and every one of
## those is written — but it is kept because it is the joke it is.
const BUG := ["Debuggers Needed", "", "It Seems", "You've Found", "A Bug!"]


## The lines of [param advertisement], centred as the original centres them.
static func lines(advertisement: Dictionary) -> Array:
	var choice := int(advertisement["choice"])
	var guardian := bool(advertisement["guardian"])
	if choice == NewsAds.PERSONAL:
		return _personal(advertisement)
	if guardian:
		if choice == 2:
			return ["Liberal Defense Lawyer",
					"%d Years Experience" % int(advertisement["years"]), "",
					"Call Today"]
		return GUARDIAN.get(choice, BUG)
	if choice == 2:
		return ["Fine Leather Chairs", "", "Special Purchase",
				"Now $%d" % int(advertisement["price"])]
	if choice == 4:
		return ["Quality Pre-Owned", "Vehicles",
				"%d Lexus GS 300" % int(advertisement["model_year"]),
				"Sedan 4D", "Only $%d" % int(advertisement["price"])]
	return REGULAR.get(choice, BUG)


## Somebody's two lines in the lonely hearts column.
static func _personal(advertisement: Dictionary) -> Array:
	return [
		String(PERSONAL_HEADLINE.get(advertisement["headline"], "")),
		"",
		"%s %s %s" % [advertisement["description"], advertisement["who"],
				advertisement["seeking"]],
		"%s w/ %s" % [advertisement["activity"], advertisement["with"]],
	]
