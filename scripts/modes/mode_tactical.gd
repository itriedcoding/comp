class_name TacticalMode
extends GameMode
## Stealth-flavoured objective run: recover intel, avoid the alarm, exfiltrate
## before the extraction window closes. Raising the alarm brings reinforcements.

const TIME_LIMIT := 480.0
const REINFORCEMENT_DELAY := 12.0
const REINFORCEMENT_COUNT := 6

var alarm_timer := -1.0
var reinforcements_sent := false
var time_limit := TIME_LIMIT


func _prepare() -> void:
	map_id = "urban"
	mode_id = "tactical"
	mission = GameData.mission_by_map("urban")
	mission_id = String(mission.get("id", "m2"))
	mode_title = "DEAD DROP  //  SOKOL HEIGHTS"
	objectives = []


func _setup_objectives() -> void:
	objectives = [
		{"type": "reach", "marker": "plaza", "label": "Move through the plaza undetected", "done": false},
		{"type": "destroy", "marker": "relay", "label": "Recover the intel from the relay", "prompt": "HOLD  [F]  TO RECOVER INTEL", "banner": "INTEL RECOVERED", "done": false},
		{"type": "extract", "marker": "extract", "label": "Exfiltrate through the alley", "done": false},
	]
	objective_index = 0
	objective_kills = 0


func _spawn_enemies() -> void:
	var spawn_list: Array = map_data.get("enemy_spawns", [])
	var difficulty: Dictionary = Game.difficulty_modifiers()
	var limit := int(round(float(mini(spawn_list.size(), 9)) * float(difficulty.get("count", 1.0))))
	for i in limit:
		var spawn: Dictionary = spawn_list[i]
		spawn_enemy(spawn.get("position", Vector3.ZERO), spawn.get("patrol", []), "assault" if i < 5 else "flanker")


func _post_setup() -> void:
	Audio.play_3d("wave_start", player.global_position, -14.0, 0.8, 40.0)
	if hud != null:
		hud.show_banner("DEAD DROP", "STAY QUIET — SUPPRESSED WEAPONS RECOMMENDED", 3.0)


func _process_mode(delta: float) -> void:
	if elapsed > time_limit:
		finish_mission(false, "EXTRACTION WINDOW CLOSED")
		return
	if not alarm:
		for e in enemies:
			if is_instance_valid(e) and not e.is_dead and e.state == Enemy.State.COMBAT:
				_raise_alarm(e.global_position)
				break
	if alarm and not reinforcements_sent:
		alarm_timer -= delta
		if alarm_timer <= 0.0:
			_send_reinforcements()
	if hud != null:
		hud.set_timer("EXFIL WINDOW  %s%s" % [UiTheme.format_time(maxf(0.0, time_limit - elapsed)), "   |   ALARM ACTIVE" if alarm else ""])


func _raise_alarm(position: Vector3) -> void:
	if alarm:
		return
	alarm = true
	alarm_timer = REINFORCEMENT_DELAY
	Audio.play_3d("alarm", position, -2.0, 1.0, 90.0)
	if hud != null:
		hud.show_banner("ALARM RAISED", "THEY KNOW YOU ARE HERE", 3.0)
		hud.add_feed("ALARM RAISED — REINFORCEMENTS INBOUND", UiTheme.DANGER)


func _send_reinforcements() -> void:
	reinforcements_sent = true
	var spawn_list: Array = map_data.get("enemy_spawns", [])
	spawn_list.shuffle()
	for i in mini(REINFORCEMENT_COUNT, spawn_list.size()):
		var spawn: Dictionary = spawn_list[i]
		var pos: Vector3 = spawn.get("position", Vector3.ZERO)
		if pos.distance_to(player.global_position) < 12.0:
			continue
		spawn_enemy(pos, spawn.get("patrol", []), "flanker" if i % 2 == 0 else "assault")
	Audio.play_ui("wave_start", -4.0)
	if hud != null:
		hud.add_feed("REINFORCEMENTS DEPLOYED", UiTheme.DANGER)


func _on_enemy_died(enemy: Enemy) -> void:
	super._on_enemy_died(enemy)
	if alarm:
		score += 50


func _hud_score_text() -> String:
	return "KILLS %d   ALARM %s" % [kills, "ACTIVE" if alarm else "CLEAR"]


func _hud_timer_text() -> String:
	return "EXFIL WINDOW  %s%s" % [UiTheme.format_time(maxf(0.0, time_limit - elapsed)), "   |   ALARM ACTIVE" if alarm else ""]


func _finish_title(victory: bool) -> String:
	return "EXTRACTION COMPLETE" if victory else "OPERATION FAILED"


func _result_stats() -> Array:
	var bonus := 0
	if last_victory and not alarm:
		bonus = 500
		score += bonus
	return [
		{"label": "Time", "value": UiTheme.format_time(elapsed)},
		{"label": "Hostiles eliminated", "value": str(kills)},
		{"label": "Alarm raised", "value": "YES" if alarm else "NO"},
		{"label": "Silent bonus", "value": str(bonus)},
		{"label": "Score", "value": str(score)},
		{"label": "Threat level", "value": String(Game.settings["difficulty"])},
	]


func _continue_label() -> String:
	return "MAIN MENU"


func _process(delta: float) -> void:
	super._process(delta)
