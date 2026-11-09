class_name SettingsPanel
extends ScrollContainer
## Live settings: graphics, controls, audio and gameplay. Every option writes
## to Game.settings and applies immediately.

signal closed

var _vbox: VBoxContainer


func _ready() -> void:
	theme = UiTheme.theme()
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	build()


func build() -> void:
	if _vbox != null and is_instance_valid(_vbox):
		_vbox.queue_free()
	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 6)
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_vbox)
	var s := Game.settings

	_section("DISPLAY")
	_option("Resolution", Game.RESOLUTIONS, String(s["resolution"]), func(v): _apply("resolution", v))
	_option("Window mode", Game.WINDOW_MODES, String(s["window_mode"]), func(v): _apply("window_mode", v))
	_toggle("V-Sync", bool(s["vsync"]), func(v): _apply("vsync", v))
	_option("Frame rate limit", ["Unlimited", "60", "90", "120", "144", "240"], _fps_label(int(s["fps_limit"])), func(v):
		_apply("fps_limit", 0 if v == "Unlimited" else int(v)))
	_option("Upscaler", Game.UPSCALERS, String(s["upscaler"]), func(v): _apply("upscaler", v))
	_slider("Render scale", 0.5, 1.0, 0.05, float(s["render_scale"]), func(v): _apply("render_scale", v), func(v): return "%d%%" % int(v * 100.0))
	_option("Anti-aliasing", Game.AA_OPTIONS, String(s["aa"]), func(v): _apply("aa", v))

	_section("QUALITY")
	_option("Shadow quality", Game.QUALITY_LEVELS, String(s["shadow_quality"]), func(v): _apply("shadow_quality", v))
	_option("Texture quality", Game.QUALITY_LEVELS, String(s["texture_quality"]), func(v): _apply("texture_quality", v))
	_option("Effects quality", Game.QUALITY_LEVELS, String(s["effects_quality"]), func(v): _apply("effects_quality", v))
	_slider("View distance", 0.4, 1.0, 0.05, float(s["view_distance"]), func(v): _apply("view_distance", v), func(v): return "%d%%" % int(v * 100.0))
	_toggle("Ambient occlusion (SSAO)", bool(s["ssao"]), func(v): _apply("ssao", v))
	_toggle("Screen-space reflections", bool(s["ssr"]), func(v): _apply("ssr", v))
	_toggle("Volumetric fog", bool(s["volumetric_fog"]), func(v): _apply("volumetric_fog", v))
	_slider("Brightness", 0.6, 1.6, 0.02, float(s["brightness"]), func(v): _apply("brightness", v), func(v): return "%.2f" % v)
	_note("Texture and material quality take effect on the next deployment.")

	_section("CONTROLS")
	_slider("Mouse sensitivity", 0.1, 3.0, 0.05, float(s["sensitivity"]), func(v): _apply("sensitivity", v), func(v): return "%.2f" % v)
	_slider("ADS sensitivity", 0.2, 1.2, 0.05, float(s["ads_sensitivity"]), func(v): _apply("ads_sensitivity", v), func(v): return "%.2f" % v)
	_toggle("Invert vertical look", bool(s["invert_y"]), func(v): _apply("invert_y", v))
	_slider("Field of view", 70.0, 110.0, 1.0, float(s["fov"]), func(v): _apply("fov", v), func(v): return "%d°" % int(v))
	_slider("Head bob", 0.0, 1.5, 0.05, float(s["headbob"]), func(v): _apply("headbob", v), func(v): return "%.2f" % v)
	_slider("Weapon sway", 0.0, 1.5, 0.05, float(s["weapon_sway"]), func(v): _apply("weapon_sway", v), func(v): return "%.2f" % v)

	_section("CROSSHAIR")
	_option("Style", Game.CROSSHAIR_STYLES, String(s["crosshair_style"]), func(v): _apply("crosshair_style", v))
	_option("Colour", ["White", "Green", "Amber", "Cyan", "Red"], _color_label(s["crosshair_color"]), func(v): _apply("crosshair_color", _color_value(v)))
	_slider("Gap", 0.0, 16.0, 1.0, float(s["crosshair_gap"]), func(v): _apply("crosshair_gap", int(v)), func(v): return "%d px" % int(v))
	_slider("Thickness", 1.0, 4.0, 1.0, float(s["crosshair_thickness"]), func(v): _apply("crosshair_thickness", int(v)), func(v): return "%d px" % int(v))
	_toggle("Centre dot", bool(s["crosshair_dot"]), func(v): _apply("crosshair_dot", v))

	_section("AUDIO")
	_slider("Master volume", 0.0, 1.0, 0.02, float(s["master_volume"]), func(v): _apply("master_volume", v), func(v): return "%d%%" % int(v * 100.0))
	_slider("Weapon / effects", 0.0, 1.0, 0.02, float(s["sfx_volume"]), func(v): _apply("sfx_volume", v), func(v): return "%d%%" % int(v * 100.0))
	_slider("Ambience", 0.0, 1.0, 0.02, float(s["ambience_volume"]), func(v): _apply("ambience_volume", v), func(v): return "%d%%" % int(v * 100.0))
	_slider("Interface", 0.0, 1.0, 0.02, float(s["ui_volume"]), func(v): _apply("ui_volume", v), func(v): return "%d%%" % int(v * 100.0))

	_section("GAMEPLAY")
	_option("Difficulty", Game.DIFFICULTIES, String(s["difficulty"]), func(v): _apply("difficulty", v, false))
	var diff_desc := UiTheme.label(String(GameData.DIFFICULTY[String(s["difficulty"])]["desc"]), 12, UiTheme.MUTED)
	diff_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	diff_desc.custom_minimum_size = Vector2(0, 0)
	_vbox.add_child(diff_desc)
	_toggle("Show FPS counter", bool(s["show_fps"]), func(v): _apply("show_fps", v))
	_slider("HUD scale", 0.7, 1.4, 0.05, float(s["hud_scale"]), func(v): _apply("hud_scale", v), func(v): return "%.2f" % v)
	_note("DLSS is not available on this renderer. FSR 1 and FSR 2 are supported above.")


