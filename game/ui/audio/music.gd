extends Node
## Presentation-only soundtrack. It never consumes simulation RNG.
var enabled := true
var _player: AudioStreamPlayer
var _track: StringName = &""

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.volume_db = -16
	_player.finished.connect(func() -> void:
		if enabled: _player.play())
	add_child(_player)
	var settings := ConfigFile.new()
	if settings.load("user://audio.cfg") == OK:
		enabled = bool(settings.get_value("music", "enabled", true))

func enable(on: bool) -> void:
	enabled = on
	var settings := ConfigFile.new()
	settings.set_value("music", "enabled", on)
	settings.save("user://audio.cfg")
	if not on: _player.stop()
	elif _player.stream != null: _player.play()

func scene(track: StringName) -> void:
	if _track == track: return
	_track = track
	_player.stop()
	var path := "res://data/music/%s.ogg" % track
	if not ResourceLoader.exists(path): return
	_player.stream = load(path) as AudioStream
	if enabled: _player.play()

func follow(session: Session, page: StringName) -> void:
	var track: StringName = &"basemode"
	if page == &"site":
		track = &"alarmed" if session.state.site.alarm else &"sitemode"
	elif page == &"combat": track = &"carchase" if session.state.mode == &"chasecar" else &"footchase"
	elif page == &"ending": track = &"conquer" if session.state.endgame_state == &"won" else &"defeat"
	elif page == &"sleepers": track = &"recruiting"
	elif page in [&"roster", &"members"]: track = &"activate"
	if session.is_waiting():
		var intent := session.pending().intent
		match intent.type:
			Intent.CONFIRM_RECRUIT: track = &"recruiting"
			Intent.CHOOSE_DATE_APPROACH: track = &"dating"
			Intent.CHOOSE_INTERROGATION_TACTIC: track = &"interrogation"
			Intent.CHOOSE_DEFENSE: track = &"defense"
		if intent.context.has("polling"): track = &"elections"
		if intent.context.has("financial_report"): track = &"finances"
	scene(track)
