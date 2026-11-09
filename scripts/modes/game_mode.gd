class_name GameMode
extends Node3D
## Base mission loop: builds the map, player, enemies, HUD and pause/results UI;
## runs objectives, checkpoints and win/loss handling. Subclasses define the
## actual mode rules by overriding the virtual hooks.

var mode_id := "campaign"
var mission_id := ""
var options: Dictionary = {}
var map_id := "industrial"
var map_data: Dictionary = {}
var builder: WorldBuilder
var player: Player
var director: SquadDirector
var fx: Fx
var hud: Hud
var hud_layer: CanvasLayer
var pause_menu: PauseMenu
var results: ResultsScreen
var ui_layer: CanvasLayer
var loading_layer: CanvasLayer

var mission: Dictionary = {}
var objectives: Array = []
var objective_index := 0
var objective_kills := 0
var markers: Dictionary = {}

var enemies: Array = []
var elapsed := 0.0
var finished := false
var last_victory := false
var paused := false
var kills := 0
var headshots := 0
var deaths := 0
var score := 0
var alarm := false
var mode_title := "OPERATION"
var mode_subtitle := ""

var interact_timer := 0.0
var interact_active := false
var _checkpoint_timer := 0.0
var _shots_start := 0
var _hits_start := 0
var _resume_data: Dictionary = {}


func start_run(run: Dictionary) -> void:
	options = run
	mode_id = String(run.get("mode", "campaign"))
	mission_id = String(run.get("mission_id", ""))
	_resume_data = Game.read_checkpoint() if bool(run.get("resume", false)) else {}
	_prepare()
	_build_world()
	_spawn_player()
	_setup_ui()
	_spawn_enemies()
	_restore_from_checkpoint()
	_setup_objectives()
	_post_setup()
	_shots_start = int(Game.profile["shots_fired"])
	_hits_start = int(Game.profile["shots_hit"])
	Game.capture_mouse(true)
	_show_intro()


# ------------------------------------------------------------ virtual hooks ---

func _prepare() -> void:
	mission = GameData.mission(mission_id if mission_id != "" else "m1")
	map_id = String(mission.get("map", "industrial"))
	mode_title = String(mission.get("name", "OPERATION"))


func _spawn_enemies() -> void:
	var spawn_list: Array = map_data.get("enemy_spawns", [])
	var limit := spawn_list.size()
	if mission.has("enemies"):
		limit = mini(limit, int(mission["enemies"]))
	var difficulty: Dictionary = Game.difficulty_modifiers()
	limit = int(round(float(limit) * float(difficulty.get("count", 1.0))))
	limit = clampi(limit, 3, spawn_list.size())
	for i in limit:
		var spawn: Dictionary = spawn_list[i]
		spawn_enemy(spawn.get("position", Vector3.ZERO), spawn.get("patrol", []), "flanker" if i % 3 == 2 else "assault")


func _setup_objectives() -> void:
	objectives = []
	for obj in mission.get("objectives", []):
		var entry: Dictionary = obj.duplicate(true)
		entry["done"] = false
		objectives.append(entry)
	objective_index = 0
	objective_kills = 0


func _post_setup() -> void:
	pass


func _process_mode(_delta: float) -> void:
	pass


func _on_player_died() -> void:
	finish_mission(false, "OPERATOR KILLED IN ACTION")


func _on_enemy_died(enemy: Enemy) -> void:
	kills += 1
	var obj := current_objective()
	if not obj.is_empty() and String(obj.get("type", "")) == "eliminate":
		objective_kills += 1
	if hud != null:
		var callsign := String(GameData.BOT_NAMES[kills % GameData.BOT_NAMES.size()])
		hud.add_feed("HOSTILE DOWN  —  %s" % callsign, UiTheme.MUTED)
	if enemy != null and enemy.global_position.y < -20.0:
		enemy.queue_free()


func _record_outcome(victory: bool) -> void:
	if mode_id == "campaign" and victory:
		Game.complete_mission(mission_id, {"time": elapsed})


func _continue_after_results() -> void:
	Game.return_to_menu()


func _hud_score_text() -> String:
	return "KILLS %d   HEADSHOTS %d" % [kills, headshots]


func _hud_timer_text() -> String:
	return UiTheme.format_time(elapsed)


func _can_retry() -> bool:
	return true


func _finish_title(victory: bool) -> String:
	return "MISSION COMPLETE" if victory else "MISSION FAILED"


