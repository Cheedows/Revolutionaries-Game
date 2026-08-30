class_name Difficulty
extends RefCounted
## The difficulty ladder every check is measured against.
##
## Mirrors CheckDifficulty in src/creature/creature.h. Because a roll caps at
## 18, formidable is genuinely hard and impossible very nearly is.

const AUTOMATIC := 1
const VERY_EASY := 3
const EASY := 5
const AVERAGE := 7
const CHALLENGING := 9
const HARD := 11
const FORMIDABLE := 13
const HEROIC := 15
const SUPERHEROIC := 17
const IMPOSSIBLE := 19
