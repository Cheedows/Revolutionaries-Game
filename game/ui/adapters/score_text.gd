class_name ScoreText
extends RefCounted
## A score is a dated result and its statistics, not one unwrapped table row.
static func describe(kept: Dictionary) -> String:
	var lines: Array[String] = []
	var table: Array = kept.get("table", [])
	if table.is_empty(): lines.append("No valid scores, press any button to return.")
	for place in table.size():
		var entry: Dictionary = table[place]
		lines.append("%d. %s" % [place + 1, String(entry.get("slogan", "")).strip_edges()])
		lines.append(String(BaseOrders.ENDINGS.get(StringName(entry.get("ending", "dead")), BaseOrders.ENDINGS[&"dead"])))
		lines.append("%d/%d" % [int(entry.get("month", 0)), int(entry.get("year", 0))])
		lines.append(_stats(entry))
		lines.append("")
	var lifetime: Dictionary = kept.get("lifetime", {})
	if not lifetime.is_empty():
		lines.append("Universal Liberal Statistics:")
		lines.append(_stats(lifetime))
	return "\n".join(lines)

static func _stats(entry: Dictionary) -> String:
	return "Recruits: %d  Martyrs: %d  Kills: %d\nKidnappings: %d\n$ Taxed: %d  $ Spent: %d\nFlags bought: %d  Flags burned: %d" % [
		int(entry.get("recruits", 0)), int(entry.get("dead", 0)), int(entry.get("kills", 0)),
		int(entry.get("kidnappings", 0)), int(entry.get("funds", 0)), int(entry.get("spent", 0)),
		int(entry.get("buys", 0)), int(entry.get("burns", 0))]