# ------------------------------------------------------------------- build ---

func _build_world() -> void:
	var result: Dictionary = Maps.build(map_id)
	builder = result["builder"]
	map_data = result["data"]
	markers = map_data.get("markers", {})
	add_child(builder)
	builder.merge_static_geometry()
	var environment := Maps.make_environment(map_data)
	add_child(environment)
	Maps.add_sun(self, map_data)
	Maps.add_weather(self, map_data)
	fx = Fx.new()
	fx.name = "Fx"
	add_child(fx)
	director = SquadDirector.new()
	director.name = "SquadDirector"
	add_child(director)
	Audio.set_ambience(String(map_data.get("ambience", "urban")), bool(map_data.get("rain", false)), map_id == "industrial")


func _spawn_player() -> void:
	player = Player.new()
	player.name = "Player"
	add_child(player)
	var spawn: Transform3D = map_data.get("player_spawn", Transform3D(Basis(), Vector3(0, 1, 0)))
	var loadout: Dictionary = Game.profile["loadout"]
	player.setup(spawn, loadout)
	player.died.connect(_on_player_died)
	player.damaged.connect(_on_player_damaged)
	director.setup(builder, player)
	player.weapon_system.shot_hit.connect(_on_shot_hit)
	player.weapon_system.weapon_changed.connect(_on_weapon_changed)


func _setup_ui() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 5
	add_child(hud_layer)
	hud = Hud.new()
	hud.bind(player, self)
	hud_layer.add_child(hud)
	_apply_hud_scale()
	Game.settings_changed.connect(_apply_hud_scale)

	ui_layer = CanvasLayer.new()
	ui_layer.layer = 20
	add_child(ui_layer)
	pause_menu = PauseMenu.new()
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	ui_layer.add_child(pause_menu)
	pause_menu.resume_pressed.connect(func() -> void: toggle_pause())
	pause_menu.restart_pressed.connect(_restart)
	pause_menu.quit_pressed.connect(func() -> void: Game.return_to_menu())
	results = ResultsScreen.new()
	results.process_mode = Node.PROCESS_MODE_ALWAYS
	ui_layer.add_child(results)
	results.action_selected.connect(_on_results_action)


func _apply_hud_scale() -> void:
	if hud_layer == null:
		return
	var s := float(Game.settings["hud_scale"])
	var viewport_size := Vector2(get_viewport().get_visible_rect().size)
	hud_layer.transform = Transform2D(0.0, Vector2(s, s), 0.0, viewport_size * 0.5 * (1.0 - s))


