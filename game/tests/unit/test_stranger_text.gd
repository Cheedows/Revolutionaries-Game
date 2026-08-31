extends TestCase
## Guessing a stranger's age and gender, the way the original guesses.

func test_a_young_stranger_is_guessed_to_within_a_year() -> void:
	var person := Creature.new()
	person.age = 16
	person.birthday_day = 3
	equal(StrangerText.age(person), "15?", "the slop is fixed to the birthday")
	person.birthday_day = 5
	equal(StrangerText.age(person), "17?", "and the other way for another day")


func test_an_adult_is_guessed_to_a_decade() -> void:
	var person := Creature.new()
	person.age = 47
	equal(StrangerText.age(person), "40s", "just the decade")
	person.age = 91
	equal(StrangerText.age(person), "Very Old", "and past ninety, not even that")


func test_a_reading_conservative_society_disputes_is_marked() -> void:
	var person := Creature.new()
	person.gender_liberal = &"female"
	person.gender_conservative = &"female"
	equal(StrangerText.gender(person), "Female", "nobody disagrees")
	person.gender_conservative = &"male"
	equal(StrangerText.gender(person), "Female?", "now somebody does")
	person.gender_liberal = &"neutral"
	equal(StrangerText.gender(person), "Ambiguous",
			"and an ambiguous reading is never queried further")


func test_nobody_guesses_at_an_animal() -> void:
	var person := Creature.new()
	person.animal_gloss = &"tank"
	equal(StrangerText.age_and_gender(person), "(?)",
			"who knows how old the tank is")
