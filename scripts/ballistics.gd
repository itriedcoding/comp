class_name Ballistics
extends RefCounted
## Hitscan ballistics with distance falloff, material-aware penetration and
## headshot detection (the enemy head is collision shape index 1).

const MAX_PENETRATIONS := 4


static func falloff_mult(dist: float, stats: Dictionary) -> float:
	var start: float = float(stats.get("falloff_start", 30.0))
	var end: float = float(stats.get("falloff_end", 100.0))
	var minimum: float = float(stats.get("falloff_min", 0.6))
	if dist <= start:
		return 1.0
	if dist >= end:
		return minimum
	return lerpf(1.0, minimum, (dist - start) / maxf(0.001, end - start))


## Returns an ordered list of impacts. Each impact dictionary:
## point, normal, surface, collider, damage, headshot.
static func trace_shot(world: World3D, from: Vector3, direction: Vector3, stats: Dictionary, exclude: Array, shooter: Node3D) -> Array:
	var results: Array = []
	if world == null:
		return results
	var space := world.direct_space_state
	if space == null:
		return results
	var dir := direction.normalized()
	var travel := 0.0
	var max_range: float = float(stats.get("range", 300.0))
	var penetration: int = int(stats.get("penetration", 1))
	var damage: float = float(stats.get("damage", 30.0))
	var pos := from
	for step in range(MAX_PENETRATIONS + 1):
		var remaining := max_range - travel
		if remaining <= 0.05:
			break
		var query := PhysicsRayQueryParameters3D.create(pos, pos + dir * remaining, 1 | 4)
		query.exclude = exclude
		query.collide_with_areas = false
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			results.append({
				"point": pos + dir * remaining,
				"normal": -dir,
				"surface": "air",
				"collider": null,
				"damage": 0.0,
				"headshot": false,
			})
			break
		var point: Vector3 = hit["position"]
		var collider = hit["collider"]
		var normal: Vector3 = hit["normal"]
		var surface := "concrete"
		var has_hit_method: bool = collider != null and collider.has_method("take_hit")
		var is_target: bool = has_hit_method and collider.get("is_target") == true
		var is_enemy: bool = has_hit_method and not is_target
		if is_enemy:
			surface = "flesh"
		elif collider != null and collider.has_meta("surface"):
			surface = String(collider.get_meta("surface"))
		var dist := from.distance_to(point)
		var dmg := damage * falloff_mult(dist, stats)
		var headshot := false
		if has_hit_method:
			var shape_index := int(hit.get("shape", 0))
			headshot = is_enemy and shape_index == 1
			if headshot:
				dmg *= float(stats.get("headshot", 1.0))
			collider.take_hit(dmg, dir, point, headshot, shooter)
		results.append({
			"point": point,
			"normal": normal,
			"surface": surface,
			"collider": collider,
			"damage": dmg,
			"headshot": headshot,
		})
		travel += dist
		if has_hit_method:
			break
		var surf: Dictionary = GameData.surface(surface)
		var penetrable := bool(surf.get("penetrable", false))
		var material_power: int = int(surf.get("pen_power", 1))
		if penetrable and penetration >= material_power and remaining > dist + 1.2:
			penetration -= material_power
			damage *= 0.62
			pos = point + dir * 0.12
			travel += 0.12
		else:
			break
	return results


## Builds a direction inside a cone of `spread_degrees` around `forward`.
static func spread_direction(forward: Vector3, spread_degrees: float, rng: RandomNumberGenerator) -> Vector3:
	if spread_degrees <= 0.0001:
		return forward
	var up := Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	var right := forward.cross(up).normalized()
	var real_up := right.cross(forward).normalized()
	var angle := deg_to_rad(spread_degrees)
	var radius := sqrt(rng.randf()) * tan(angle)
	var theta := rng.randf() * TAU
	return (forward + right * (cos(theta) * radius) + real_up * (sin(theta) * radius)).normalized()


static func apply_impact_effect(fx: Node, hit: Dictionary) -> void:
	if fx == null:
		return
	var surface := String(hit.get("surface", "concrete"))
	if surface == "air":
		return
	fx.call("impact", hit["point"], hit["normal"], surface)


static func apply_tracer(fx: Node, from: Vector3, to: Vector3) -> void:
	if fx == null:
		return
	fx.call("tracer", from, to)
