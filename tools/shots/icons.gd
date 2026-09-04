extends SceneTree
## Draws every icon at once, so they can be looked at rather than imagined.
##
##   xvfb-run -a godot --path game --rendering-driver opengl3 \
##       --script res://../tools/shots/icons.gd -- out.png
func _initialize() -> void:
	var page := PanelContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.add_theme_stylebox_override(&"panel", UiTheme.panel())
	root.add_child(page)
	root.size = Vector2i(560, 620)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override(&"h_separation", Metrics.WIDE)
	grid.add_theme_constant_override(&"v_separation", Metrics.SNUG)
	page.add_child(grid)
	for name: StringName in IconArt.ROWS:
		grid.add_child(Icons.on(Atoms.button(String(name), false), name))
	for _settle in 20:
		await process_frame
	root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	print("wrote it")
	quit()
