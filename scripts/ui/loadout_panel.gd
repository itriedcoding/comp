class_name LoadoutPanel
extends ScrollContainer
## Loadout configuration: primary/secondary/sidearm plus per-weapon attachments
## with live stat readouts.

signal closed

var _vbox: VBoxContainer
var _selected_primary := "kx15"


func _ready() -> void:
	theme = UiTheme.theme()
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_selected_primary = String(Game.profile["loadout"]["primary"])
	build()


func build() -> void:
	if _vbox != null and is_instance_valid(_vbox):
		_vbox.queue_free()
	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 8)
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_vbox)
	var loadout: Dictionary = Game.profile["loadout"]

	_section("SLOTS")
	_option("Primary", GameData.PRIMARY_OPTIONS, String(loadout["primary"]), func(v: String) -> void:
		Game.set_loadout("primary", v)
		_selected_primary = v
		build()
	)
	_option("Secondary", GameData.SECONDARY_OPTIONS, String(loadout["secondary"]), func(v: String) -> void:
		Game.set_loadout("secondary", v)
		build()
	)
	_option("Sidearm", GameData.SIDEARM_OPTIONS, String(loadout["sidearm"]), func(v: String) -> void:
		Game.set_loadout("sidearm", v)
		build()
	)

	var weapon_id := String(loadout["primary"])
	var def: Dictionary = GameData.weapon(weapon_id)
	_section("%s  —  %s" % [String(def["name"]).to_upper(), String(def["class"]).to_upper()])
	var att: Dictionary = Game.attachments_for(weapon_id)
	# Optic options are weapon-specific.
	var optic_ids: Array = def.get("optic_options", ["none", "red_dot"])
	var optic_names: Array = []
	for id in optic_ids:
		optic_names.append(String(GameData.ATTACHMENTS.get(id, {}).get("name", id)))
	var optic_index := optic_ids.find(String(att.get("optic", "none")))
	_option("Optic", optic_names, String(optic_names[maxi(0, optic_index)]), func(v: String) -> void:
		var idx := optic_names.find(v)
		if idx >= 0:
			Game.set_attachment(weapon_id, "optic", String(optic_ids[idx]))
			build()
	)
	_option("Muzzle", ["None", "QD Suppressor"], "QD Suppressor" if String(att.get("suppressor", "none")) != "none" else "None", func(v: String) -> void:
		Game.set_attachment(weapon_id, "suppressor", "suppressor" if v == "QD Suppressor" else "none")
		build()
	)
	_option("Magazine", ["Standard", "Extended"], "Extended" if String(att.get("magazine", "standard")) == "extended" else "Standard", func(v: String) -> void:
		Game.set_attachment(weapon_id, "magazine", "extended" if v == "Extended" else "standard")
		build()
	)
	_option("Underbarrel", ["None", "Vertical Grip", "Angled Grip"], _grip_name(String(att.get("grip", "none"))), func(v: String) -> void:
		var grip_id := "none"
		if v == "Vertical Grip":
			grip_id = "vertical"
		elif v == "Angled Grip":
			grip_id = "angled"
		Game.set_attachment(weapon_id, "grip", grip_id)
		build()
	)

	_section("EFFECTIVE STATISTICS")
	var stats: Dictionary = GameData.resolved_weapon(weapon_id, att)
	_stat("Damage", float(stats["damage"]), 70.0, "%.0f per round" % float(stats["damage"]))
	_stat("Rate of fire", float(stats["rpm"]), 900.0, "%d rpm" % int(stats["rpm"]))
	_stat("Accuracy", clampf(4.0 / maxf(0.05, float(stats["spread_ads"])), 0.5, 10.0), 10.0, "%.2f° ADS spread" % float(stats["spread_ads"]))
	_stat("Recoil", clampf(3.0 / maxf(0.1, float(stats["recoil_v"])), 0.4, 5.0), 5.0, "%.2f vertical" % float(stats["recoil_v"]))
	_stat("Magazine", float(stats["mag"]), 45.0, "%d rounds" % int(stats["mag"]))
	_stat("Effective range", float(stats["falloff_end"]), 300.0, "%d m" % int(stats["falloff_end"]))
	if bool(stats.get("suppressed", false)):
		_note("Suppressed: muzzle report reduced by 66%, slightly lower muzzle velocity.")
	_note("Attachments are applied to the weapon model, recoil, spread and audio report in-game.")


func _grip_name(id: String) -> String:
	match id:
		"vertical":
			return "Vertical Grip"
		"angled":
			return "Angled Grip"
		_:
			return "None"


func _stat(label_text: String, value: float, maximum: float, readout: String) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var l := UiTheme.label(label_text, 14, UiTheme.TEXT)
	l.custom_minimum_size = Vector2(150, 0)
	h.add_child(l)
	var bar := UiTheme.stat_bar(value, maximum, UiTheme.ACCENT, 240.0, 8.0)
	h.add_child(bar)
	var r := UiTheme.label(readout, 12, UiTheme.MUTED)
	r.custom_minimum_size = Vector2(190, 0)
	h.add_child(r)
	_vbox.add_child(h)


func _section(title: String) -> void:
	_vbox.add_child(UiTheme.spacer(6))
	_vbox.add_child(UiTheme.label(title, 13, UiTheme.ACCENT))
	_vbox.add_child(UiTheme.hsep())


func _note(text_value: String) -> void:
	var l := UiTheme.label(text_value, 12, UiTheme.MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vbox.add_child(l)


func _option(label_text: String, options: Array, current: String, callback: Callable) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	var l := UiTheme.label(label_text, 14, UiTheme.TEXT)
	l.custom_minimum_size = Vector2(250, 0)
	h.add_child(l)
	var ob := OptionButton.new()
	for option in options:
		ob.add_item(String(option))
	ob.selected = maxi(0, options.find(current))
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ob.item_selected.connect(func(i: int) -> void: callback.call(String(options[i])))
	h.add_child(ob)
	_vbox.add_child(h)
