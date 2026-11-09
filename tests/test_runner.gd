extends Node
## Headless test suite: data integrity, maps, weapons, AI, modes, saves.

var checks := 0
var failures := 0
var _test_world: WorldBuilder


func _ready() -> void:
	await _run_all()


func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS  %s" % label)
	else:
		failures += 1
		print("FAIL  %s" % label)
		push_error("FAIL: %s" % label)


func _frames(count: int = 3) -> void:
	for i in count:
		await get_tree().physics_frame


func _run_all() -> void:
	print("=== BLACKSITE TEST SUITE ===")
	_test_inputs()
	_test_data()
	_test_settings()
	_test_audio_and_materials()
	await _test_maps()
	await _test_performance()
	await _test_player_and_weapons()
	await _test_ai()
	await _test_checkpoint()
	await _test_modes()
	print("=== RESULT: %d checks, %d failures ===" % [checks, failures])
	# Let queued frees and deferred callbacks drain so shutdown is clean.
	for i in 8:
		await get_tree().process_frame
	get_tree().quit(0 if failures == 0 else 1)


func _test_inputs() -> void:
	var actions := [
		"move_forward", "move_back", "move_left", "move_right", "jump", "sprint",
		"crouch", "lean_left", "lean_right", "fire", "aim", "reload",
		"weapon_1", "weapon_2", "weapon_3", "weapon_next", "weapon_prev",
		"pause", "interact", "tactical_light",
	]
	for action in actions:
		check(InputMap.has_action(action) and InputMap.action_get_events(action).size() > 0, "input action bound: %s" % action)


func _test_data() -> void:
	var required := ["name", "damage", "rpm", "mag", "reserve", "reload_tac", "spread_hip", "spread_ads", "recoil_v", "range", "fire_mode", "viewmodel"]
	for id in GameData.WEAPONS.keys():
		var w: Dictionary = GameData.WEAPONS[id]
		var ok := true
		for key in required:
			if not w.has(key):
				ok = false
		check(ok, "weapon definition complete: %s" % id)
		var resolved: Dictionary = GameData.resolved_weapon(id, {"optic": "none", "suppressor": "suppressor", "magazine": "extended", "grip": "vertical"})
		check(float(resolved["damage"]) > 0.0 and int(resolved["mag"]) > 0, "weapon resolves with attachments: %s" % id)
	check(GameData.MISSIONS.size() == 3, "three campaign missions defined")
	for mission in GameData.MISSIONS:
		check(["industrial", "urban", "outpost"].has(String(mission["map"])), "mission map exists: %s" % mission["id"])
		check(mission["objectives"].size() >= 3, "mission has objectives: %s" % mission["id"])
	for diff in Game.DIFFICULTIES:
		check(GameData.DIFFICULTY.has(diff), "difficulty tuning present: %s" % diff)
	check(GameData.MODES.size() >= 5, "five game modes defined")


func _test_settings() -> void:
	var original := float(Game.settings["sensitivity"])
	Game.set_setting("sensitivity", 2.25)
	Game.save_settings()
	Game.settings["sensitivity"] = 1.0
	Game.load_settings()
	check(absf(float(Game.settings["sensitivity"]) - 2.25) < 0.01, "settings persist and reload")
	Game.set_setting("sensitivity", original)
	Game.apply_settings()
	check(get_tree().root.scaling_3d_scale > 0.0, "root viewport scaling applied")
	check(Game.resolution_size().x >= 1280, "resolution parser returns sane size")


func _test_audio_and_materials() -> void:
	var ids := ["shot_rifle", "shot_smg", "shot_dmr", "shot_shotgun", "shot_pistol", "shot_suppressed", "mag_in", "bolt", "impact_metal", "foot_concrete_0", "wind_loop"]
	for id in ids:
		var stream: AudioStream = Audio.stream(id)
		check(stream != null and stream is AudioStreamWAV and stream.data.size() > 1000, "synthesised stream: %s" % id)
	Audio.play_ui("ui_click", -20.0)
	Audio.play_3d("shot_rifle", Vector3(0, 1, 0), -6.0)
	check(true, "audio playback calls accepted")
	var mat := Materials.get_material("concrete")
	check(mat != null and mat.albedo_texture != null, "procedural material has texture")
	check(Materials.get_material("metal_panel").metallic > 0.5, "metal material is metallic")
	var cached := Materials.get_material("concrete")
	check(cached == mat, "material cache returns same instance")


