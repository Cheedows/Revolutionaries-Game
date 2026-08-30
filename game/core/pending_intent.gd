class_name PendingIntent
extends RefCounted
## A decision a system needs before it can carry on.
##
## Returning one of these is how a system stops without blocking: it hands back
## the question and a callable to resume with once an answer arrives. That is
## what replaces the original's 736 in-line getkey() calls, and what makes a
## playthrough a list of answers that can be replayed.

## What is being asked.
var intent: Intent

## Called with the player's choice to continue where the system left off.
##
## It returns what any system returns: an [Array] of [Event]s, or another
## [PendingIntent] when one answer leads to the next question.
var resume: Callable

## What happened before the question came up.
##
## A system that gets halfway through a job and then has to ask something still
## has news to report, and it would be lost otherwise.
var events: Array[Event] = []


func _init(asked: Intent, resume_with: Callable,
		so_far: Array[Event] = []) -> void:
	intent = asked
	resume = resume_with
	events = so_far
