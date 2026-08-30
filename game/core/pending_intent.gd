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
var resume: Callable


func _init(asked: Intent, resume_with: Callable) -> void:
	intent = asked
	resume = resume_with
