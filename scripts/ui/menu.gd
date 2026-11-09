class_name Menu
extends Control
## Main menu: operation select, campaign briefings, loadout and settings.
## Every entry launches a real, playable mode.

signal start_requested(mode: String, mission_id: String, options: Dictionary)

var _content: VBoxContainer
var _nav: VBoxContainer
var _nav_buttons: Dictionary = {}
var _page := "overview"
var _selected_mission := "m1"
var _difficulty := "Regular"
var _backdrop: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	Game.capture_mouse(false)
	_difficulty = String(Game.settings["difficulty"])
	_build()
	_show_page("overview")


func _build() -> void:
	_backdrop = Backdrop.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 52)
	margin.add_theme_constant_override("margin_right", 52)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)

	var header := HBoxContainer.new()
	layout.add_child(header)
	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 0)
	header.add_child(title_box)
	var title := UiTheme.heading("BLACKSITE", 52)
	title_box.add_child(title)
	var subtitle := UiTheme.label("TACTICAL OPERATIONS  //  OFFLINE SINGLE PLAYER", 12, UiTheme.ACCENT)
	title_box.add_child(subtitle)
	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)
	var meta := VBoxContainer.new()
	meta.alignment = BoxContainer.ALIGNMENT_END
	header.add_child(meta)
	var version := UiTheme.label("BUILD %s  |  WINDOWS x86_64" % Game.GAME_VERSION, 11, UiTheme.MUTED)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	meta.add_child(version)
	var player_meta := UiTheme.label("OPERATOR  //  ACTIVE", 11, UiTheme.MUTED)
	player_meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	meta.add_child(player_meta)

	layout.add_child(UiTheme.hsep())

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(body)

	_nav = VBoxContainer.new()
	_nav.custom_minimum_size = Vector2(320, 0)
	_nav.add_theme_constant_override("separation", 5)
	body.add_child(_nav)
	_nav_button("OPERATIONS", "overview")
	_nav_button("CAMPAIGN", "campaign")
	_nav_button("SHOOTING RANGE", "training")
	_nav_button("SURVIVAL", "survival")
	_nav_button("TACTICAL MISSION", "tactical")
	_nav_button("OFFLINE BOT MATCH", "botmatch")
	_nav.add_child(UiTheme.spacer(10))
	_nav_button("LOADOUT", "loadout")
	_nav_button("SETTINGS", "settings")
	_nav.add_child(UiTheme.spacer(10))
	var quit := UiTheme.button("QUIT", func() -> void: Game.quit_game())
	_nav.add_child(quit)

	var content_panel := UiTheme.panel(Color(0.035, 0.045, 0.05, 0.93))
	content_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(content_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_panel.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 10)
	scroll.add_child(_content)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 24)
	layout.add_child(footer)
	var stats := UiTheme.label(_profile_line(), 12, UiTheme.MUTED)
	footer.add_child(stats)
	var footer_spacer := Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(footer_spacer)
	var hint := UiTheme.label("WASD MOVE   SHIFT SPRINT   CTRL CROUCH   RMB AIM   R RELOAD   F INTERACT   ESC PAUSE", 11, UiTheme.MUTED)
	footer.add_child(hint)


func _nav_button(label: String, page: String) -> void:
	var b := UiTheme.button(label, func() -> void: _show_page(page), 38)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_nav.add_child(b)
	_nav_buttons[page] = b


func _profile_line() -> String:
	return "MISSIONS %d / %d     ACCURACY %.0f%%     ELIMINATIONS %d     BEST WAVE %d     BEST RANGE %d" % [
		int(Game.profile["missions_completed"].size()),
		GameData.MISSIONS.size(),
		Game.accuracy() * 100.0,
		int(Game.profile["total_kills"]),
		int(Game.profile["best_wave"]),
		int(Game.profile["best_training"]),
	]


func _clear_content() -> void:
	for child in _content.get_children():
		child.queue_free()


func _show_page(page: String) -> void:
	_page = page
	_clear_content()
	for key in _nav_buttons.keys():
		var b: Button = _nav_buttons[key]
		b.modulate = Color(1, 1, 1) if key == page else Color(0.8, 0.82, 0.78)
	match page:
		"campaign":
			_build_campaign()
		"training":
			_build_training()
		"survival":
			_build_survival()
		"tactical":
			_build_tactical()
		"botmatch":
			_build_botmatch()
		"loadout":
			_build_loadout()
		"settings":
			_build_settings()
		_:
			_build_overview()


# ------------------------------------------------------------------ pages ---

