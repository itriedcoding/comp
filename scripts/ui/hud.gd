class_name Hud
extends Control
## In-game HUD: health/armor/stamina, ammo, dynamic crosshair, hitmarker,
## compass, objectives, interaction prompts, damage direction and kill feed.

const BAR_W := 240.0

var player: Player
var mode: Node

var _health_fill: ColorRect
var _health_label: Label
var _armor_fill: ColorRect
var _armor_label: Label
var _stamina_fill: ColorRect
var _ammo_label: Label
var _reserve_label: Label
var _weapon_label: Label
var _weapon_class: Label
var _fire_mode_label: Label
var _slot_label: Label
var _objective_title: Label
var _objective_label: Label
var _objective_list: VBoxContainer
var _timer_label: Label
var _score_label: Label
var _message_label: Label
var _feed: VBoxContainer
var _prompt_label: Label
var _crosshair: Crosshair
var _compass: Compass
var _damage: DamageOverlay
var _vignette: TextureRect
var _banner: Label
var _banner_sub: Label
var _hit_flash := 0.0
var _hit_headshot := false
var _message_timer := 0.0
var _damage_flash := 0.0
var _feed_entries: Array = []
var _score_text := ""
var _wave_text := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	build()


func build() -> void:
	# Low health vignette.
	_vignette = TextureRect.new()
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0.5, 0.02, 0.02, 0.0), Color(0.55, 0.02, 0.02, 0.85)])
	grad.offsets = PackedFloat32Array([0.55, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.05, 0.5)
	tex.width = 256
	tex.height = 256
	_vignette.texture = tex
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.modulate.a = 0.0
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vignette)

	_crosshair = Crosshair.new()
	_crosshair.hud = self
	_crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_crosshair)

	_damage = DamageOverlay.new()
	_damage.set_anchors_preset(Control.PRESET_FULL_RECT)
	_damage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_damage)

	# Compass at the top centre.
	_compass = Compass.new()
	_compass.hud = self
	_compass.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_compass.position = Vector2(-180, 18)
	_compass.size = Vector2(360, 44)
	_compass.custom_minimum_size = Vector2(360, 44)
	_compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_compass)

	# Objectives (top left).
	var obj_panel := UiTheme.panel(Color(0.05, 0.06, 0.062, 0.72))
	obj_panel.position = Vector2(26, 24)
	obj_panel.custom_minimum_size = Vector2(330, 0)
	obj_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(obj_panel)
	var obj_box := VBoxContainer.new()
	obj_box.add_theme_constant_override("separation", 4)
	obj_panel.add_child(obj_box)
	var obj_header := UiTheme.label("OBJECTIVES", 12, UiTheme.ACCENT)
	obj_header.add_theme_constant_override("outline_size", 3)
	obj_box.add_child(obj_header)
	_objective_title = UiTheme.label("--", 16, UiTheme.TEXT)
	obj_box.add_child(_objective_title)
	_objective_list = VBoxContainer.new()
	_objective_list.add_theme_constant_override("separation", 2)
	obj_box.add_child(_objective_list)
	_timer_label = UiTheme.label("", 14, UiTheme.MUTED)
	obj_box.add_child(_timer_label)
	_objective_label = _objective_title

	# Score (top right).
	_score_label = UiTheme.label("", 14, UiTheme.TEXT)
	_score_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_score_label.position = Vector2(-330, 30)
	_score_label.size = Vector2(300, 24)
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_score_label)

	# Vitals (bottom left).
	var vitals := Control.new()
	vitals.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	vitals.position = Vector2(28, -150)
	vitals.size = Vector2(320, 120)
	vitals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vitals)
	var hb := HBoxContainer.new()
	hb.position = Vector2(0, 4)
	hb.add_theme_constant_override("separation", 4)
	vitals.add_child(hb)
	var hl := UiTheme.label("VITALS", 12, UiTheme.MUTED)
	hl.custom_minimum_size = Vector2(300, 0)
	hb.add_child(hl)
	var health_bar := Control.new()
	health_bar.custom_minimum_size = Vector2(BAR_W, 9)
	health_bar.size = Vector2(BAR_W, 9)
	vitals.add_child(health_bar)
	var health_bg := ColorRect.new()
	health_bg.color = Color(0.12, 0.13, 0.13, 0.9)
	health_bg.size = Vector2(BAR_W, 9)
	health_bar.add_child(health_bg)
	_health_fill = ColorRect.new()
	_health_fill.color = Color(0.72, 0.24, 0.18)
	_health_fill.size = Vector2(BAR_W, 9)
	health_bar.add_child(_health_fill)
	_health_label = UiTheme.label("100", 13, UiTheme.TEXT)
	_health_label.position = Vector2(BAR_W + 10, -3)
	vitals.add_child(_health_label)
	var armor_bar := Control.new()
	armor_bar.position = Vector2(0, 26)
	armor_bar.custom_minimum_size = Vector2(BAR_W, 6)
	armor_bar.size = Vector2(BAR_W, 6)
	vitals.add_child(armor_bar)
	var armor_bg := ColorRect.new()
	armor_bg.color = Color(0.12, 0.13, 0.13, 0.9)
	armor_bg.size = Vector2(BAR_W, 6)
	armor_bar.add_child(armor_bg)
	_armor_fill = ColorRect.new()
	_armor_fill.color = Color(0.42, 0.58, 0.72)
	_armor_fill.size = Vector2(BAR_W, 6)
	armor_bar.add_child(_armor_fill)
	_armor_label = UiTheme.label("100", 12, UiTheme.MUTED)
	_armor_label.position = Vector2(BAR_W + 10, 20)
	vitals.add_child(_armor_label)
	var stamina_bar := Control.new()
	stamina_bar.position = Vector2(0, 44)
	stamina_bar.custom_minimum_size = Vector2(BAR_W, 4)
	stamina_bar.size = Vector2(BAR_W, 4)
	vitals.add_child(stamina_bar)
	var stamina_bg := ColorRect.new()
	stamina_bg.color = Color(0.12, 0.13, 0.13, 0.9)
	stamina_bg.size = Vector2(BAR_W, 4)
	stamina_bar.add_child(stamina_bg)
	_stamina_fill = ColorRect.new()
	_stamina_fill.color = Color(0.62, 0.66, 0.4)
	_stamina_fill.size = Vector2(BAR_W, 4)
	stamina_bar.add_child(_stamina_fill)

	# Weapon/ammo (bottom right).
	var ammo_box := Control.new()
	ammo_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ammo_box.position = Vector2(-330, -160)
	ammo_box.size = Vector2(300, 130)
	ammo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ammo_box)
	_weapon_label = UiTheme.label("KX-15", 20, UiTheme.TEXT)
	_weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_weapon_label.size = Vector2(300, 26)
	_weapon_label.position = Vector2(0, 0)
	ammo_box.add_child(_weapon_label)
	_weapon_class = UiTheme.label("ASSAULT RIFLE", 11, UiTheme.MUTED)
	_weapon_class.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_weapon_class.size = Vector2(300, 16)
	_weapon_class.position = Vector2(0, 26)
	ammo_box.add_child(_weapon_class)
	_ammo_label = UiTheme.label("30", 54, Color(0.92, 0.9, 0.82))
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ammo_label.size = Vector2(220, 62)
	_ammo_label.position = Vector2(0, 44)
	ammo_box.add_child(_ammo_label)
	_reserve_label = UiTheme.label("/ 210", 18, UiTheme.MUTED)
	_reserve_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_reserve_label.size = Vector2(300, 24)
	_reserve_label.position = Vector2(0, 100)
	ammo_box.add_child(_reserve_label)
	_fire_mode_label = UiTheme.label("AUTO", 12, UiTheme.ACCENT)
	_fire_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fire_mode_label.size = Vector2(300, 18)
	_fire_mode_label.position = Vector2(0, 122)
	ammo_box.add_child(_fire_mode_label)
	_slot_label = UiTheme.label("", 11, UiTheme.MUTED)
	_slot_label.position = Vector2(-330, -190)
	_slot_label.size = Vector2(300, 18)
	_slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_slot_label)

	# Centre prompt + message + banner.
	_prompt_label = UiTheme.label("", 16, UiTheme.ACCENT)
	_prompt_label.set_anchors_preset(Control.PRESET_CENTER)
	_prompt_label.position = Vector2(-250, 90)
	_prompt_label.size = Vector2(500, 26)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_prompt_label)
	_message_label = UiTheme.label("", 18, Color(0.95, 0.93, 0.85))
	_message_label.set_anchors_preset(Control.PRESET_CENTER)
	_message_label.position = Vector2(-320, -180)
	_message_label.size = Vector2(640, 30)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_message_label)
	_banner = UiTheme.heading("", 46)
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.position = Vector2(-360, -110)
	_banner.size = Vector2(720, 60)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.modulate.a = 0.0
	add_child(_banner)
	_banner_sub = UiTheme.label("", 16, UiTheme.MUTED)
	_banner_sub.set_anchors_preset(Control.PRESET_CENTER)
	_banner_sub.position = Vector2(-360, -48)
	_banner_sub.size = Vector2(720, 24)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_sub.modulate.a = 0.0
	add_child(_banner_sub)

	# Kill feed (right side above the ammo block).
	_feed = VBoxContainer.new()
	_feed.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_feed.position = Vector2(-360, -330)
	_feed.size = Vector2(330, 140)
	_feed.alignment = BoxContainer.ALIGNMENT_END
	_feed.add_theme_constant_override("separation", 3)
	add_child(_feed)


