extends Node
## Global state: graphics/audio/control settings, persistent profile, progression,
## mid-mission checkpoint save/load and routing between menu and gameplay.

signal settings_changed
signal profile_changed
signal request_run(mode: String, mission_id: String, options: Dictionary)
signal request_menu

const SETTINGS_PATH := "user://settings.cfg"
const PROFILE_PATH := "user://profile.cfg"
const CHECKPOINT_PATH := "user://checkpoint.json"
const GAME_VERSION := "1.0.0"

const RESOLUTIONS := ["1280x720", "1600x900", "1920x1080", "2560x1440", "3440x1440", "3840x2160"]
const WINDOW_MODES := ["Fullscreen", "Borderless", "Windowed"]
const AA_OPTIONS := ["Off", "FXAA", "TAA", "MSAA 2x", "MSAA 4x", "TAA + MSAA 4x"]
const QUALITY_LEVELS := ["Low", "Medium", "High", "Ultra"]
const UPSCALERS := ["Off", "FSR 1", "FSR 2"]
const DIFFICULTIES := ["Recruit", "Regular", "Veteran", "Elite"]
const CROSSHAIR_STYLES := ["Dynamic", "Static", "Dot"]

var settings: Dictionary = {
	"resolution": "1920x1080",
	"window_mode": "Fullscreen",
	"vsync": true,
	"fps_limit": 0,
	"render_scale": 1.0,
	"upscaler": "Off",
	"aa": "TAA",
	"shadow_quality": "High",
	"texture_quality": "High",
	"effects_quality": "High",
	"view_distance": 1.0,
	"ssao": true,
	"ssr": true,
	"volumetric_fog": true,
	"brightness": 1.0,
	"fov": 90.0,
	"sensitivity": 1.0,
	"ads_sensitivity": 0.65,
	"invert_y": false,
	"headbob": 0.6,
	"weapon_sway": 0.6,
	"crosshair_style": "Dynamic",
	"crosshair_color": Color(0.9, 0.92, 0.86, 1.0),
	"crosshair_gap": 5,
	"crosshair_thickness": 2,
	"crosshair_dot": true,
	"master_volume": 0.85,
	"sfx_volume": 1.0,
	"ambience_volume": 0.75,
	"ui_volume": 0.9,
	"difficulty": "Regular",
	"subtitles": true,
	"show_fps": false,
	"hud_scale": 1.0,
}

var profile: Dictionary = {
	"missions_completed": [],
	"mission_best_time": {},
	"best_training": 0,
	"best_wave": 0,
	"survival_points": 0,
	"total_kills": 0,
	"total_headshots": 0,
	"shots_fired": 0,
	"shots_hit": 0,
	"missions_played": 0,
	"loadout": {
		"primary": "kx15",
		"secondary": "mp5",
		"sidearm": "p226",
		"attachments": {
			"kx15": {"optic": "red_dot", "suppressor": "none", "magazine": "standard", "grip": "vertical"},
			"m14": {"optic": "scope_4x", "suppressor": "none", "magazine": "standard", "grip": "none"},
			"m590": {"optic": "none", "suppressor": "none", "magazine": "standard", "grip": "none"},
			"mp5": {"optic": "red_dot", "suppressor": "none", "magazine": "standard", "grip": "vertical"},
			"p226": {"optic": "none", "suppressor": "none", "magazine": "standard", "grip": "none"},
		},
	},
}

## Set by the bootstrap before starting a mode.
var current_run: Dictionary = {}
var checkpoint_data: Dictionary = {}
var last_result: Dictionary = {}

var _fps_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	load_profile()
	# Deferred so the window and root viewport exist before we touch them.
	apply_settings.call_deferred()


func _process(_delta: float) -> void:
	if _fps_label != null and is_instance_valid(_fps_label):
		_fps_label.text = "%d FPS  |  %.1f ms" % [Engine.get_frames_per_second(), 1000.0 / maxf(1.0, Engine.get_frames_per_second())]


