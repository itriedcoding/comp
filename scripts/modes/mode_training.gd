class_name TrainingMode
extends GameMode
## Timed shooting-range drill with pop-up targets, accuracy scoring and grades.

const DRILL_TIME := 80.0
const MAX_TARGETS := 6
const MISS_PENALTY := 25
const TARGET_PENALTY := 10

var drill_time := DRILL_TIME
var targets_hit := 0
var targets_missed := 0
var shots_taken := 0
var target_spawn_timer := 0.0
var active_targets: Array = []
var spawn_candidates: Array = []
var drill_over := false
var _shot_connected := false


func _prepare() -> void:
	map_id = "industrial"
	mode_id = "training"
	mission = {
		"name": "Shooting Range",
		"briefing": "Eighty seconds on the yard range. Steel targets pop up at varying distance — score for speed and precision, penalties for misses and expired targets.",
		"objectives": [],
	}
	mode_title = "SHOOTING RANGE"
	objectives = []


func _spawn_enemies() -> void:
	pass


func _setup_objectives() -> void:
	objectives = []


func _post_setup() -> void:
	player.global_position = Vector3(0, 0.4, 52)
	player.yaw = 0.0
	player.rotation.y = 0.0
	player.pitch = 0.0
	drill_time = DRILL_TIME
	_build_spawn_candidates()
	player.weapon_system.fired.connect(_on_shot_fired)
	_shot_connected = true
	if hud != null:
		hud.show_banner("SHOOTING RANGE", "80 SECONDS — ENGAGE THE STEEL", 3.0)


func _build_spawn_candidates() -> void:
	spawn_candidates.clear()
	for x in range(-16, 17, 4):
		for z in range(14, 44, 4):
			var pos := Vector3(float(x), 0.0, float(z))
			if builder.is_walkable(pos):
				spawn_candidates.append(pos)
	if spawn_candidates.is_empty():
		for x in range(-10, 11, 5):
			spawn_candidates.append(Vector3(float(x), 0, 24))


func _process_mode(delta: float) -> void:
	if drill_over:
		return
	drill_time -= delta
	target_spawn_timer -= delta
	for t in active_targets.duplicate():
		if not is_instance_valid(t):
			active_targets.erase(t)
	if target_spawn_timer <= 0.0 and active_targets.size() < MAX_TARGETS and drill_time > 3.0:
		target_spawn_timer = 0.85
		_spawn_target()
	if drill_time <= 0.0:
		_end_drill()
	if hud != null:
		hud.set_timer("DRILL  %s   |   TARGETS %d" % [UiTheme.format_time(maxf(0.0, drill_time)), targets_hit])
		hud.set_score("SCORE %d   HITS %d   MISSES %d" % [score, targets_hit, targets_missed])


func _spawn_target() -> void:
	if spawn_candidates.is_empty():
		return
	var pos: Vector3 = spawn_candidates[randi() % spawn_candidates.size()]
	if player.global_position.distance_to(pos) < 8.0:
		return
	var target := TrainingTarget.new()
	add_child(target)
	target.global_position = pos + Vector3(0, randf_range(1.1, 2.0), 0)
	target.lifetime = randf_range(2.8, 4.4)
	target.hit.connect(_on_target_hit)
	target.expired.connect(_on_target_expired)
	active_targets.append(target)


func _on_target_hit(target: TrainingTarget, points: int) -> void:
	targets_hit += 1
	var distance := player.global_position.distance_to(target.global_position)
	var bonus := int(clampf(distance * 2.0, 0.0, 60.0))
	score += points + bonus
	active_targets.erase(target)
	if hud != null:
		hud.flash_hit(false)
		hud.show_message("+%d" % (points + bonus), 0.6)


func _on_target_expired(target: TrainingTarget) -> void:
	targets_missed += 1
	score = maxi(0, score - TARGET_PENALTY)
	active_targets.erase(target)


func _on_shot_fired() -> void:
	shots_taken += 1


func _on_weapon_fired_counted() -> void:
	pass


func _end_drill() -> void:
	if drill_over:
		return
	drill_over = true
	Game.record_training(score)
	var grade := "D"
	var acc := accuracy_percent()
	if score >= 2400 and acc >= 55.0:
		grade = "S"
	elif score >= 1800 and acc >= 45.0:
		grade = "A"
	elif score >= 1200:
		grade = "B"
	elif score >= 600:
		grade = "C"
	var subtitle := "SCORE %d   |   ACCURACY %.0f%%   |   GRADE %s" % [score, acc, grade]
	finish_mission(true, subtitle)


func accuracy_percent() -> float:
	if shots_taken <= 0:
		return 0.0
	return clampf(float(targets_hit) / float(shots_taken) * 100.0, 0.0, 100.0)


func _hud_score_text() -> String:
	return "SCORE %d   HITS %d   MISSES %d" % [score, targets_hit, targets_missed]


func _hud_timer_text() -> String:
	return "DRILL  %s" % UiTheme.format_time(maxf(0.0, drill_time))


func _finish_title(victory: bool) -> String:
	return "DRILL COMPLETE"


func _result_stats() -> Array:
	return [
		{"label": "Score", "value": str(score)},
		{"label": "Targets hit", "value": str(targets_hit)},
		{"label": "Targets missed", "value": str(targets_missed)},
		{"label": "Accuracy", "value": "%.1f%%" % accuracy_percent()},
		{"label": "Best score", "value": str(int(Game.profile["best_training"]))},
		{"label": "Threat level", "value": String(Game.settings["difficulty"])},
	]


func _continue_label() -> String:
	return "MAIN MENU"
