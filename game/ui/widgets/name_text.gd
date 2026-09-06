class_name NameText
extends RichTextLabel
## Wrapped prose with literal text and coloured name spans, never injected BBCode.

var record: Dictionary = {}
var referents: Array[int] = []


func _init() -> void:
	fit_content = true
	scroll_active = false
	bbcode_enabled = false
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func show_text(said: String, state: GameState, ink: Color) -> void:
	show_record({"text": said, "colour": ink, "runs": NameColours.spans(said, state, ink, referents)})


func show_record(line: Dictionary) -> void:
	record = line.duplicate(true)
	clear()
	for run: Dictionary in line.get("runs", [{"text": line.text, "colour": line.colour}]):
		push_color(run.colour)
		add_text(run.text)
		pop()