func bind(p: Player, m: Node) -> void:
	player = p
	mode = m


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	# Vitals.
	var hp := player.health / maxf(1.0, player.max_health)
	_health_fill.size = Vector2(BAR_W * clampf(hp, 0.0, 1.0), 9)
	_health_fill.color = Color(0.72, 0.24, 0.18) if hp > 0.35 else Color(0.85, 0.16, 0.12)
	_health_label.text = "%d" % int(ceil(player.health))
	_armor_fill.size = Vector2(BAR_W * clampf(player.armor / maxf(1.0, player.max_armor), 0.0, 1.0), 6)
	_armor_label.text = "%d" % int(ceil(player.armor))
	_stamina_fill.size = Vector2(BAR_W * clampf(player.stamina / maxf(1.0, player.max_stamina), 0.0, 1.0), 4)
	_vignette.modulate.a = clampf(1.0 - hp * 1.6, 0.0, 0.9)
	# Weapon.
	if player.weapon_system != null:
		var data: Dictionary = player.weapon_system.hud_data()
		_weapon_label.text = String(data.get("name", ""))
		_weapon_class.text = String(data.get("class", "")).to_upper()
		_ammo_label.text = "%d" % int(data.get("mag", 0))
		_reserve_label.text = "/ %d" % int(data.get("reserve", 0))
		var mode_text := String(data.get("fire_mode", "auto")).to_upper()
		if data.get("suppressed", false):
			mode_text += "  SUPP"
		_fire_mode_label.text = "RELOADING" if data.get("reloading", false) else mode_text
		_fire_mode_label.add_theme_color_override("font_color", UiTheme.DANGER if data.get("reloading", false) else UiTheme.ACCENT)
		_slot_label.text = "%s  |  [1] [2] [3] TO SWITCH" % String(data.get("slot", ""))
	_crosshair.queue_redraw()
	_compass.queue_redraw()
	_damage.tick(delta)
	_hit_flash = maxf(0.0, _hit_flash - delta)
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			_message_label.text = ""
	if _banner.modulate.a > 0.0:
		_banner.modulate.a = maxf(0.0, _banner.modulate.a - delta * 0.35)
		_banner_sub.modulate.a = _banner.modulate.a
	_feed_prune(delta)