func _build_overview() -> void:
	_content.add_child(UiTheme.heading("OPERATIONS", 26))
	_content.add_child(_para("Select an operation. All modes run offline against AI operators with full combat behaviour, objectives and progression."))
	_content.add_child(UiTheme.spacer(6))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	_content.add_child(grid)
	for id in ["campaign", "training", "survival", "tactical", "botmatch"]:
		var info: Dictionary = GameData.MODES[id]
		var b := UiTheme.button("", func() -> void: _show_page(id), 96)
		b.text = "%s\n%s" % [String(info["name"]).to_upper(), String(info["tagline"])]
		b.add_theme_font_size_override("font_size", 14)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(b)
	_content.add_child(UiTheme.spacer(10))
	_content.add_child(UiTheme.hsep())
	var stat_box := VBoxContainer.new()
	stat_box.add_theme_constant_override("separation", 4)
	_content.add_child(stat_box)
	stat_box.add_child(UiTheme.label("OPERATOR RECORD", 12, UiTheme.ACCENT))
	stat_box.add_child(UiTheme.label(_profile_line(), 13, UiTheme.TEXT))
	var accuracy_note := UiTheme.label("Missions completed unlock the next operation. Mid-mission checkpoints are written every 45 seconds.", 12, UiTheme.MUTED)
	accuracy_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stat_box.add_child(accuracy_note)


func _build_campaign() -> void:
	_content.add_child(UiTheme.heading("CAMPAIGN", 26))
	_content.add_child(_para("Three linked operations. Each mission has staged objectives, a checkpoint and a debrief."))
	for mission in GameData.MISSIONS:
		var id := String(mission["id"])
		var unlocked := Game.is_mission_unlocked(id)
		var completed: bool = Game.profile["missions_completed"].has(id)
		var b := UiTheme.button("", func() -> void:
			_selected_mission = id
			_show_page("campaign")
		, 58)
		var state := "COMPLETE" if completed else ("AVAILABLE" if unlocked else "LOCKED")
		b.text = "%s   %s\n%s     //     %s" % [id.to_upper(), String(mission["name"]).to_upper(), String(mission["location"]), state]
		b.add_theme_font_size_override("font_size", 14)
		b.disabled = not unlocked
		if id == _selected_mission and unlocked:
			b.modulate = Color(1.0, 0.94, 0.78)
		_content.add_child(b)
	var mission_data: Dictionary = GameData.mission(_selected_mission)
	_content.add_child(UiTheme.spacer(8))
	var panel := UiTheme.panel(UiTheme.PANEL_SOFT)
	_content.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(UiTheme.label("BRIEFING  //  %s" % String(mission_data["name"]).to_upper(), 13, UiTheme.ACCENT))
	box.add_child(_para(String(mission_data["briefing"])))
	box.add_child(UiTheme.hsep())
	box.add_child(UiTheme.label("OBJECTIVES", 12, UiTheme.ACCENT))
	for obj in mission_data.get("objectives", []):
		box.add_child(UiTheme.label("▸  " + String(obj["label"]), 13, UiTheme.TEXT))
	box.add_child(UiTheme.label("THREAT LEVEL", 12, UiTheme.ACCENT))
	var diff_row := HBoxContainer.new()
	diff_row.add_theme_constant_override("separation", 8)
	box.add_child(diff_row)
	var diff := OptionButton.new()
	for d in Game.DIFFICULTIES:
		diff.add_item(d)
	diff.selected = maxi(0, Game.DIFFICULTIES.find(_difficulty))
	diff.item_selected.connect(func(i: int) -> void:
		_difficulty = Game.DIFFICULTIES[i]
		Game.settings["difficulty"] = _difficulty
		Game.save_settings()
	)
	diff_row.add_child(diff)
	var diff_desc := UiTheme.label(String(GameData.DIFFICULTY[_difficulty]["desc"]), 12, UiTheme.MUTED)
	diff_row.add_child(diff_desc)
	box.add_child(UiTheme.spacer(6))
	var launch := UiTheme.button("DEPLOY", func() -> void:
		_start("campaign", _selected_mission, {})
	, 44)
	box.add_child(launch)
	var checkpoint := Game.read_checkpoint()
	if checkpoint.get("mode", "") == "campaign" and checkpoint.get("mission_id", "") == _selected_mission:
		box.add_child(UiTheme.button("RESUME CHECKPOINT", func() -> void:
			_start("campaign", _selected_mission, {"resume": true})
		, 38))


