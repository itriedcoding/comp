class_name BotMatchMode
extends GameMode
## Offline deathmatch: the player against seven AI operators, first to 25.

const SCORE_LIMIT := 25
const MATCH_TIME := 600.0
const PLAYER_RESPAWN := 3.0
const BOT_RESPAWN := 4.5
const BOT_COUNT := 7

var player_score := 0
var bot_score := 0
var respawn_timer := 0.0
var pending_bots: Array = []
var spawn_points: Array = []


func _prepare() -> void:
	map_id = "urban"
	mode_id = "botmatch"
	mode_title = "DEATHMATCH  //  SOKOL HEIGHTS"
	mission = {
		"name": "Deathmatch",
		"briefing": "Seven hostile operators are hunting you through the block. First to twenty-five eliminations wins. You respawn in three seconds; they are not so lucky.",
		"objectives": [],
	}
	objectives = []


func _setup_objectives() -> void:
	objectives = []


func _spawn_enemies() -> void:
	spawn_points.clear()
	for spawn in map_data.get("enemy_spawns", []):
		spawn_points.append(spawn["position"])
	spawn_points.shuffle()
	for i in BOT_COUNT:
		var pos: Vector3 = spawn_points[i % spawn_points.size()]
		spawn_enemy(pos, [], "flanker" if i % 2 == 1 else "assault")
	if hud != null:
		hud.show_banner("DEATHMATCH", "FIRST TO %d ELIMINATIONS" % SCORE_LIMIT, 3.0)
		hud.add_feed("SEVEN HOSTILE OPERATORS DEPLOYED", UiTheme.DANGER)


func _post_setup() -> void:
	player_score = 0
	bot_score = 0
	Game.capture_mouse(true)


func _process_mode(delta: float) -> void:
	if respawn_timer > 0.0:
		respawn_timer -= delta
		if hud != null:
			hud.set_prompt("RESPAWN IN %.1f" % maxf(0.0, respawn_timer))
		if respawn_timer <= 0.0:
			_respawn_player()
	if not pending_bots.is_empty():
		for entry in pending_bots.duplicate():
			entry["timer"] -= delta
			if entry["timer"] <= 0.0:
				pending_bots.erase(entry)
				_spawn_bot()
	if elapsed >= MATCH_TIME:
		finish_mission(player_score > bot_score, "TIME EXPIRED  —  %d : %d" % [player_score, bot_score])


func _on_enemy_died(enemy: Enemy) -> void:
	super._on_enemy_died(enemy)
	player_score += 1
	score = player_score
	if hud != null:
		hud.add_feed("ELIMINATED  —  +1", UiTheme.ACCENT)
		pending_bots.append({"timer": BOT_RESPAWN})
	if player_score >= SCORE_LIMIT:
		finish_mission(true, "SCORE LIMIT REACHED  —  %d : %d" % [player_score, bot_score])


func _on_player_died() -> void:
	bot_score += 1
	deaths += 1
	respawn_timer = PLAYER_RESPAWN
	if hud != null:
		hud.add_feed("YOU WERE ELIMINATED  —  BOTS +1", UiTheme.DANGER)
	if bot_score >= SCORE_LIMIT:
		finish_mission(false, "BOTS REACHED THE SCORE LIMIT  —  %d : %d" % [player_score, bot_score])


func _respawn_player() -> void:
	var pos := _safe_spawn()
	player.revive_at(Transform3D(Basis(Vector3.UP, randf_range(0.0, TAU)), pos), 100.0, 50.0)
	player.weapon_system.refill_ammo()
	Game.capture_mouse(true)
	if hud != null:
		hud.set_prompt("")


func _spawn_bot() -> void:
	var alive := 0
	for e in enemies:
		if is_instance_valid(e) and not e.is_dead:
			alive += 1
	if alive >= BOT_COUNT + 2:
		return
	var pos := _safe_spawn()
	spawn_enemy(pos, [], "flanker" if randi() % 2 == 0 else "assault")


func _safe_spawn() -> Vector3:
	if spawn_points.is_empty():
		return player.global_position + Vector3(10, 0, 10)
	var best: Vector3 = spawn_points[0]
	var best_distance := -1.0
	for i in 6:
		var candidate: Vector3 = spawn_points[randi() % spawn_points.size()]
		var d := candidate.distance_to(player.global_position)
		if d > best_distance:
			best_distance = d
			best = candidate
	return best + Vector3.UP * 0.2


func _hud_score_text() -> String:
	return "YOU %d   :   %d BOTS     [FIRST TO %d]" % [player_score, bot_score, SCORE_LIMIT]


func _hud_timer_text() -> String:
	return "MATCH  %s" % UiTheme.format_time(maxf(0.0, MATCH_TIME - elapsed))


func _finish_title(victory: bool) -> String:
	return "MATCH WON" if victory else "MATCH LOST"


func _result_stats() -> Array:
	return [
		{"label": "Final score", "value": "%d : %d" % [player_score, bot_score]},
		{"label": "Eliminations", "value": str(player_score)},
		{"label": "Deaths", "value": str(deaths)},
		{"label": "Headshots", "value": str(headshots)},
		{"label": "Match time", "value": UiTheme.format_time(elapsed)},
		{"label": "Threat level", "value": String(Game.settings["difficulty"])},
	]


func _continue_label() -> String:
	return "MAIN MENU"