# ---------------------------------------------------------------- settings ---

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		save_settings()
		return
	for key in settings.keys():
		var value = cfg.get_value("settings", key, settings[key])
		if typeof(value) == typeof(settings[key]) or (settings[key] is float and value is int):
			settings[key] = value
	sanitize_settings()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in settings.keys():
		cfg.set_value("settings", key, settings[key])
	cfg.save(SETTINGS_PATH)


func set_setting(key: String, value) -> void:
	if not settings.has(key):
		push_warning("Unknown setting: %s" % key)
		return
	settings[key] = value
	sanitize_settings()
	save_settings()
	apply_settings()


func sanitize_settings() -> void:
	settings["fps_limit"] = int(settings["fps_limit"])
	settings["render_scale"] = clampf(float(settings["render_scale"]), 0.5, 1.0)
	settings["sensitivity"] = clampf(float(settings["sensitivity"]), 0.1, 4.0)
	settings["ads_sensitivity"] = clampf(float(settings["ads_sensitivity"]), 0.1, 1.5)
	settings["fov"] = clampf(float(settings["fov"]), 65.0, 110.0)
	settings["headbob"] = clampf(float(settings["headbob"]), 0.0, 2.0)
	settings["weapon_sway"] = clampf(float(settings["weapon_sway"]), 0.0, 2.0)
	settings["brightness"] = clampf(float(settings["brightness"]), 0.6, 1.6)
	settings["view_distance"] = clampf(float(settings["view_distance"]), 0.4, 1.0)
	settings["hud_scale"] = clampf(float(settings["hud_scale"]), 0.7, 1.4)
	settings["crosshair_gap"] = clampi(int(settings["crosshair_gap"]), 0, 20)
	settings["crosshair_thickness"] = clampi(int(settings["crosshair_thickness"]), 1, 5)
	for key in ["master_volume", "sfx_volume", "ambience_volume", "ui_volume"]:
		settings[key] = clampf(float(settings[key]), 0.0, 1.0)
	if not RESOLUTIONS.has(settings["resolution"]):
		settings["resolution"] = "1920x1080"
	if not WINDOW_MODES.has(settings["window_mode"]):
		settings["window_mode"] = "Fullscreen"
	if not AA_OPTIONS.has(settings["aa"]):
		settings["aa"] = "TAA"
	if not QUALITY_LEVELS.has(settings["shadow_quality"]):
		settings["shadow_quality"] = "High"
	if not QUALITY_LEVELS.has(settings["texture_quality"]):
		settings["texture_quality"] = "High"
	if not QUALITY_LEVELS.has(settings["effects_quality"]):
		settings["effects_quality"] = "High"
	if not UPSCALERS.has(settings["upscaler"]):
		settings["upscaler"] = "Off"
	if not DIFFICULTIES.has(settings["difficulty"]):
		settings["difficulty"] = "Regular"
	if not CROSSHAIR_STYLES.has(settings["crosshair_style"]):
		settings["crosshair_style"] = "Dynamic"