func _apply(key: String, value, persist: bool = true) -> void:
	Game.settings[key] = value
	Game.sanitize_settings()
	Game.apply_settings()
	if persist:
		Game.save_settings()


func _fps_label(value: int) -> String:
	return "Unlimited" if value == 0 else str(value)


func _color_label(color: Color) -> String:
	var presets := {
		"White": Color(0.9, 0.92, 0.86, 1.0),
		"Green": Color(0.45, 0.95, 0.45, 1.0),
		"Amber": Color(1.0, 0.75, 0.25, 1.0),
		"Cyan": Color(0.4, 0.9, 1.0, 1.0),
		"Red": Color(1.0, 0.35, 0.3, 1.0),
	}
	for name in presets.keys():
		if presets[name].is_equal_approx(color):
			return name
	return "White"


func _color_value(label: String) -> Color:
	match label:
		"Green":
			return Color(0.45, 0.95, 0.45, 1.0)
		"Amber":
			return Color(1.0, 0.75, 0.25, 1.0)
		"Cyan":
			return Color(0.4, 0.9, 1.0, 1.0)
		"Red":
			return Color(1.0, 0.35, 0.3, 1.0)
		_:
			return Color(0.9, 0.92, 0.86, 1.0)


func _section(title: String) -> void:
	_vbox.add_child(UiTheme.spacer(8))
	var l := UiTheme.label(title, 13, UiTheme.ACCENT)
	l.add_theme_constant_override("outline_size", 2)
	_vbox.add_child(l)
	_vbox.add_child(UiTheme.hsep())


func _note(text_value: String) -> void:
	var l := UiTheme.label(text_value, 12, UiTheme.MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vbox.add_child(l)


func _row(label_text: String, control: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	var l := UiTheme.label(label_text, 14, UiTheme.TEXT)
	l.custom_minimum_size = Vector2(250, 0)
	h.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(control)
	_vbox.add_child(h)
	return h


func _option(label_text: String, options: Array, current: String, callback: Callable) -> void:
	var ob := OptionButton.new()
	for option in options:
		ob.add_item(String(option))
	var index := options.find(current)
	ob.selected = maxi(0, index)
	ob.item_selected.connect(func(i: int) -> void:
		callback.call(String(options[i]))
	)
	_row(label_text, ob)


func _slider(label_text: String, min_value: float, max_value: float, step: float, value: float, callback: Callable, formatter: Callable) -> void:
	var holder := HBoxContainer.new()
	holder.add_theme_constant_override("separation", 12)
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(180, 24)
	var readout := UiTheme.label(String(formatter.call(value)), 13, UiTheme.MUTED)
	readout.custom_minimum_size = Vector2(70, 0)
	slider.value_changed.connect(func(v: float) -> void:
		readout.text = String(formatter.call(v))
		callback.call(v)
	)
	slider.drag_ended.connect(func(_changed: bool) -> void:
		Game.save_settings()
	)
	holder.add_child(slider)
	holder.add_child(readout)
	_row(label_text, holder)


func _toggle(label_text: String, value: bool, callback: Callable) -> void:
	var check := CheckButton.new()
	check.button_pressed = value
	check.toggled.connect(func(v: bool) -> void: callback.call(v))
	_row(label_text, check)
