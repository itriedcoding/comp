class_name SquadDirector
extends Node
## Coordinates a squad: shares contact reports, assigns flanking routes and
## keeps the team from stacking on top of each other.

var enemies: Array = []
var builder: WorldBuilder
var player: Player
var alert_position := Vector3.ZERO
var has_contact := false
var contact_age := 999.0
var flank_cursor := 0
var _rng := RandomNumberGenerator.new()


func setup(b: WorldBuilder, p: Player) -> void:
	builder = b
	player = p
	_rng.seed = 1212


func register(enemy: Enemy) -> void:
	if not enemies.has(enemy):
		enemies.append(enemy)
		enemy.director = self


func unregister(enemy: Enemy) -> void:
	enemies.erase(enemy)


func alive_count() -> int:
	var count := 0
	for e in enemies:
		if is_instance_valid(e) and not e.is_dead:
			count += 1
	return count


func _process(delta: float) -> void:
	contact_age += delta
	if contact_age > 12.0:
		has_contact = false


func report_contact(position: Vector3, reporter: Node = null) -> void:
	alert_position = position
	has_contact = true
	contact_age = 0.0
	for e in enemies:
		if is_instance_valid(e) and not e.is_dead and e != reporter:
			e.on_squad_contact(position, reporter)


func request_flank(enemy: Enemy) -> Vector3:
	if player == null or builder == null:
		return enemy.global_position
	var options: Array = builder.cover_for_positions(player.global_position, player.global_position, 26.0)
	if options.is_empty():
		var angle := _rng.randf_range(0.0, TAU)
		var candidate := player.global_position + Vector3(cos(angle), 0, sin(angle)) * 12.0
		var snapped := builder.find_path(enemy.global_position, candidate)
		if snapped.size() > 0:
			return snapped[snapped.size() - 1]
		return enemy.global_position
	flank_cursor += 1
	# Prefer positions away from the rest of the squad.
	var pick: Dictionary = options[flank_cursor % options.size()]
	for option in options:
		var pos: Vector3 = option["cover"]["position"]
		var too_close := false
		for e in enemies:
			if is_instance_valid(e) and e != enemy and not e.is_dead and e.global_position.distance_to(pos) < 5.0:
				too_close = true
				break
		if not too_close:
			pick = option
			break
	return pick["cover"]["position"]


func squad_center() -> Vector3:
	var total := Vector3.ZERO
	var count := 0
	for e in enemies:
		if is_instance_valid(e) and not e.is_dead:
			total += e.global_position
			count += 1
	if count == 0:
		return Vector3.ZERO
	return total / float(count)