func apply_settings() -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	var root := tree.root
	# --- display ---
	_apply_window_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if settings["vsync"] else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(settings["fps_limit"])
	# --- anti-aliasing / upscaling ---
	match String(settings["aa"]):
		"Off":
			root.msaa_3d = Viewport.MSAA_DISABLED
			root.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			root.use_taa = false
		"FXAA":
			root.msaa_3d = Viewport.MSAA_DISABLED
			root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			root.use_taa = false
		"TAA":
			root.msaa_3d = Viewport.MSAA_DISABLED
			root.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			root.use_taa = true
		"MSAA 2x":
			root.msaa_3d = Viewport.MSAA_2X
			root.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			root.use_taa = false
		"MSAA 4x":
			root.msaa_3d = Viewport.MSAA_4X
			root.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			root.use_taa = false
		"TAA + MSAA 4x":
			root.msaa_3d = Viewport.MSAA_4X
			root.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			root.use_taa = true
	match String(settings["upscaler"]):
		"FSR 1":
			root.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
		"FSR 2":
			root.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
		_:
			root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	root.scaling_3d_scale = clampf(float(settings["render_scale"]), 0.5, 1.0)
	# --- shadows ---
	match String(settings["shadow_quality"]):
		"Low":
			root.positional_shadow_atlas_size = 1024
		"Medium":
			root.positional_shadow_atlas_size = 2048
		"High":
			root.positional_shadow_atlas_size = 4096
		"Ultra":
			root.positional_shadow_atlas_size = 8192
	# --- view distance / geometry detail ---
	root.mesh_lod_threshold = lerpf(3.0, 0.4, clampf(float(settings["view_distance"]), 0.0, 1.0))
	if Audio != null:
		Audio.apply_volumes()
	_update_fps_overlay()
	settings_changed.emit()


func _apply_window_mode() -> void:
	var mode := String(settings["window_mode"])
	var size := resolution_size()
	if mode == "Fullscreen":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif mode == "Borderless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		var screen := DisplayServer.screen_get_size()
		DisplayServer.window_set_position(Vector2i.ZERO)
		DisplayServer.window_set_size(screen)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		DisplayServer.window_set_size(size)
		var screen := DisplayServer.screen_get_size()
		DisplayServer.window_set_position((screen - size) / 2)


func resolution_size() -> Vector2i:
	var parts := String(settings["resolution"]).split("x")
	if parts.size() != 2:
		return Vector2i(1920, 1080)
	return Vector2i(int(parts[0]), int(parts[1]))


func _update_fps_overlay() -> void:
	if not is_inside_tree():
		return
	if bool(settings["show_fps"]):
		if _fps_label == null or not is_instance_valid(_fps_label):
			var layer := CanvasLayer.new()
			layer.layer = 100
			layer.name = "FPSOverlay"
			add_child(layer)
			_fps_label = Label.new()
			_fps_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7))
			_fps_label.add_theme_font_size_override("font_size", 14)
			_fps_label.position = Vector2(16, 10)
			layer.add_child(_fps_label)
	elif _fps_label != null and is_instance_valid(_fps_label):
		_fps_label.get_parent().queue_free()
		_fps_label = null


# ----------------------------------------------------------------- profile ---

func load_profile() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PROFILE_PATH) != OK:
		save_profile()
		return
	for key in profile.keys():
		var value = cfg.get_value("profile", key, profile[key])
		if value != null and typeof(value) == typeof(profile[key]):
			profile[key] = value
	# Nested loadout needs explicit merging so new keys get defaults.
	var saved_loadout = cfg.get_value("profile", "loadout", null)
	if saved_loadout is Dictionary:
		for key in saved_loadout.keys():
			if profile["loadout"].has(key):
				if profile["loadout"][key] is Dictionary and saved_loadout[key] is Dictionary:
					for sub in saved_loadout[key].keys():
						profile["loadout"][key][sub] = saved_loadout[key][sub]
				else:
					profile["loadout"][key] = saved_loadout[key]
	profile_changed.emit()


func save_profile() -> void:
	var cfg := ConfigFile.new()
	for key in profile.keys():
		cfg.set_value("profile", key, profile[key])
	cfg.save(PROFILE_PATH)


func is_mission_unlocked(mission_id: String) -> bool:
	var index := GameData.mission_index(mission_id)
	if index <= 0:
		return true
	var previous: String = GameData.MISSIONS[index - 1]["id"]
	return profile["missions_completed"].has(previous)


func complete_mission(mission_id: String, stats: Dictionary) -> void:
	if not profile["missions_completed"].has(mission_id):
		profile["missions_completed"].append(mission_id)
	var t := float(stats.get("time", 0.0))
	var best = profile["mission_best_time"].get(mission_id, 0.0)
	if best == null or best <= 0.0 or (t > 0.0 and t < float(best)):
		profile["mission_best_time"][mission_id] = t
	profile["missions_played"] = int(profile["missions_played"]) + 1
	save_profile()
	profile_changed.emit()


