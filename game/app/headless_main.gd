extends SceneTree
## Runs the simulation with no window, for replays and parity work.
##
##   godot --headless --path game --script res://app/headless_main.gd -- \
##       --seed 12345 --days 30 [--trace out.jsonl]
##
## Prints one line per event, or writes the run as JSON Lines when --trace is
## given, in the same shape as the harness records from the original.

func _initialize() -> void:
	var options := _parse(OS.get_cmdline_user_args())
	var session := Session.new(int(options.get("seed", "1")))
	var days := int(options.get("days", "1"))

	var trace: FileAccess = null
	if options.has("trace"):
		trace = FileAccess.open(options["trace"], FileAccess.WRITE)
		if trace == null:
			printerr("cannot write %s" % options["trace"])
			quit(2)
			return

	for day in days:
		session.emit(DailyTurn.run(session.state, session.rng))
		if session.is_waiting():
			printerr("day %d stopped for a decision: %s"
					% [day, session.pending().intent.type])
			break
		_report(session.drain_events(), session, trace)

	if trace != null:
		trace.close()
	quit(0)


func _report(events: Array[Event], session: Session, trace: FileAccess) -> void:
	if trace == null:
		for event in events:
			print("%4d  %s  %s" % [event.sequence, event.type, event.data])
		return
	var encoded := []
	for event in events:
		encoded.append({"sequence": event.sequence, "type": String(event.type),
				"data": event.data})
	trace.store_line(JSON.stringify({
		"date": "%04d-%02d-%02d" % [session.state.calendar.year,
				session.state.calendar.month, session.state.calendar.day],
		"funds": session.state.ledger.funds,
		"events": encoded,
	}))


func _parse(arguments: PackedStringArray) -> Dictionary:
	var options := {}
	var index := 0
	while index < arguments.size():
		var argument := arguments[index]
		if argument.begins_with("--") and index + 1 < arguments.size():
			options[argument.substr(2)] = arguments[index + 1]
			index += 2
		else:
			index += 1
	return options
