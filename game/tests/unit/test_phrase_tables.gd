extends TestCase
## Where the simulation rolls an index, the interface has that many phrases.
##
## Several of the original's descriptions are chosen by a die roll, and the
## roll has to happen whether or not anybody reads the result — it moves the
## generator, and the rest of the run depends on where the generator is. So
## `core/` rolls the index and the adapters own the words.
##
## That leaves a seam nothing else watches: if the two get out of step, the
## index either lands on the wrong phrase or is clamped, and the variety the
## original had quietly disappears. There is no crash and no failing draw
## count, because the draw is still made.
##
## A roll whose result the port discards outright is not listed here. Those are
## deliberate — the incapacitation lines, for instance, are rolled for parity
## and the port says its own thing instead — and a table that does not exist
## cannot fall out of step with one that does.

func test_a_death_has_as_many_ways_as_the_original() -> void:
	equal(DeathText.HEADLESS.size(), Aftermath.HEADLESS_WAYS,
			"the ways a headless body falls")
	equal(DeathText.IN_PIECES.size(), Aftermath.IN_PIECES_WAYS,
			"the ways one cut in half does")
	equal(DeathText.QUIETLY.size(), Aftermath.QUIET_WAYS,
			"and the ways everybody else goes")
	for line: Array in DeathText.HEADLESS:
		equal(line.size(), 2,
				"each headless line reads differently in a car")


func test_a_crash_has_as_many_ways_as_the_original() -> void:
	equal(ChaseText.CRASHES.size(), Crashes.CRASH_MODES,
			"the ways a car goes off the road")
	equal(ChaseText.CRASHES.size(), Crashes.ENEMY_MODES,
			"which is the same either side")
	equal(ChaseText.DEATHS.size(), Crashes.FATALITIES,
			"and the ways somebody in it dies")


func test_the_other_rolled_phrases_line_up() -> void:
	equal(SiteReportText.FUMBLES.size(), Suspicion.FUMBLE_LINES,
			"what somebody does when their nerve goes")
	equal(DayText.IDLE_AFTERNOONS.size(), TailoringActivity.IDLE_WAYS,
			"an afternoon with nothing to mend")
