class_name ResultsScreen
extends Control
## Mission debrief with outcomes, statistics and follow-up actions.

signal action_selected(action: String)

var _title: Label
var _subtitle: Label
var _stats: VBoxContainer
var _continue_button: Button
var _retry_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.theme()
	visible = false
	_build()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.015, 0.02, 0.022, 0.92)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := UiTheme.panel(Color(0.055, 0.065, 0.07, 0.98))
	panel.custom_minimum_size = Vector2(620, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	_title = UiTheme.heading("MISSION COMPLETE", 32)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_subtitle = UiTheme.label("", 14, UiTheme.MUTED)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_subtitle)
	box.add_child(UiTheme.hsep())
	_stats = VBoxContainer.new()
	_stats.add_theme_constant_override("separation", 6)
	box.add_child(_stats)
	box.add_child(UiTheme.spacer(10))
	_continue_button = UiTheme.button("CONTINUE", func() -> void: action_selected.emit("continue"))
	box.add_child(_continue_button)
	_retry_button = UiTheme.button("RETRY MISSION", func() -> void: action_selected.emit("retry"))
	box.add_child(_retry_button)
	box.add_child(UiTheme.button("MAIN MENU", func() -> void: action_selected.emit("menu")))


func show_result(victory: bool, title: String, subtitle: String, stats: Array, can_retry: bool = true, continue_label: String = "CONTINUE") -> void:
	visible = true
	_title.text = title.to_upper()
	_title.add_theme_color_override("font_color", UiTheme.SUCCESS if victory else UiTheme.DANGER)
	_subtitle.text = subtitle
	for child in _stats.get_children():
		child.queue_free()
	for entry in stats:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		var l := UiTheme.label(String(entry.get("label", "")), 14, UiTheme.MUTED)
		l.custom_minimum_size = Vector2(300, 0)
		h.add_child(l)
		var v := UiTheme.label(String(entry.get("value", "")), 15, UiTheme.TEXT)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		_stats.add_child(h)
	_continue_button.text = continue_label.to_upper()
	_retry_button.visible = can_retry
	Game.capture_mouse(false)
