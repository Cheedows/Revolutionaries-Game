extends Node
## Fans simulation events out to the UI.
##
## The bus is the only thing ui/ listens to; it never touches [GameState]
## directly, and core/ has no idea it exists.

## One simulation event, in the order it happened.
signal event_occurred(event: Event)

## The simulation is waiting for a decision.
signal decision_needed(intent: Intent)

## The simulation has finished a step and produced no more events.
signal step_finished


## Publishes everything a [Session] has produced.
func publish(events: Array) -> void:
	for event: Event in events:
		event_occurred.emit(event)
	step_finished.emit()


## Publishes a question for the UI to put to the player.
func ask(intent: Intent) -> void:
	decision_needed.emit(intent)
