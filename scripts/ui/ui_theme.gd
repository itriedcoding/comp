class_name UiTheme
extends RefCounted
## Shared military-inspired interface styling.

const BG := Color(0.035, 0.045, 0.05)
const PANEL := Color(0.07, 0.083, 0.09, 0.94)
const PANEL_SOFT := Color(0.1, 0.115, 0.12, 0.9)
const ACCENT := Color(0.78, 0.68, 0.4)
const ACCENT_DIM := Color(0.5, 0.45, 0.28)
const TEXT := Color(0.83, 0.85, 0.81)
const MUTED := Color(0.48, 0.53, 0.5)
const DANGER := Color(0.76, 0.28, 0.2)
const SUCCESS := Color(0.48, 0.72, 0.47)

static var _theme: Theme


static func box(bg: Color, border: Color, border_width: int = 1, radius: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = 15
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("normal", "Button", box(Color(0.1, 0.115, 0.115, 0.95), Color(1, 1, 1, 0.06), 1, 2))
	t.set_stylebox("hover", "Button", box(Color(0.16, 0.17, 0.155, 1.0), ACCENT_DIM, 1, 2))
	t.set_stylebox("pressed", "Button", box(Color(0.22, 0.2, 0.13, 1.0), ACCENT, 1, 2))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), ACCENT, 1, 2))
	t.set_stylebox("disabled", "Button", box(Color(0.07, 0.075, 0.075, 0.8), Color(1, 1, 1, 0.04), 1, 2))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color(0.95, 0.9, 0.75))
	t.set_color("font_pressed_color", "Button", Color(1, 0.95, 0.8))
	t.set_color("font_disabled_color", "Button", Color(0.35, 0.37, 0.35))
	t.set_font_size("font_size", "Button", 15)
	t.set_stylebox("panel", "PanelContainer", box(PANEL, Color(1, 1, 1, 0.06), 1, 2))
	t.set_stylebox("panel", "Panel", box(PANEL, Color(1, 1, 1, 0.06), 1, 2))
	t.set_stylebox("normal", "OptionButton", box(Color(0.1, 0.115, 0.115, 0.95), Color(1, 1, 1, 0.08), 1, 2))
	t.set_stylebox("hover", "OptionButton", box(Color(0.16, 0.17, 0.155, 1.0), ACCENT_DIM, 1, 2))
	t.set_stylebox("pressed", "OptionButton", box(Color(0.16, 0.17, 0.155, 1.0), ACCENT, 1, 2))
	t.set_color("font_color", "OptionButton", TEXT)
	t.set_stylebox("slider", "HSlider", box(Color(0.16, 0.17, 0.17, 1.0), Color(1, 1, 1, 0.05), 1, 1))
	t.set_stylebox("grabber_area", "HSlider", box(ACCENT_DIM, ACCENT_DIM, 0, 0))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(ACCENT, ACCENT, 0, 0))
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_color("font_pressed_color", "CheckButton", ACCENT)
	t.set_stylebox("focus", "CheckButton", box(Color(0, 0, 0, 0), ACCENT_DIM, 1, 2))
	t.set_stylebox("scroll", "VScrollBar", box(Color(0.06, 0.07, 0.07, 0.8), Color(0, 0, 0, 0), 0, 0))
	t.set_stylebox("grabber", "VScrollBar", box(Color(0.3, 0.31, 0.28, 0.9), Color(0, 0, 0, 0), 0, 2))
	_theme = t
	return t


static func label(text_value: String, size: int = 15, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text_value
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func heading(text_value: String, size: int = 30) -> Label:
	var l := label(text_value.to_upper(), size, Color(0.93, 0.9, 0.78))
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	return l


static func button(text_value: String, callback: Callable = Callable(), min_height: int = 40) -> Button:
	var b := Button.new()
	b.text = text_value
	b.custom_minimum_size = Vector2(0, min_height)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 15)
	if callback.is_valid():
		b.pressed.connect(callback)
	b.mouse_entered.connect(func(): Audio.play_ui("ui_hover", -18.0))
	b.pressed.connect(func(): Audio.play_ui("ui_click", -10.0))
	return b


static func small_button(text_value: String, callback: Callable = Callable()) -> Button:
	var b := button(text_value, callback, 30)
	b.add_theme_font_size_override("font_size", 13)
	return b


static func spacer(height: int = 10) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c


static func hsep(height: int = 1, color: Color = Color(1, 1, 1, 0.08)) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(0, height)
	return r


static func panel(bg: Color = PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, Color(1, 1, 1, 0.07), 1, 2))
	return p


static func stat_bar(value: float, maximum: float, color: Color, width: float = 220.0, height: float = 7.0) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(width, height)
	var bg := ColorRect.new()
	bg.color = Color(0.15, 0.16, 0.16, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(bg)
	var fill := ColorRect.new()
	fill.color = color
	fill.position = Vector2.ZERO
	fill.size = Vector2(width * clampf(value / maxf(1.0, maximum), 0.0, 1.0), height)
	holder.add_child(fill)
	return holder


static func format_time(seconds: float) -> String:
	var total := int(maxf(0.0, seconds))
	return "%02d:%02d" % [total / 60, total % 60]
