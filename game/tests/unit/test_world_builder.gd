extends TestCase
## Diffs the built world against the original.
##
## Six scenarios with different laws, half of them starting with floor plans.
## Everything is checked: which places exist, how they nest, who holds them,
## their names — several of which change as the country turns Conservative — and
## the generator stream each takes for its own floor plan, which only lines up
## if every naming roll happened in the right place.

const PROBE := "res://tests/golden/probes/world.jsonl.gz"


func test_the_city_is_built_the_same_way() -> void:
	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return

	for sample: Dictionary in samples:
		var state := GameState.new()
		var laws: Array = sample["law"]
		for index in Ids.LAWS.size():
			state.law.values[index] = int(laws[index])

		var rng := Rng.new(int(sample["seed"]))
		# The probe alternates whether the squad starts with floor plans.
		WorldBuilder.build(state, rng, int(sample["scenario"]) % 2 == 1)

		var expected: Array = sample["locations"]
		equal(state.locations.size(), expected.size(),
				"scenario %s location count" % sample["scenario"])

		for entry: Dictionary in expected:
			var location: Location = state.locations.get(int(entry["id"]))
			if location == null:
				fail("scenario %s: no location with id %s"
						% [sample["scenario"], entry["id"]])
				return
			var where := "scenario %s location %s" % [sample["scenario"], entry["id"]]

			var type_name: StringName = Ids.SITE_TYPES[int(entry["type"])]
			if location.type != type_name:
				fail("%s: type expected %s, got %s" % [where, type_name, location.type])
				return
			if location.parent != int(entry["parent"]):
				fail("%s: parent expected %s, got %d"
						% [where, entry["parent"], location.parent])
				return
			if location.area != int(entry["area"]):
				fail("%s: area expected %s, got %d" % [where, entry["area"], location.area])
				return
			if location.renting != int(entry["renting"]):
				fail("%s: holder expected %s, got %d"
						% [where, entry["renting"], location.renting])
				return
			if int(location.hidden) != int(entry["hidden"]):
				fail("%s: hidden expected %s, got %s"
						% [where, entry["hidden"], location.hidden])
				return
			if int(location.mapped) != int(entry["mapped"]):
				fail("%s: mapped expected %s, got %s"
						% [where, entry["mapped"], location.mapped])
				return
			if int(location.upgradable) != int(entry["upgradable"]):
				fail("%s: upgradable expected %s, got %s"
						% [where, entry["upgradable"], location.upgradable])
				return

			if location.name != String(entry["name"]):
				fail("%s: name expected %s, got %s"
						% [where, entry["name"], location.name])
				return
			if location.short_name != String(entry["shortname"]):
				fail("%s: short name expected %s, got %s"
						% [where, entry["shortname"], location.short_name])
				return

			var seeds: Array = entry["mapseed"]
			for word in seeds.size():
				if location.map_seed[word] != TraceFile.to_unsigned(int(seeds[word])):
					fail("%s: map seed word %d expected %d, got %d"
							% [where, word, TraceFile.to_unsigned(int(seeds[word])),
									location.map_seed[word]])
					return


func test_a_conservative_country_renames_its_institutions() -> void:
	var state := GameState.new()
	state.law.set_value(&"policebehavior", -2)
	state.law.set_value(&"deathpenalty", -2)
	state.law.set_value(&"prisons", -2)
	state.law.set_value(&"freespeech", -2)
	WorldBuilder.build(state, Rng.new(1))

	var names := {}
	for location: Location in state.locations.values():
		names[location.type] = location.name

	equal(names[&"government_policestation"], "Death Squad HQ", "the police station")
	equal(names[&"government_courthouse"], "Halls of Ultimate Judgment", "the courthouse")
	check(String(names[&"government_prison"]).ends_with("Forced Labor Camp"),
			"the prison, got %s" % names[&"government_prison"])
	equal(names[&"government_firestation"], "Fireman HQ", "the fire station")