func _build_training() -> void:
	_content.add_child(UiTheme.heading("SHOOTING RANGE", 26))
	_content.add_child(_para(String(GameData.MODES["training"]["desc"])))
	_content.add_child(UiTheme.spacer(6))
	_content.add_child(UiTheme.label("Best score: %d" % int(Game.profile["best_training"]), 14, UiTheme.ACCENT))
	_content.add_child(UiTheme.spacer(10))
	_content.add_child(UiTheme.button("START DRILL", func() -> void: _start("training", "", {}), 44))


func _build_survival() -> void:
	_content.add_child(UiTheme.heading("SURVIVAL", 26))
	_content.add_child(_para(String(GameData.MODES["survival"]["desc"])))
	_content.add_child(UiTheme.spacer(6))
	_content.add_child(UiTheme.label("Best wave: %d" % int(Game.profile["best_wave"]), 14, UiTheme.ACCENT))
	_content.add_child(UiTheme.spacer(10))
	_content.add_child(UiTheme.button("DEPLOY", func() -> void: _start("survival", "", {}), 44))


func _build_tactical() -> void:
	_content.add_child(UiTheme.heading("TACTICAL MISSION", 26))
	_content.add_child(_para(String(GameData.MODES["tactical"]["desc"])))
	_content.add_child(UiTheme.hsep())
	_content.add_child(UiTheme.label("DEAD DROP  //  SOKOL HEIGHTS", 13, UiTheme.ACCENT))
	_content.add_child(_para("Recover the relay intel, avoid raising the alarm and exfiltrate through the alley before the window closes. Suppressed weapons and crouched movement reduce detection."))
	_content.add_child(UiTheme.spacer(10))
	_content.add_child(UiTheme.button("DEPLOY", func() -> void: _start("tactical", "m2", {}), 44))


func _build_botmatch() -> void:
	_content.add_child(UiTheme.heading("OFFLINE BOT MATCH", 26))
	_content.add_child(_para(String(GameData.MODES["botmatch"]["desc"])))
	_content.add_child(UiTheme.spacer(6))
	_content.add_child(UiTheme.label("THREAT LEVEL", 12, UiTheme.ACCENT))
	var diff := OptionButton.new()
	for d in Game.DIFFICULTIES:
		diff.add_item(d)
	diff.selected = maxi(0, Game.DIFFICULTIES.find(_difficulty))
	diff.item_selected.connect(func(i: int) -> void:
		_difficulty = Game.DIFFICULTIES[i]
		Game.settings["difficulty"] = _difficulty
		Game.save_settings()
	)
	_content.add_child(diff)
	_content.add_child(UiTheme.spacer(10))
	_content.add_child(UiTheme.button("START MATCH", func() -> void: _start("botmatch", "", {}), 44))


func _build_loadout() -> void:
	_content.add_child(UiTheme.heading("LOADOUT", 26))
	_content.add_child(_para("Primary, secondary and sidearm are carried in mission. Attachments change the weapon model, recoil, spread, magazine size and report."))
	var panel := LoadoutPanel.new()
	panel.custom_minimum_size = Vector2(0, 520)
	_content.add_child(panel)


func _build_settings() -> void:
	_content.add_child(UiTheme.heading("SETTINGS", 26))
	var panel := SettingsPanel.new()
	panel.custom_minimum_size = Vector2(0, 560)
	_content.add_child(panel)


func _para(text_value: String) -> Label:
	var l := UiTheme.label(text_value, 14, UiTheme.MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(560, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _start(mode: String, mission: String, extra: Dictionary) -> void:
	Game.settings["difficulty"] = _difficulty
	Game.save_settings()
	Audio.play_ui("ui_click", -8.0)
	start_requested.emit(mode, mission, extra)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and _page != "overview":
		_show_page("overview")
		get_viewport().set_input_as_handled()


# --------------------------------------------------------------- backdrop ---

class Backdrop extends Control:
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.024, 0.03, 0.034))
		for i in 26:
			var f := float(i) / 26.0
			draw_rect(Rect2(0, h * f, w, h / 26.0 + 1.0), Color(0.028 + f * 0.02, 0.035 + f * 0.023, 0.04 + f * 0.022))
		for x in range(0, int(w), 96):
			draw_line(Vector2(x, 0), Vector2(x, h), Color(1, 1, 1, 0.018), 1.0)
		for y in range(0, int(h), 96):
			draw_line(Vector2(0, y), Vector2(w, y), Color(1, 1, 1, 0.018), 1.0)
		var sweep := fmod(_t * 34.0, w + 500.0) - 250.0
		draw_line(Vector2(sweep, 0), Vector2(sweep + 240.0, h), Color(0.78, 0.68, 0.4, 0.05), 3.0)
		draw_rect(Rect2(0, h - 3.0, w, 3.0), Color(0.78, 0.68, 0.4, 0.25))