func _show_intro() -> void:
	loading_layer = CanvasLayer.new()
	loading_layer.layer = 30
	add_child(loading_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.015, 0.02, 0.022, 1.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading_layer.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	var tag := UiTheme.label("OPERATION  //  %s" % String(map_data.get("name", "")).to_upper(), 12, UiTheme.ACCENT)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tag)
	var title := UiTheme.heading(mode_title, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var brief := UiTheme.label(String(mission.get("briefing", "")), 14, UiTheme.MUTED)
	brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	brief.custom_minimum_size = Vector2(620, 0)
	brief.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(brief)
	var diff := UiTheme.label("THREAT LEVEL: %s" % String(Game.settings["difficulty"]).to_upper(), 13, UiTheme.ACCENT)
	diff.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(diff)
	var hint := UiTheme.label("WASD MOVE    SHIFT SPRINT    CTRL CROUCH/SLIDE    RMB AIM    R RELOAD    F INTERACT    L LIGHT", 11, UiTheme.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	var tween := create_tween()
	tween.tween_interval(0.8)
	tween.tween_property(dim, "color:a", 0.0, 0.7)
	tween.parallel().tween_property(box, "modulate:a", 0.0, 0.7)
	tween.tween_callback(loading_layer.queue_free)


func spawn_enemy(position: Vector3, route: Array = [], role: String = "assault") -> Enemy:
	var enemy := Enemy.new()
	add_child(enemy)
	enemy.setup(builder, player, position + Vector3.UP * 0.2, route, role)
	enemy.died.connect(_on_enemy_died)
	director.register(enemy)
	enemies.append(enemy)
	return enemy


# ------------------------------------------------------------------ update ---

func _process(delta: float) -> void:
	if get_tree().paused or finished:
		return
	elapsed += delta
	_process_mode(delta)
	_update_objectives(delta)
	_update_interaction(delta)
	_update_hud()
	_checkpoint_timer += delta
	if _checkpoint_timer > 45.0 and mode_id == "campaign":
		_checkpoint_timer = 0.0
		save_checkpoint()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not finished:
		toggle_pause()
		get_viewport().set_input_as_handled()


func toggle_pause() -> void:
	if finished:
		return
	paused = not paused
	get_tree().paused = paused
	if paused:
		pause_menu.open(_can_retry())
	else:
		pause_menu.close()


func _restart() -> void:
	Game.start_run(mode_id, mission_id, {"retry": true})


func current_objective() -> Dictionary:
	if objective_index < 0 or objective_index >= objectives.size():
		return {}
	return objectives[objective_index]


func marker_position(marker_name: String) -> Vector3:
	var value = markers.get(marker_name, null)
	if value == null:
		return player.global_position if player != null else Vector3.ZERO
	return value


func _update_objectives(_delta: float) -> void:
	var obj := current_objective()
	if obj.is_empty():
		return
	var type := String(obj.get("type", ""))
	match type:
		"reach":
			var target := marker_position(String(obj.get("marker", "")))
			if player.global_position.distance_to(target) < 4.0:
				_complete_objective()
		"extract":
			var target2 := marker_position(String(obj.get("marker", "")))
			if player.global_position.distance_to(target2) < 4.0:
				_complete_objective()
		"eliminate":
			if objective_kills >= int(obj.get("count", 0)):
				_complete_objective()
		"destroy":
			pass
		_:
			pass


func _update_interaction(delta: float) -> void:
	var obj := current_objective()
	if obj.is_empty():
		interact_active = false
		if hud != null:
			hud.set_prompt("")
		return
	var type := String(obj.get("type", ""))
	if type != "destroy":
		if type == "intel":
			pass
		if hud != null:
			hud.set_prompt("")
		return
	var target := marker_position(String(obj.get("marker", "")))
	var distance := player.global_position.distance_to(target)
	if distance < 3.2:
		interact_active = true
		if hud != null:
			var prompt_text := String(obj.get("prompt", "HOLD  [F]  TO PLANT CHARGE"))
			hud.set_prompt("%s   —   %.0f%%" % [prompt_text, interact_timer / 1.8 * 100.0])
		if Input.is_action_pressed("interact"):
			interact_timer += delta
			if interact_timer >= 1.8:
				_complete_objective()
				interact_timer = 0.0
				if fx != null:
					fx.explosion_light(target, Color(1.0, 0.6, 0.25), 12.0, 22.0)
				Audio.play_3d("wave_start", target, 0.0, 0.7, 60.0)
				if hud != null:
					hud.show_banner(String(obj.get("banner", "CHARGE DETONATED")), "OBJECTIVE SECURED", 2.0)
		else:
			interact_timer = maxf(0.0, interact_timer - delta * 2.0)
	else:
		interact_active = false
		if hud != null:
			hud.set_prompt("")


func _complete_objective() -> void:
	if objective_index >= objectives.size():
		return
	objectives[objective_index]["done"] = true
	objective_index += 1
	objective_kills = 0
	interact_timer = 0.0
	Audio.play_ui("rank_up", -6.0)
	if hud != null:
		hud.set_prompt("")
	if objective_index >= objectives.size():
		finish_mission(true, "ALL OBJECTIVES COMPLETE")
	else:
		if hud != null:
			hud.show_message("OBJECTIVE COMPLETE", 1.8)
		save_checkpoint()


func _update_hud() -> void:
	if hud == null:
		return
	var entries: Array = []
	for i in objectives.size():
		var obj: Dictionary = objectives[i]
		entries.append({
			"text": String(obj.get("label", "")),
			"done": bool(obj.get("done", false)),
			"active": i == objective_index,
		})
	hud.set_objectives(mode_title, entries)
	hud.set_timer(_hud_timer_text())
	hud.set_score(_hud_score_text())


# --------------------------------------------------------------- events ------

func _on_shot_hit(headshot: bool, _killed: bool) -> void:
	if headshot:
		headshots += 1
	if hud != null:
		hud.flash_hit(headshot)


func _on_player_damaged(direction: Vector3, amount: float) -> void:
	if hud != null:
		hud.damage_from(direction, amount)


func _on_weapon_changed(_weapon_id: String, display_name: String) -> void:
	if hud != null:
		hud.show_message(display_name.to_upper(), 1.2)


func _on_results_action(action: String) -> void:
	match action:
		"retry":
			get_tree().paused = false
			Game.start_run(mode_id, mission_id, {"retry": true})
		"menu":
			get_tree().paused = false
			Game.return_to_menu()
		"continue":
			get_tree().paused = false
			_continue_after_results()
		_:
			Game.return_to_menu()


func finish_mission(victory: bool, reason: String) -> void:
	if finished:
		return
	finished = true
	last_victory = victory
	Game.capture_mouse(false)
	get_tree().paused = true
	_record_outcome(victory)
	if victory:
		Game.clear_checkpoint()
	Audio.play_ui("rank_up" if victory else "damage", -4.0)
	var stats: Array = _result_stats()
	var subtitle := reason
	if not victory:
		subtitle = reason
	results.show_result(victory, _finish_title(victory), subtitle, stats, _can_retry(), _continue_label())


func _continue_label() -> String:
	return "CONTINUE"


func _result_stats() -> Array:
	var fired := int(Game.profile["shots_fired"]) - _shots_start
	var hits := int(Game.profile["shots_hit"]) - _hits_start
	var acc := 0.0 if fired <= 0 else float(hits) / float(fired) * 100.0
	return [
		{"label": "Time", "value": UiTheme.format_time(elapsed)},
		{"label": "Hostiles eliminated", "value": str(kills)},
		{"label": "Headshots", "value": str(headshots)},
		{"label": "Accuracy", "value": "%.1f%%  (%d / %d)" % [acc, hits, fired]},
		{"label": "Threat level", "value": String(Game.settings["difficulty"])},
	]


# ------------------------------------------------------------ checkpoints ---

func save_checkpoint() -> void:
	if mode_id != "campaign" or finished or player == null:
		return
	var enemy_state: Array = []
	for e in enemies:
		if is_instance_valid(e) and not e.is_dead:
			enemy_state.append({"pos": [e.global_position.x, e.global_position.y, e.global_position.z], "health": e.health})
	var data := {
		"mode": mode_id,
		"mission_id": mission_id,
		"map_id": map_id,
		"elapsed": elapsed,
		"kills": kills,
		"headshots": headshots,
		"objective_index": objective_index,
		"objective_kills": objective_kills,
		"player": {
			"pos": [player.global_position.x, player.global_position.y, player.global_position.z],
			"yaw": player.yaw,
			"health": player.health,
			"armor": player.armor,
		},
		"weapons": player.weapon_system.export_state(),
		"enemies": enemy_state,
	}
	Game.write_checkpoint(data)


func _restore_from_checkpoint() -> void:
	if _resume_data.is_empty():
		return
	if String(_resume_data.get("mode", "")) != mode_id or String(_resume_data.get("mission_id", "")) != mission_id:
		return
	var player_data: Dictionary = _resume_data.get("player", {})
	var pos_array: Array = player_data.get("pos", [])
	if pos_array.size() == 3:
		var spawn := Transform3D(Basis(Vector3.UP, float(player_data.get("yaw", 0.0))), Vector3(float(pos_array[0]), float(pos_array[1]), float(pos_array[2])))
		player.revive_at(spawn, float(player_data.get("health", 100.0)), float(player_data.get("armor", 50.0)))
		player.weapon_system.import_state(_resume_data.get("weapons", []))
	elapsed = float(_resume_data.get("elapsed", 0.0))
	kills = int(_resume_data.get("kills", 0))
	headshots = int(_resume_data.get("headshots", 0))
	objective_index = clampi(int(_resume_data.get("objective_index", 0)), 0, maxi(0, objectives.size() - 1))
	objective_kills = int(_resume_data.get("objective_kills", 0))
	for i in mini(objective_index, objectives.size()):
		objectives[i]["done"] = true
	# Rebuild the surviving garrison at its saved posts.
	var saved: Array = _resume_data.get("enemies", [])
	if saved.is_empty():
		return
	for e in enemies:
		if is_instance_valid(e):
			director.unregister(e)
			e.queue_free()
	enemies.clear()
	for entry in saved:
		var arr: Array = entry.get("pos", [])
		if arr.size() != 3:
			continue
		var enemy := spawn_enemy(Vector3(float(arr[0]), float(arr[1]), float(arr[2])), [], "assault")
		enemy.health = float(entry.get("health", enemy.max_health))
	if hud != null:
		hud.show_message("CHECKPOINT RESTORED", 2.5)
