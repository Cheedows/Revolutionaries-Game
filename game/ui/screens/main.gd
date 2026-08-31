extends Control
## The entry point, and the only thing that knows what follows what.
##
## Title, then either the new-game questions or a game read off disk, then the
## safehouse. Each screen only announces what happened; none of them knows
## about any of the others, so any of them can be opened on its own.


func _ready() -> void:
	build()


## Opens the first screen. See title_screen.gd's build() for why this is
## public.
func build() -> void:
	_title()


func _title() -> void:
	var screen: Control = _swap("res://ui/screens/title_screen.tscn")
	screen.new_game_wanted.connect(_new_game)
	screen.loaded.connect(_play)


func _new_game() -> void:
	var screen: Control = _swap("res://ui/screens/new_game_screen.tscn")
	screen.started.connect(_play)


func _play(session: Session) -> void:
	var screen: Control = _swap("res://ui/screens/base_screen.tscn")
	screen.setup(session)
	screen.finished.connect(_title)


func _swap(scene_path: String) -> Control:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var screen: Control = (load(scene_path) as PackedScene).instantiate()
	add_child(screen)
	return screen