func _feed_prune(delta: float) -> void:
	for entry in _feed_entries.duplicate():
		entry["time"] -= delta
		if entry["time"] <= 0.0:
			_feed_entries.erase(entry)
			if is_instance_valid(entry["label"]):
				entry["label"].queue_free()


func set_objectives(title: String, entries: Array) -> void:
	_objective_title.text = title.to_upper()
	for child in _objective_list.get_children():
		child.queue_free()
	for entry in entries:
		var text := String(entry.get("text", ""))
		var done := bool(entry.get("done", false))
		var active := bool(entry.get("active", false))
		var line := UiTheme.label(("✓  " if done else "▸  ") + text, 13, UiTheme.SUCCESS if done else (UiTheme.ACCENT if active else UiTheme.MUTED))
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size = Vector2(288, 0)
		_objective_list.add_child(line)


func set_timer(text_value: String) -> void:
	_timer_label.text = text_value


func set_score(text_value: String) -> void:
	_score_text = text_value
	_score_label.text = text_value


func set_prompt(text_value: String) -> void:
	_prompt_label.text = text_value


func show_message(text_value: String, duration: float = 2.5) -> void:
	_message_label.text = text_value
	_message_timer = duration


func show_banner(title: String, subtitle: String = "", duration: float = 2.4) -> void:
	_banner.text = title.to_upper()
	_banner_sub.text = subtitle
	_banner.modulate.a = 1.0
	_banner_sub.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(duration)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.6)


