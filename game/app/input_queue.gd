class_name InputQueue
extends RefCounted
## Feeds answers to a waiting [Session], one decision at a time.
##
## A live game fills this from the UI; a replay fills it from a file. Because
## every answer is data, a whole playthrough is a list — which is what lets a
## recorded run be replayed against the golden traces.

var _answers: Array = []
var _consumed := 0


## Queues answers, in the order they will be given.
func queue(answers: Array) -> void:
	_answers.append_array(answers)


## Whether there is an answer left to give.
func has_answer() -> bool:
	return _consumed < _answers.size()


## Answers whatever [param session] is waiting on. Returns false when the queue
## is empty or nothing is waiting.
func supply(session: Session) -> bool:
	if not session.is_waiting() or not has_answer():
		return false
	var answer: Variant = _answers[_consumed]
	_consumed += 1
	session.answer(answer)
	return true


## How many answers have been used, for reporting where a replay stopped.
func consumed() -> int:
	return _consumed
