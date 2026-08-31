extends TestCase
## Diffs grabbing somebody against the original.
##
## Four things to hold — nothing, a pistol, a gavel and a knife — against four
## kinds of victim, four grades of grabber and three states of injury.
##
## Compared on draw counts, whether they were taken, whether it was done bare
## handed, and what the grabber learned from it.

const PROBE := "res://tests/golden/probes/kidnap.jsonl.gz"

var _catalog: Catalog


func test_a_grab_goes_the_same_way() -> void:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()

	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return
	for sample: Dictionary in samples:
		if not _grab_matches(sample):
			return


func _grab_matches(sample: Dictionary) -> bool:
	var chase: Object = (load("res://tests/unit/test_chase.gd") as GDScript).new()
	var state := GameState.new()
	var rng: Rng = chase._rng_at(sample)
	var where := "scenario %s weapon=%s who=%s grade=%s hurt=%s" % [
			sample["scenario"], sample["weapon"], sample["who"],
			sample["grade"], sample["hurt"]]

	var grabber: Creature = chase._person(state, {}, sample["grabber"])
	var victim: Creature = chase._person(state, {}, sample["target"])

	var result := Kidnapping.grab(state, rng, grabber, victim, _catalog)

	if rng.draws != int(sample["draws"]):
		return _diverged(where, "draws", sample["draws"], rng.draws)
	if bool(result["taken"]) != (int(sample["got"]) != 0):
		return _diverged(where, "taken", sample["got"], result["taken"])
	if bool(result["amateur"]) != (int(sample["amateur"]) != 0):
		return _diverged(where, "bare handed", sample["amateur"],
				result["amateur"])

	var after: Dictionary = sample["grabber_after"]
	var skills: Array = after["skills"]
	for index in skills.size():
		if grabber.skills.values[index] != int(skills[index]):
			return _diverged(where, "skill %s" % Ids.SKILLS[index],
					skills[index], grabber.skills.values[index])
	return true


func _diverged(where: String, field: String, expected: Variant,
		actual: Variant) -> bool:
	fail("%s: %s expected %s, got %s" % [where, field, expected, actual])
	return false