func flash_hit(headshot: bool) -> void:
	_hit_flash = 0.18
	_hit_headshot = headshot


func add_feed(text_value: String, color: Color = UiTheme.TEXT) -> void:
	var l := UiTheme.label(text_value, 13, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_feed.add_child(l)
	_feed_entries.append({"label": l, "time": 5.0})
	while _feed_entries.size() > 5:
		var old: Dictionary = _feed_entries.pop_front()
		if is_instance_valid(old["label"]):
			old["label"].queue_free()


func damage_from(direction: Vector3, amount: float) -> void:
	_damage.add(direction, amount)


func set_wave(text_value: String) -> void:
	_wave_text = text_value


# --------------------------------------------------------------- drawing ---

class Crosshair extends Control:
	var hud: Hud

	func _draw() -> void:
		if hud == null or hud.player == null:
			return
		var center := size * 0.5
		var settings := Game.settings
		var color: Color = settings["crosshair_color"]
		color.a = 0.9
		var thickness: int = int(settings["crosshair_thickness"])
		var gap: float = float(settings["crosshair_gap"])
		var style := String(settings["crosshair_style"])
		var spread := 0.0
		if hud.player.weapon_system != null:
			spread = hud.player.weapon_system.current_spread_degrees()
		var dynamic_gap := gap + spread * 3.5 * (1.0 - hud.player.ads_progress * 0.7)
		if style == "Dot":
			dynamic_gap = 0.0
		var length := 7.0
		if hud.player.ads_progress > 0.85 and hud.player.weapon_system != null:
			var optic: String = String(hud.player.weapon_system.current_slot().get("attachments", {}).get("optic", "none"))
			if optic == "red_dot" or optic == "holo" or optic == "acog" or optic == "scope_4x":
				draw_circle(center, 1.6, Color(1.0, 0.2, 0.1, 0.95))
				return
		if style != "Dot":
			draw_line(center + Vector2(-dynamic_gap - length, 0), center + Vector2(-dynamic_gap, 0), color, thickness, true)
			draw_line(center + Vector2(dynamic_gap, 0), center + Vector2(dynamic_gap + length, 0), color, thickness, true)
			draw_line(center + Vector2(0, -dynamic_gap - length), center + Vector2(0, -dynamic_gap), color, thickness, true)
			draw_line(center + Vector2(0, dynamic_gap), center + Vector2(0, dynamic_gap + length), color, thickness, true)
		if bool(settings["crosshair_dot"]) or style == "Dot":
			draw_circle(center, maxf(1.0, thickness * 0.8), color)
		if hud._hit_flash > 0.0:
			var hc := Color(1.0, 0.85, 0.3, minf(1.0, hud._hit_flash * 8.0)) if hud._hit_headshot else Color(1, 1, 1, minf(1.0, hud._hit_flash * 8.0))
			var d := 6.0
			draw_line(center + Vector2(-d, -d), center + Vector2(-d * 0.4, -d * 0.4), hc, 2.0, true)
			draw_line(center + Vector2(d, -d), center + Vector2(d * 0.4, -d * 0.4), hc, 2.0, true)
			draw_line(center + Vector2(-d, d), center + Vector2(-d * 0.4, d * 0.4), hc, 2.0, true)
			draw_line(center + Vector2(d, d), center + Vector2(d * 0.4, d * 0.4), hc, 2.0, true)


class Compass extends Control:
	var hud: Hud
	var _font: Font

	func _ready() -> void:
		_font = get_theme_default_font()

	func _draw() -> void:
		if hud == null or hud.player == null:
			return
		var yaw := -rad_to_deg(hud.player.yaw + hud.player.recoil_yaw)
		var cardinals := [["N", 0.0], ["NE", 45.0], ["E", 90.0], ["SE", 135.0], ["S", 180.0], ["SW", 225.0], ["W", 270.0], ["NW", 315.0]]
		var width := size.x
		var center_x := width * 0.5
		draw_line(Vector2(30, size.y - 6), Vector2(width - 30, size.y - 6), Color(1, 1, 1, 0.25), 1.0)
		for i in range(-4, 5):
			var x := center_x + i * 30.0
			var fade := 1.0 - absf(float(i)) / 5.0
			draw_line(Vector2(x, size.y - 12), Vector2(x, size.y - 6), Color(1, 1, 1, 0.35 * fade), 1.0)
		for c in cardinals:
			var angle: float = c[1]
			var delta := wrapf(angle - yaw, -180.0, 180.0)
			if absf(delta) > 120.0:
				continue
			var x := center_x + delta / 120.0 * (width * 0.5 - 30.0)
			var alpha := clampf(1.0 - absf(delta) / 120.0, 0.15, 1.0)
			var label_text: String = c[0]
			var col := Color(0.9, 0.88, 0.72, alpha) if label_text == "N" else Color(0.8, 0.83, 0.78, alpha)
			if _font != null:
				draw_string(_font, Vector2(x - 8, 22), label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 13, col)


class DamageOverlay extends Control:
	var entries: Array = []

	func add(direction: Vector3, amount: float) -> void:
		if direction.length_squared() < 0.01:
			return
		entries.append({"dir": direction.normalized(), "time": 1.2, "amount": amount})

	func tick(delta: float) -> void:
		for e in entries.duplicate():
			e["time"] -= delta
			if e["time"] <= 0.0:
				entries.erase(e)
		queue_redraw()

	func _draw() -> void:
		if entries.is_empty():
			return
		var center := size * 0.5
		for e in entries:
			var dir: Vector3 = e["dir"]
			var angle := atan2(dir.x, -dir.z)
			var alpha: float = clampf(float(e["time"]) / 1.2, 0.0, 1.0) * 0.85
			var radius := minf(size.x, size.y) * 0.34
			var points := PackedVector2Array()
			var base := angle - PI * 0.5
			for i in 9:
				var a := base - 0.28 + i * 0.07
				var r := radius + sin(float(i) / 8.0 * PI) * 34.0
				points.append(center + Vector2(cos(a), sin(a)) * r)
			for i in range(8, -1, -1):
				var a2 := base - 0.28 + i * 0.07
				var r2 := radius + 6.0
				points.append(center + Vector2(cos(a2), sin(a2)) * r2)
			draw_colored_polygon(points, Color(0.75, 0.12, 0.08, alpha * 0.5))
		# Centred damage flash ring.
		for e in entries:
			var alpha2: float = clampf(float(e["time"]) / 1.2, 0.0, 1.0)
			draw_arc(center, minf(size.x, size.y) * 0.42, 0, TAU, 64, Color(0.7, 0.1, 0.06, alpha2 * 0.25), 18.0, true)
