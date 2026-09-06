class_name SiteTranscript
extends PanelContainer
## A readable exchange before returning to exploration, also retained in history.

signal closed
var _words: NameText
var _scroll: ScrollContainer


func show_exchange(said: String, state: GameState) -> void:
	if _words == null:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		add_theme_stylebox_override(&"panel", UiTheme.panel())
		var column := Atoms.column(Metrics.SNUG)
		add_child(column)
		column.add_child(Atoms.heading("Conversation"))
		_scroll = ScrollContainer.new()
		Metrics.page_scroller(_scroll)
		_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(_scroll)
		_words = NameText.new()
		_scroll.add_child(_words)
		var done := Atoms.primary("Continue")
		done.pressed.connect(func() -> void: closed.emit())
		column.add_child(done)
	_words.show_text(said.replace("\n", "\n\n"), state, Palette.TEXT)
	_scroll.scroll_vertical = 0
	show()
	Metrics.enlarge(self, Metrics.touch(self))
	PressFeel.teach(self)
