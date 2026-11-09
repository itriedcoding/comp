class_name SurvivalMode
extends GameMode
## Survival: escalating waves, credits earned per kill, resupply between waves.

const WAVE_INTERMISSION := 14.0
const SUPPLY_COST := 500
const SUPPLY_RADIUS := 4.0

var wave := 0
var credits := 0
var wave_active := false
var intermission := 6.0
var supply_position := Vector3(0, 0.2, 1.0)
var _spawn_locations: Array = []
var _wave_kills := 0


func _prepare() -> void:
	map_id = "industrial"
	mode_id = "survival"
	mission = {
		"name": "Survival",
		"briefing": "Hold the Kessler loading floor. Waves enter from the yard and the dock. Credits buy resupply between waves — stay alive as long as you can.",
		"objectives": [],
	}
	mode_title = "SURVIVAL  //  KESSLER DEPOT"
	objectives = []


func _spawn_enemies() -> void:
	_spawn_locations = []
	for spawn in map_data.get("enemy_spawns", []):
		_spawn_locations.append(spawn["position"])
	supply_position = player.global_position + Vector3(0, 0.0, -2.5)
	intermission = 5.0
	wave_active = false
	if hud != null:
		hud.show_banner("SURVIVAL", "WAVE 1 INBOUND", 2.5)


func _setup_objectives() -> void:
	objectives = []


func _process_mode(delta: float) -> void:
	if not wave_active:
		intermission -= delta
		if hud != null:
			hud.set_prompt("HOLD [F] AT THE SUPPLY CRATE  —  %d CREDITS  (RESUPPLY %d)" % [credits, SUPPLY_COST])
			if Input.is_action_pressed("interact") and player.global_position.distance_to(supply_position) < SUPPLY_RADIUS:
				_buy_supply()
		if intermission <= 0.0:
			_start_wave()
	_update_respawn_check()


func _start_wave() -> void:
	wave += 1
	wave_active = true
	_wave_kills = 0
	var count := mini(18, 3 + wave)
	var difficulty: Dictionary = Game.difficulty_modifiers()
	count = int(round(float(count) * float(difficulty.get("count", 1.0))))
	for i in count:
		var pos: Vector3 = _pick_spawn()
		var enemy := spawn_enemy(pos, [], "flanker" if i % 4 == 3 else "assault")
		var scale_health := 1.0 + float(wave - 1) * 0.06
		enemy.max_health = enemy.max_health * scale_health
		enemy.health = enemy.max_health
		enemy.awareness = 0.0
	Audio.play_ui("wave_start", -2.0)
	if hud != null:
		hud.show_banner("WAVE %d" % wave, "%d HOSTILES" % count, 2.2)
		hud.add_feed("WAVE %d — %d HOSTILES INBOUND" % [wave, count], UiTheme.ACCENT)
		hud.set_prompt("")


func _pick_spawn() -> Vector3:
	if _spawn_locations.is_empty():
		return player.global_position + Vector3(randf_range(-20, 20), 0, randf_range(-20, 20))
	var best: Vector3 = _spawn_locations[0]
	var best_distance := -1.0
	for i in 4:
		var candidate: Vector3 = _spawn_locations[randi() % _spawn_locations.size()]
		var distance := candidate.distance_to(player.global_position)
		if distance > best_distance:
			best_distance = distance
			best = candidate
	return best


func _on_enemy_died(enemy: Enemy) -> void:
	super._on_enemy_died(enemy)
	credits += 120
	_wave_kills += 1
	score += 100
	if hud != null:
		hud.add_feed("+120 CREDITS", UiTheme.ACCENT)
	_update_respawn_check()


func _update_respawn_check() -> void:
	if not wave_active:
		return
	var alive := 0
	for e in enemies:
		if is_instance_valid(e) and not e.is_dead:
			alive += 1
	if alive == 0:
		wave_active = false
		credits += 250 * wave
		score += 400 * wave
		intermission = WAVE_INTERMISSION
		Game.record_survival(wave, credits)
		Audio.play_ui("rank_up", -4.0)
		if hud != null:
			hud.show_banner("WAVE %d CLEARED" % wave, "RESUPPLY AT THE CRATE  —  %d CREDITS" % credits, 3.0)


func _buy_supply() -> void:
	if credits < SUPPLY_COST:
		if hud != null:
			hud.show_message("INSUFFICIENT CREDITS", 1.5)
		return
	credits -= SUPPLY_COST
	player.weapon_system.refill_ammo()
	player.heal(60.0)
	player.add_armor(60.0)
	player.stamina = player.max_stamina
	Audio.play_ui("rank_up", -8.0)
	if hud != null:
		hud.show_message("RESUPPLIED  —  AMMO / ARMOR / HEALTH", 2.0)


func _hud_score_text() -> String:
	var alive := 0
	for e in enemies:
		if is_instance_valid(e) and not e.is_dead:
			alive += 1
	return "WAVE %d   CREDITS %d   HOSTILES %d" % [wave, credits, alive]


func _hud_timer_text() -> String:
	if wave_active:
		return "WAVE %d ACTIVE" % wave
	return "NEXT WAVE IN %s" % UiTheme.format_time(maxf(0.0, intermission))


func finish_mission(victory: bool, reason: String) -> void:
	Game.record_survival(wave, credits)
	super.finish_mission(victory, reason)


func _finish_title(victory: bool) -> String:
	return "SURVIVAL ENDED"


func _result_stats() -> Array:
	return [
		{"label": "Waves survived", "value": str(maxi(0, wave - (1 if wave_active else 0)))},
		{"label": "Current wave", "value": str(wave)},
		{"label": "Hostiles eliminated", "value": str(kills)},
		{"label": "Credits earned", "value": str(credits)},
		{"label": "Best wave", "value": str(int(Game.profile["best_wave"]))},
		{"label": "Threat level", "value": String(Game.settings["difficulty"])},
	]


func _continue_label() -> String:
	return "MAIN MENU"
