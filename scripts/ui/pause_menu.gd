class_name PauseMenu
extends Control
## In-game pause overlay with resume, settings, restart and quit.

signal resume_pressed
signal restart_pressed
signal quit_pressed

var _settings: SettingsPanel
var _main_box: VBoxContainer
var _settings_box: VBoxContainer
var _restart_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.theme()
	visible = false
	_build()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.025, 0.028, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_main_box = VBoxContainer.new()
	_main_box.custom_minimum_size = Vector2(420, 0)
	_main_box.add_theme_constant_override("separation", 10)
	center.add_child(_main_box)
	var title := UiTheme.heading("PAUSED", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_main_box.add_child(title)
	var sub := UiTheme.label("TACTICAL HOLD", 12, UiTheme.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_main_box.add_child(sub)
	_main_box.add_child(UiTheme.spacer(14))
	_main_box.add_child(UiTheme.button("RESUME", func() -> void: resume_pressed.emit()))
	_main_box.add_child(UiTheme.button("SETTINGS", _open_settings))
	_restart_button = UiTheme.button("RESTART MISSION", func() -> void: restart_pressed.emit())
	_main_box.add_child(_restart_button)
	_main_box.add_child(UiTheme.button("QUIT TO MAIN MENU", func() -> void: quit_pressed.emit()))
	_main_box.add_child(UiTheme.spacer(8))
	var hint := UiTheme.label("ESC  RESUME", 11, UiTheme.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_main_box.add_child(hint)

	_settings_box = VBoxContainer.new()
	_settings_box.custom_minimum_size = Vector2(640, 620)
	_settings_box.add_theme_constant_override("separation", 8)
	_settings_box.visible = false
	add_child(_settings_box)
	var settings_header := HBoxContainer.new()
	settings_header.add_theme_constant_override("separation", 12)
	var sh := UiTheme.heading("SETTINGS", 26)
	settings_header.add_child(sh)
	settings_header.add_child(UiTheme.small_button("BACK", _close_settings))
	_settings_box.add_child(settings_header)
	_settings = SettingsPanel.new()
	_settings.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_settings_box.add_child(_settings)
	_settings_box.set_anchors_preset(Control.PRESET_CENTER)
	_settings_box.position = Vector2(-320, -310)


func open(allow_restart: bool = true) -> void:
	visible = true
	_settings_box.visible = false
	_main_box.visible = true
	_restart_button.disabled = not allow_restart
	Game.capture_mouse(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	visible = false
	Game.capture_mouse(true)


func _open_settings() -> void:
	_main_box.visible = false
	_settings_box.visible = true


func _close_settings() -> void:
	_settings.visible = true
	_main_box.visible = true
	_settings_box.visible = false
