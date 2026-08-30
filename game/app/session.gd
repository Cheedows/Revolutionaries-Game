class_name Session
extends RefCounted
## Owns a game and pumps the simulation.
##
## The systems in core/ never wait and never draw: they take the state and the
## generator, return [Event]s, and return a [PendingIntent] when they need a
## decision. This is the loop that drives them and routes the results — the only
## place that knows both sides.

## The game being played.
var state: GameState

## The generator every system draws from. Its state is part of the save.
var rng: Rng

## Content, loaded once.
var catalog: Catalog

## Events produced since the last drain, oldest first.
var _events: Array[Event] = []

## The decision the simulation is waiting on, or null when it is free to run.
var _pending: PendingIntent = null

var _next_sequence := 0


func _init(seed_value: int = 0) -> void:
	state = GameState.new()
	rng = Rng.new(seed_value)
	catalog = Catalog.new()
	catalog.load_all()


## Whether the simulation is waiting for a decision.
func is_waiting() -> bool:
	return _pending != null


## The decision being waited on, or null.
func pending() -> PendingIntent:
	return _pending


## Answers the pending decision and lets the simulation continue.
##
## Whatever resuming produces goes back through [method submit], so a system
## that asks a second question parks again rather than losing the thread, and
## the events it produced on the way are not dropped.
func answer(choice: Variant) -> void:
	assert(_pending != null, "nothing is waiting for an answer")
	var waiting := _pending
	_pending = null
	submit(waiting.resume.call(choice))


## Takes everything that has happened since the last call.
func drain_events() -> Array[Event]:
	var drained := _events
	_events = []
	return drained


## Records events returned by a system, in order.
func emit(events: Array[Event]) -> void:
	for event in events:
		event.sequence = _next_sequence
		_next_sequence += 1
		_events.append(event)


## Takes whatever a system returned: events to record, or a question to park on.
##
## Every system returns one or the other, so this is the single place the
## difference is handled — callers do not have to test for it.
func submit(result: Variant) -> void:
	if result is PendingIntent:
		var asked: PendingIntent = result
		emit(asked.events)
		ask(asked)
		return
	if result is Array:
		emit(result)


## Parks the simulation until [method answer] is called.
func ask(intent: PendingIntent) -> void:
	assert(_pending == null, "already waiting on a decision")
	_pending = intent