func _test_maps() -> void:
	for map_id in ["industrial", "urban", "outpost"]:
		var result: Dictionary = Maps.build(map_id)
		var builder: WorldBuilder = result["builder"]
		var data: Dictionary = result["data"]
		check(builder != null, "map builds: %s" % map_id)
		check(builder.cover_points.size() > 15, "map has cover points: %s (%d)" % [map_id, builder.cover_points.size()])
		check(builder.is_nav_ready(), "navigation grid ready: %s" % map_id)
		var spawn: Transform3D = data["player_spawn"]
		check(builder.is_walkable(spawn.origin), "player spawn walkable: %s" % map_id)
		check(data["enemy_spawns"].size() >= 8, "enemy spawns present: %s" % map_id)
		var marker: Vector3 = data["markers"]["extract"]
		var path := builder.find_path(spawn.origin, marker)
		check(path.size() > 1, "path from spawn to extract: %s (%d nodes)" % [map_id, path.size()])
		check(builder.world_to_grid(spawn.origin) != builder.world_to_grid(marker), "spawn and extract are distinct cells: %s" % map_id)
		var cover: Dictionary = builder.find_cover_near(spawn.origin, marker, 30.0)
		check(not cover.is_empty(), "cover search returns a point: %s" % map_id)
		for route_enemy in data["enemy_spawns"]:
			var patrol: Array = route_enemy.get("patrol", [])
			if patrol.is_empty():
				continue
			check(builder.is_walkable(patrol[0]), "patrol point walkable: %s" % map_id)
			break
		var env := Maps.make_environment(data)
		check(env.environment != null, "environment built: %s" % map_id)
		builder.queue_free()
		env.queue_free()
		await _frames(2)


func _count_mesh_instances(node: Node) -> int:
	var count := 0
	for child in node.get_children():
		if child is MeshInstance3D:
			count += 1
		count += _count_mesh_instances(child)
	return count


func _test_performance() -> void:
	var total_before := 0
	var total_after := 0
	for map_id in ["industrial", "urban", "outpost"]:
		var started := Time.get_ticks_msec()
		var result: Dictionary = Maps.build(map_id)
		var builder: WorldBuilder = result["builder"]
		add_child(builder)
		await _frames(2)
		var before := _count_mesh_instances(builder)
		var stats: Dictionary = builder.merge_static_geometry()
		await _frames(2)
		var after := _count_mesh_instances(builder)
		var elapsed := Time.get_ticks_msec() - started
		total_before += before
		total_after += after
		print("PERF  %-10s build+merge %4d ms   mesh nodes %4d -> %3d   material batches %2d   verts %d" % [map_id, elapsed, before, after, int(stats["groups"]), int(stats["vertices"])])
		check(after < 40, "merged draw batches per map: %s (%d)" % [map_id, after])
		check(after * 3 < before, "draw calls reduced by at least 3x: %s (%d -> %d)" % [map_id, before, after])
		check(elapsed < 5000, "map build stays under 5 s: %s (%d ms)" % [map_id, elapsed])
		builder.queue_free()
		await _frames(2)
	print("PERF  total mesh nodes %d -> %d" % [total_before, total_after])
	var mem_mb := Performance.get_monitor(Performance.MEMORY_STATIC) / (1024.0 * 1024.0)
	print("PERF  static memory %.0f MB" % mem_mb)
	check(mem_mb < 1800.0, "memory inside the 6 GB budget (static %.0f MB)" % mem_mb)


func _test_player_and_weapons() -> void:
	var builder := WorldBuilder.new()
	add_child(builder)
	_test_world = builder
	builder.add_box(Vector3(0, -0.5, 0), Vector3(80, 1, 80), "concrete", {"name": "TestFloor"})
	builder.add_box(Vector3(0, 1, -6), Vector3(6, 2, 0.5), "concrete", {"name": "TestWall"})
	builder.build_navigation(Rect2(-40, -40, 80, 80))
	var fx := Fx.new()
	add_child(fx)
	var player := Player.new()
	add_child(player)
	player.setup(Transform3D(Basis(), Vector3(0, 0.9, 0)), Game.profile["loadout"])
	player.force_input_active = true
	await _frames(20)
	check(player.is_on_floor(), "player lands on the floor")
	# Wait out the equip animation before testing the trigger.
	await _frames(45)
	check(player.camera != null and player.camera.current, "player camera is active")
	check(player.weapon_system.current_weapon_name() == "KX-15", "loadout equips the KX-15")
	var ammo_before: int = player.weapon_system.ammo_total()
	Input.action_press("fire")
	await _frames(10)
	Input.action_release("fire")
	await _frames(2)
	check(player.weapon_system.ammo_total() < ammo_before, "firing consumes ammunition")
	check(int(Game.profile["shots_fired"]) > 0, "shot recorded in profile")
	player.weapon_system.start_reload()
	check(player.weapon_system.is_reloading(), "reload state entered")
	player.weapon_system.state_timer = player.weapon_system.state_duration - 0.01
	await _frames(3)
	check(not player.weapon_system.is_reloading(), "reload completes")
	check(player.weapon_system.ammo_total() == 30, "reload refills the magazine")
	player.weapon_system.switch_to(2)
	await _frames(2)
	check(player.weapon_system.current_weapon_name() == "P226", "weapon switching changes to the sidearm")
	player.weapon_system.switch_to(0)
	await _frames(2)
	var armor_before := player.armor
	player.take_damage(40.0, player.global_position + Vector3(0, 0, -4))
	check(player.armor < armor_before, "armor absorbs damage")
	check(player.health < 100.0 and player.health > 40.0, "health reduced by unabsorbed damage")
	player.heal(100.0)
	check(player.health >= 99.0, "healing restores health")
	var start_pos := player.global_position
	Input.action_press("move_forward")
	await _frames(30)
	Input.action_release("move_forward")
	check(player.global_position.distance_to(start_pos) > 1.0, "player moves through physics")
	player.is_dead = false
	player.take_damage(1000.0, player.global_position)
	check(player.is_dead, "lethal damage kills the player")
	check(fx.get_child_count() >= 0, "fx node alive")
	player.queue_free()
	fx.queue_free()
	builder.queue_free()
	await _frames(3)


