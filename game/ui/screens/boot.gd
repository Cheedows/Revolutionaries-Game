extends Control
## Placeholder entry point.
##
## The UI is Phase 3 (see docs/port/GODOT-PORT-PLAN.md); until then the project
## boots to a stub so that `godot --path game` runs and the import pass is clean.
## The sim core is exercised headlessly through app/headless_main.gd and the
## tests, neither of which needs a scene.

@onready var _label: Label = $Label


func _ready() -> void:
	_label.text = "%s — sim core only.\nRun the tests: tools/run_tests.sh" % Branding.GAME_TITLE
