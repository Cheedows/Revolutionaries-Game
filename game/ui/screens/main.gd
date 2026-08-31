extends Control
## The entry point: start a game, then play it.
##
## The two screens do not know about each other — this swaps one for the other
## when the new-game questions are answered, so either can be opened on its own
## in the editor or a test.


func _ready() -> void:
	var opening: Control = preload("res://ui/screens/new_game_screen.tscn").instantiate()
	opening.started.connect(_play)
	add_child(opening)


func _play(session: Session) -> void:
	for child in get_children():
		child.queue_free()
		remove_child(child)
	var screen: Control = preload("res://ui/screens/base_screen.tscn").instantiate()
	add_child(screen)
	screen.setup(session)