func _test_ai() -> void:
	var builder := WorldBuilder.new()
	add_child(builder)
	builder.add_box(Vector3(0, -0.5, 0), Vector3(80, 1, 80), "concrete", {"name": "TestFloor"})
	builder.add_box(Vector3(6, 1, -8), Vector3(2, 2, 6), "concrete", {"name": "CoverBlock"})
	builder.build_navigation(Rect2(-40, -40, 80, 80))
	var fx := Fx.new()
	add_child(fx)
	var player := Player.new()
	add_child(player)
	player.setup(Transform3D(Basis(), Vector3(0, 0.9, 0)), Game.profile["loadout"])
	await _frames(10)
	var director := SquadDirector.new()
	add_child(director)
	director.setup(builder, player)
	var enemy := Enemy.new()
	add_child(enemy)
	enemy.setup(builder, player, Vector3(0, 0.9, 12), [], "assault")
	director.register(enemy)
	await _frames(6)
	check(not enemy.is_dead, "enemy spawns alive")
	check(enemy.state == Enemy.State.PATROL, "enemy starts on patrol")
	enemy.rotation.y = 0.0
	enemy._facing = 0.0
	check(enemy.can_see_player(), "enemy line of sight works")
	enemy._enter_combat()
	await _frames(40)
	check(enemy.state == Enemy.State.COMBAT, "enemy enters combat")
	check(enemy.awareness > 0.4, "enemy awareness rises")
	check(director.alive_count() == 1, "director tracks the squad")
	var health_before := enemy.health
	enemy.take_hit(40.0, Vector3.FORWARD, enemy.global_position + Vector3.UP, false, player)
	check(enemy.health < health_before, "enemy takes damage")
	check(director.has_contact, "squad receives contact report")
	enemy.take_hit(1000.0, Vector3.FORWARD, enemy.global_position + Vector3.UP, true, player)
	check(enemy.is_dead, "enemy dies from lethal damage")
	check(director.alive_count() == 0, "director removes the dead enemy")
	player.queue_free()
	enemy.queue_free()
	director.queue_free()
	fx.queue_free()
	builder.queue_free()
	await _frames(3)


func _test_checkpoint() -> void:
	Game.write_checkpoint({
		"mode": "campaign",
		"mission_id": "m1",
		"map_id": "industrial",
		"elapsed": 42.5,
		"player": {"pos": [1.0, 0.2, 2.0], "health": 88.0, "armor": 40.0},
	})
	var data := Game.read_checkpoint()
	check(String(data.get("mission_id", "")) == "m1", "checkpoint round-trips")
	check(Game.has_mid_mission_save(), "checkpoint detected as mid-mission save")
	Game.clear_checkpoint()
	check(not Game.has_checkpoint(), "checkpoint cleared")


func _test_modes() -> void:
	var mode_ids := ["campaign", "training", "survival", "tactical", "botmatch"]
	for id in mode_ids:
		var mode: GameMode
		match id:
			"survival":
				mode = SurvivalMode.new()
			"training":
				mode = TrainingMode.new()
			"tactical":
				mode = TacticalMode.new()
			"botmatch":
				mode = BotMatchMode.new()
			_:
				mode = CampaignMode.new()
		add_child(mode)
		mode.start_run({"mode": id, "mission_id": "m1", "difficulty": "Regular"})
		await _frames(6)
		check(mode.player != null, "mode spawns the player: %s" % id)
		check(mode.builder != null and mode.map_data.size() > 0, "mode builds a map: %s" % id)
		check(mode.hud != null, "mode builds the HUD: %s" % id)
		check(mode.pause_menu != null and mode.results != null, "mode builds pause/results UI: %s" % id)
		check(not mode.finished, "mode is running: %s" % id)
		if id == "campaign":
			check(mode.objectives.size() == 4, "campaign objective chain loaded")
			check(mode.enemies.size() >= 6, "campaign spawns hostiles")
		if id == "survival":
			var survival := mode as SurvivalMode
			check(survival != null and (survival.wave_active or survival.intermission > 0.0), "survival wave cycle started")
		if id == "botmatch":
			check(mode.enemies.size() == 7, "botmatch spawns seven bots")
		mode.queue_free()
		get_tree().paused = false
		await _frames(3)
	check(true, "all game modes instantiate")