func record_training(score: int) -> void:
	profile["best_training"] = maxi(int(profile["best_training"]), score)
	save_profile()
	profile_changed.emit()


func record_survival(wave: int, points: int) -> void:
	profile["best_wave"] = maxi(int(profile["best_wave"]), wave)
	profile["survival_points"] = points
	save_profile()
	profile_changed.emit()


func record_match(kills: int, headshots: int) -> void:
	profile["total_kills"] = int(profile["total_kills"]) + kills
	profile["total_headshots"] = int(profile["total_headshots"]) + headshots
	save_profile()
	profile_changed.emit()


func record_shot(hit: bool) -> void:
	profile["shots_fired"] = int(profile["shots_fired"]) + 1
	if hit:
		profile["shots_hit"] = int(profile["shots_hit"]) + 1


func accuracy() -> float:
	var fired := int(profile["shots_fired"])
	if fired <= 0:
		return 0.0
	return float(profile["shots_hit"]) / float(fired)


func set_loadout(key: String, value: String) -> void:
	profile["loadout"][key] = value
	save_profile()
	profile_changed.emit()


func set_attachment(weapon_id: String, slot: String, value: String) -> void:
	var att: Dictionary = profile["loadout"]["attachments"]
	if not att.has(weapon_id):
		att[weapon_id] = {"optic": "none", "suppressor": "none", "magazine": "standard", "grip": "none"}
	att[weapon_id][slot] = value
	save_profile()
	profile_changed.emit()


func attachments_for(weapon_id: String) -> Dictionary:
	var att: Dictionary = profile["loadout"]["attachments"]
	return att.get(weapon_id, {"optic": "none", "suppressor": "none", "magazine": "standard", "grip": "none"})


# -------------------------------------------------------------- checkpoint ---

func has_checkpoint() -> bool:
	return FileAccess.file_exists(CHECKPOINT_PATH)


func write_checkpoint(data: Dictionary) -> void:
	checkpoint_data = data.duplicate(true)
	var file := FileAccess.open(CHECKPOINT_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write checkpoint")
		return
	file.store_string(JSON.stringify(checkpoint_data, "\t"))
	file.close()


func read_checkpoint() -> Dictionary:
	if checkpoint_data.size() > 0:
		return checkpoint_data.duplicate(true)
	if not FileAccess.file_exists(CHECKPOINT_PATH):
		return {}
	var file := FileAccess.open(CHECKPOINT_PATH, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		checkpoint_data = parsed
		return checkpoint_data.duplicate(true)
	return {}


func clear_checkpoint() -> void:
	checkpoint_data = {}
	if FileAccess.file_exists(CHECKPOINT_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CHECKPOINT_PATH))


func has_mid_mission_save() -> bool:
	var data := read_checkpoint()
	return data.has("mode") and data.has("map_id")


# ----------------------------------------------------------------- routing ---

func start_run(mode: String, mission_id: String, options: Dictionary = {}) -> void:
	current_run = {"mode": mode, "mission_id": mission_id}
	current_run.merge(options, true)
	capture_mouse(true)
	request_run.emit(mode, mission_id, current_run)


func return_to_menu() -> void:
	capture_mouse(false)
	if get_tree() != null:
		get_tree().paused = false
	request_menu.emit()


func capture_mouse(captured: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE


func difficulty_modifiers() -> Dictionary:
	return GameData.DIFFICULTY.get(String(settings["difficulty"]), GameData.DIFFICULTY["Regular"])


func format_time(seconds: float) -> String:
	var total := int(maxf(0.0, seconds))
	return "%02d:%02d" % [total / 60, total % 60]


func quit_game() -> void:
	save_settings()
	save_profile()
	get_tree().quit()
