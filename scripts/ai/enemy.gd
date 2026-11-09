class_name Enemy
extends CharacterBody3D
## Hostile operator AI: sight/sound perception, patrols, cover use, flanking,
## suppressive bursts, hit reactions and death. Shares contacts through the
## SquadDirector so the team presses together instead of standing in the open.

signal died(enemy: Enemy)
signal damaged(enemy: Enemy, amount: float)

enum State { PATROL, INVESTIGATE, COMBAT, SEARCH, DEAD }

const MAX_HEALTH := 100.0

var director: SquadDirector
var player: Player
var builder: WorldBuilder

var state := State.PATROL
var route: Array = []
var route_index := 0
var route_wait := 0.0
var health := MAX_HEALTH
var max_health := MAX_HEALTH
var is_dead := false
var awareness := 0.0
var last_known := Vector3.ZERO
var has_last_known := false
var alert_timer := 0.0
var search_timer := 0.0
var reaction_timer := 0.0
var fire_cooldown := 0.0
var burst_left := 0
var burst_timer := 0.0
var reload_timer := 0.0
var ammo := 30
var magazine := 30
var cover_target := Vector3.ZERO
var has_cover_target := false
var in_cover := false
var peek_timer := 0.0
var peeking := false
var suppress_timer := 0.0
var role := "assault"
var flank_position := Vector3.ZERO
var has_flank_order := false
var stagger := 0.0
var _path := PackedVector3Array()
var _path_index := 0
var _repath_timer := 0.0
var _anim_time := 0.0
var _rng := RandomNumberGenerator.new()
var _visual: Node3D
var _head_mesh: MeshInstance3D
var _leg_left: Node3D
var _leg_right: Node3D
var _arm_left: Node3D
var _arm_right: Node3D
var _gun: Node3D
var _muzzle: Node3D
var _eye_height := 1.6
var _facing := 0.0
var _cover_strafe_dir := 1.0
var _strafe_timer := 0.0
var _last_seen_timer := 99.0
var _scan_time := 0.0
var _difficulty: Dictionary = {}
var _shotguns := false
var _call_timer := 0.0
var _moving_intent := false
var _hips: Node3D
var _torso: Node3D
var _head_pivot: Node3D
var _shin_left: Node3D
var _shin_right: Node3D
var _forearm_left: Node3D
var _forearm_right: Node3D
var _crouch_blend := 0.0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	floor_max_angle = deg_to_rad(50)
	floor_snap_length = 0.4
	add_to_group("enemies")
	_rng.seed = int(Time.get_ticks_usec() % 999983)
	_difficulty = Game.difficulty_modifiers()
	max_health = MAX_HEALTH * float(_difficulty.get("health", 1.0))
	health = max_health
	_build_body()
	_build_visual()
	magazine = 30
	ammo = 210
	reaction_timer = float(_difficulty.get("reaction", 1.0)) * _rng.randf_range(0.35, 0.7)


func setup(b: WorldBuilder, p: Player, spawn: Vector3, patrol_route: Array = [], assigned_role: String = "assault") -> void:
	builder = b
	player = p
	global_position = spawn
	route = patrol_route.duplicate()
	route_index = 0
	role = assigned_role
	if route.is_empty():
		route_wait = _rng.randf_range(1.0, 4.0)
		_facing = _rng.randf_range(0.0, TAU)
		rotation.y = _facing
	var difficulty: Dictionary = Game.difficulty_modifiers()
	_shotguns = _rng.randf() < 0.15
	if _shotguns:
		magazine = 7
		ammo = 40


func _build_body() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.7
	shape.shape = capsule
	shape.position.y = 0.85
	shape.name = "Body"
	add_child(shape)
	var head := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.19
	head.shape = sphere
	head.position.y = 1.62
	head.name = "Head"
	add_child(head)


func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	var uniform := Materials.get_material("fabric")
	var vest := Materials.get_material("vest")
	var armor := Materials.get_material("metal_panel")
	var glove := Materials.get_material("glove")
	var skin := Materials.get_material("skin")
	var boot := Materials.get_material("rubber")
	var glass := Materials.get_material("glass")

	# Pelvis and articulated torso.
	_hips = Node3D.new()
	_hips.name = "Hips"
	_hips.position = Vector3(0, 0.92, 0)
	_visual.add_child(_hips)
	_add_mesh(_hips, Vector3(0, 0.02, 0), Vector3(0.34, 0.24, 0.26), uniform)

	_torso = Node3D.new()
	_torso.name = "Torso"
	_torso.position = Vector3(0, 0.3, 0)
	_hips.add_child(_torso)
	_add_mesh(_torso, Vector3(0, 0.12, 0), Vector3(0.42, 0.5, 0.25), uniform)
	_add_mesh(_torso, Vector3(0, 0.14, -0.015), Vector3(0.45, 0.4, 0.3), vest)
	for i in 3:
		_add_mesh(_torso, Vector3(-0.12 + float(i) * 0.12, -0.01, -0.18), Vector3(0.1, 0.13, 0.06), vest)
	_add_mesh(_torso, Vector3(0.13, 0.3, 0.16), Vector3(0.06, 0.2, 0.06), armor)
	_add_mesh(_torso, Vector3(0, 0.14, 0.19), Vector3(0.26, 0.32, 0.13), vest)
	_add_mesh(_torso, Vector3(-0.25, 0.26, 0), Vector3(0.13, 0.12, 0.2), armor)
	_add_mesh(_torso, Vector3(0.25, 0.26, 0), Vector3(0.13, 0.12, 0.2), armor)

	# Neck, head, helmet, goggles and NVG mount.
	_add_mesh(_torso, Vector3(0, 0.36, 0), Vector3(0.11, 0.09, 0.11), skin)
	_head_pivot = Node3D.new()
	_head_pivot.name = "HeadPivot"
	_head_pivot.position = Vector3(0, 0.44, 0)
	_torso.add_child(_head_pivot)
	_head_mesh = _add_mesh(_head_pivot, Vector3.ZERO, Vector3(0.2, 0.24, 0.21), skin, true)
	var helmet := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.155
	sphere.height = 0.2
	sphere.radial_segments = 16
	sphere.rings = 8
	helmet.mesh = sphere
	helmet.material_override = armor
	helmet.position = Vector3(0, 0.04, 0.005)
	helmet.scale = Vector3(1.06, 0.86, 1.12)
	_head_mesh.add_child(helmet)
	_add_mesh(_head_pivot, Vector3(0, 0.015, -0.1), Vector3(0.17, 0.055, 0.035), glass)
	_add_mesh(_head_pivot, Vector3(0, 0.12, -0.09), Vector3(0.05, 0.05, 0.05), armor)

	# Arms with elbow joints.
	_arm_left = Node3D.new()
	_arm_left.position = Vector3(-0.26, 0.24, 0)
	_torso.add_child(_arm_left)
	_add_mesh(_arm_left, Vector3(0, -0.16, 0), Vector3(0.12, 0.32, 0.13), uniform)
	_forearm_left = Node3D.new()
	_forearm_left.position = Vector3(0, -0.31, 0)
	_arm_left.add_child(_forearm_left)
	_add_mesh(_forearm_left, Vector3(0, -0.14, -0.03), Vector3(0.1, 0.28, 0.11), uniform)
	_add_mesh(_forearm_left, Vector3(0, -0.29, -0.07), Vector3(0.09, 0.1, 0.13), glove)
	_arm_right = Node3D.new()
	_arm_right.position = Vector3(0.26, 0.24, 0)
	_torso.add_child(_arm_right)
	_add_mesh(_arm_right, Vector3(0, -0.16, 0), Vector3(0.12, 0.32, 0.13), uniform)
	_forearm_right = Node3D.new()
	_forearm_right.position = Vector3(0, -0.31, 0)
	_arm_right.add_child(_forearm_right)
	_add_mesh(_forearm_right, Vector3(0, -0.14, -0.03), Vector3(0.1, 0.28, 0.11), uniform)
	_add_mesh(_forearm_right, Vector3(0, -0.29, -0.07), Vector3(0.09, 0.1, 0.13), glove)

	# Legs with knee pads and boots.
	_leg_left = Node3D.new()
	_leg_left.position = Vector3(-0.12, -0.06, 0)
	_hips.add_child(_leg_left)
	_add_mesh(_leg_left, Vector3(0, -0.2, 0), Vector3(0.15, 0.42, 0.17), uniform)
	_add_mesh(_leg_left, Vector3(0, -0.36, -0.05), Vector3(0.14, 0.12, 0.1), armor)
	_shin_left = Node3D.new()
	_shin_left.position = Vector3(0, -0.41, 0)
	_leg_left.add_child(_shin_left)
	_add_mesh(_shin_left, Vector3(0, -0.2, 0), Vector3(0.13, 0.4, 0.15), uniform)
	_add_mesh(_shin_left, Vector3(0, -0.41, -0.04), Vector3(0.13, 0.1, 0.26), boot)
	_leg_right = Node3D.new()
	_leg_right.position = Vector3(0.12, -0.06, 0)
	_hips.add_child(_leg_right)
	_add_mesh(_leg_right, Vector3(0, -0.2, 0), Vector3(0.15, 0.42, 0.17), uniform)
	_add_mesh(_leg_right, Vector3(0, -0.36, -0.05), Vector3(0.14, 0.12, 0.1), armor)
	_shin_right = Node3D.new()
	_shin_right.position = Vector3(0, -0.41, 0)
	_leg_right.add_child(_shin_right)
	_add_mesh(_shin_right, Vector3(0, -0.2, 0), Vector3(0.13, 0.4, 0.15), uniform)
	_add_mesh(_shin_right, Vector3(0, -0.41, -0.04), Vector3(0.13, 0.1, 0.26), boot)

	# Rifle with optic, magazine and stock.
	_gun = Node3D.new()
	_gun.position = Vector3(0.12, 0.1, -0.33)
	_torso.add_child(_gun)
	_add_mesh(_gun, Vector3(0, 0, 0), Vector3(0.055, 0.09, 0.48), armor)
	_add_mesh(_gun, Vector3(0, 0.01, -0.34), Vector3(0.026, 0.026, 0.34), armor)
	_add_mesh(_gun, Vector3(0, -0.02, -0.28), Vector3(0.05, 0.06, 0.2), vest)
	_add_mesh(_gun, Vector3(0, -0.01, 0.32), Vector3(0.05, 0.08, 0.2), vest)
	_add_mesh(_gun, Vector3(0, -0.1, -0.04), Vector3(0.045, 0.15, 0.08), armor)
	_add_mesh(_gun, Vector3(0, 0.08, -0.02), Vector3(0.04, 0.05, 0.12), armor)
	_add_mesh(_gun, Vector3(0, 0.075, -0.09), Vector3(0.035, 0.035, 0.012), glass)
	_muzzle = Node3D.new()
	_muzzle.position = Vector3(0, 0.01, -0.55)
	_gun.add_child(_muzzle)


func _add_mesh(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, sphere: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if sphere:
		var s := SphereMesh.new()
		s.radius = size.x * 0.5
		s.height = size.y
		s.radial_segments = 12
		s.rings = 6
		mi.mesh = s
	else:
		mi.mesh = WorldBuilder.box_mesh(size, 2.0)
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if player == null or builder == null:
		return
	_difficulty = Game.difficulty_modifiers()
	_moving_intent = false
	_anim_time += delta
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	repath_timer(delta)
	_update_perception(delta)
	_update_state(delta)
	_update_movement(delta)
	_update_visual(delta)


func repath_timer(delta: float) -> void:
	_repath_timer -= delta
	burst_timer -= delta
	search_timer -= delta
	alert_timer -= delta
	suppress_timer = maxf(0.0, suppress_timer - delta)
	stagger = maxf(0.0, stagger - delta)
	_last_seen_timer += delta
	reload_timer = maxf(0.0, reload_timer - delta)
	_call_timer -= delta


func _eye_position() -> Vector3:
	return global_position + Vector3.UP * _eye_height


func can_see_player() -> bool:
	if player == null or player.is_dead:
		return false
	var eye := _eye_position()
	var target := player.global_position + Vector3.UP * 1.2
	var to_target := target - eye
	var distance := to_target.length()
	var view_distance: float = 62.0 * clampf(float(_difficulty.get("detection", 1.0)), 0.6, 1.8)
	if distance > view_distance:
		return false
	var forward := -global_transform.basis.z
	forward.y = 0.0
	var flat := Vector3(to_target.x, 0, to_target.z).normalized()
	var fov := 110.0
	if state == State.PATROL or state == State.INVESTIGATE:
		fov = 95.0
	if rad_to_deg(acos(clampf(forward.normalized().dot(flat), -1.0, 1.0))) > fov * 0.5:
		return false
	var space := get_world_3d().direct_space_state
	if space == null:
		return false
	var query := PhysicsRayQueryParameters3D.create(eye, target, 1)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	return hit.is_empty()


func _update_perception(delta: float) -> void:
	var visible := can_see_player()
	var detection: float = float(_difficulty.get("detection", 1.0))
	if visible:
		var distance := global_position.distance_to(player.global_position)
		var strength := clampf(1.4 - distance / 70.0, 0.25, 1.4)
		if player.is_crouching:
			strength *= 0.8
		if player.is_sprinting:
			strength *= 1.25
		awareness = minf(1.5, awareness + delta * strength * detection * 1.15)
		last_known = player.global_position
		has_last_known = true
		_last_seen_timer = 0.0
		if awareness >= 1.0 and state != State.COMBAT:
			_enter_combat()
	else:
		awareness = maxf(0.0, awareness - delta * 0.18)
		if state == State.COMBAT and _last_seen_timer > 6.0:
			state = State.SEARCH
			search_timer = 8.0
	if awareness >= 1.0 and state == State.COMBAT and visible:
		_face_towards(player.global_position, delta, 8.0)


func hear_noise(position: Vector3, radius: float, _source: String = "player") -> void:
	if is_dead:
		return
	var distance := global_position.distance_to(position)
	if distance > radius * 2.4:
		return
	last_known = position
	has_last_known = true
	awareness = maxf(awareness, 0.45)
	if state == State.PATROL:
		state = State.INVESTIGATE
		alert_timer = 16.0
		_path = builder.find_path(global_position, position) if builder != null else PackedVector3Array()
		_path_index = 0
	if state == State.COMBAT:
		pass


func on_squad_contact(position: Vector3, _reporter: Node = null) -> void:
	if is_dead:
		return
	last_known = position
	has_last_known = true
	awareness = maxf(awareness, 0.9)
	if state != State.COMBAT:
		state = State.COMBAT
		_path = builder.find_path(global_position, position) if builder != null else PackedVector3Array()
		_path_index = 0
		reaction_timer = float(_difficulty.get("reaction", 1.0)) * 0.5
		has_cover_target = false


func on_rounds_near(position: Vector3, radius: float) -> void:
	if is_dead:
		return
	if global_position.distance_to(position) <= radius:
		suppress_timer = 2.0
		if state == State.PATROL:
			last_known = position
			has_last_known = true
			state = State.INVESTIGATE
			alert_timer = 12.0


func _enter_combat() -> void:
	state = State.COMBAT
	reaction_timer = float(_difficulty.get("reaction", 1.0)) * _rng.randf_range(0.25, 0.6)
	has_cover_target = false
	in_cover = false
	peek_timer = _rng.randf_range(0.8, 2.0)
	if director != null:
		director.report_contact(player.global_position, self)
	if _call_timer <= 0.0:
		_call_timer = 6.0
		Audio.play_3d("shot_rifle", global_position, -26.0, 0.8, 40.0)


func _update_state(delta: float) -> void:
	match state:
		State.PATROL:
			_update_patrol(delta)
		State.INVESTIGATE:
			_update_investigate(delta)
		State.COMBAT:
			_update_combat(delta)
		State.SEARCH:
			_update_search(delta)


func _update_patrol(delta: float) -> void:
	if route.is_empty():
		route_wait -= delta
		_scan_time += delta
		_facing += sin(_scan_time * 0.6) * delta * 0.5
		rotation.y = _facing
		return
	var target: Vector3 = route[route_index]
	if global_position.distance_to(target) < 1.4:
		route_index = (route_index + 1) % route.size()
		route_wait = _rng.randf_range(1.5, 4.0)
	if route_wait > 0.0:
		route_wait -= delta
		var look_target: Vector3 = route[route_index]
		_face_towards(look_target, delta, 3.0)
		return
	_move_towards(route[route_index], 2.6, delta)


func _update_investigate(delta: float) -> void:
	alert_timer -= delta
	var target := last_known
	if global_position.distance_to(target) < 2.0:
		# Sweep the area, then resume patrol.
		_scan_time += delta
		_facing += sin(_scan_time * 1.2) * delta * 1.6
		rotation.y = _facing
		if alert_timer <= 0.0:
			state = State.PATROL
			route_wait = 2.0
		return
	_move_towards(target, 3.4, delta)
	if alert_timer <= 0.0:
		state = State.PATROL


func _update_combat(delta: float) -> void:
	if player == null or player.is_dead:
		state = State.SEARCH
		search_timer = 6.0
		return
	var visible := can_see_player()
	if visible:
		last_known = player.global_position
		has_last_known = true
		_last_seen_timer = 0.0
	else:
		_last_seen_timer += delta
		if _last_seen_timer > 4.0:
			state = State.SEARCH
			search_timer = 9.0
			return
	# Assign flanking when the squad has a contact but this unit cannot see it.
	if not visible and director != null and role == "flanker" and not has_flank_order:
		has_flank_order = true
		flank_position = director.request_flank(self)
	if role == "flanker" and has_flank_order and not visible:
		_move_towards(flank_position, 4.6, delta)
		if global_position.distance_to(flank_position) < 1.8:
			has_flank_order = false
			role = "assault"
		return
	var distance := global_position.distance_to(player.global_position)
	var desired_distance := 12.0
	# Low health: fall back into cover.
	if health < max_health * 0.3:
		if builder != null and not has_cover_target:
			var cp: Dictionary = builder.find_cover_near(global_position, player.global_position, 20.0)
			if not cp.is_empty():
				cover_target = cp["position"]
				has_cover_target = true
		if has_cover_target:
			_move_towards(cover_target, 5.0, delta)
			if global_position.distance_to(cover_target) < 1.4:
				in_cover = true
				has_cover_target = false
			_try_fire(visible)
			return
	# Seek cover when exposed and far enough away.
	if not in_cover and has_cover_target:
		_move_towards(cover_target, 4.4, delta)
		if global_position.distance_to(cover_target) < 1.3:
			in_cover = true
			has_cover_target = false
			peek_timer = _rng.randf_range(0.8, 1.8)
		_try_fire(visible)
		return
	if not in_cover and suppress_timer > 0.0 and builder != null:
		var cp2: Dictionary = builder.find_cover_near(global_position, player.global_position, 16.0)
		if not cp2.is_empty():
			cover_target = cp2["position"]
			has_cover_target = true
			return
	# In cover: peek periodically and fire.
	if in_cover:
		peek_timer -= delta
		if peek_timer <= 0.0:
			peeking = not peeking
			peek_timer = _rng.randf_range(0.7, 1.5) if peeking else _rng.randf_range(1.0, 2.4)
			if peeking:
				_try_fire(visible, true)
		_try_fire(visible, peeking)
		if not peeking and health > max_health * 0.4:
			# Reload while behind cover.
			if magazine <= 0 and reload_timer <= 0.0:
				reload_timer = 2.6
			if reload_timer > 0.0:
				pass
		return
	# No cover: keep distance and strafe.
	if distance > 26.0:
		_move_towards(player.global_position, 3.8, delta)
	elif distance < 7.0 and health < max_health * 0.6:
		_move_towards(global_position - (player.global_position - global_position).normalized() * 6.0, 3.6, delta)
	else:
		_strafe_timer -= delta
		if _strafe_timer <= 0.0:
			_strafe_timer = _rng.randf_range(1.0, 2.2)
			_cover_strafe_dir = -_cover_strafe_dir
		var right := (player.global_position - global_position).cross(Vector3.UP).normalized()
		_move_towards(global_position + right * _cover_strafe_dir * 3.0, 2.4, delta)
	_face_towards(player.global_position, delta, 6.0)
	_try_fire(visible)


func _update_search(delta: float) -> void:
	search_timer -= delta
	var target := last_known
	if global_position.distance_to(target) > 2.5:
		_move_towards(target, 3.6, delta)
	else:
		_scan_time += delta
		_facing += sin(_scan_time * 0.9) * delta * 1.2
		rotation.y = _facing
	if search_timer <= 0.0:
		state = State.PATROL
		has_flank_order = false
		role = "assault"
		if director != null:
			director.has_contact = false


func _try_fire(visible: bool, force: bool = false) -> void:
	if not visible or player == null or player.is_dead:
		return
	if reaction_timer > 0.0:
		reaction_timer -= get_physics_process_delta_time()
		return
	if reload_timer > 0.0:
		if reload_timer <= 0.01:
			magazine = 30
		return
	if fire_cooldown > 0.0:
		return
	if magazine <= 0:
		reload_timer = 2.8
		return
	if not force and burst_left <= 0:
		var aggression: float = float(_difficulty.get("aggression", 1.0))
		burst_left = _rng.randi_range(2, 5) if not _shotguns else 1
		burst_timer = 0.0
		fire_cooldown = _rng.randf_range(0.35, 0.9) / aggression
		burst_timer = 0.09 / float(_difficulty.get("fire_rate", 1.0))
	_shoot()
	magazine -= 1
	if _shotguns:
		burst_left = 0
		fire_cooldown = 0.85 / float(_difficulty.get("fire_rate", 1.0))
	else:
		burst_left -= 1
		burst_timer = 0.085 / float(_difficulty.get("fire_rate", 1.0))
		fire_cooldown = burst_timer if burst_left > 0 else _rng.randf_range(0.4, 1.1) / float(_difficulty.get("aggression", 1.0))


func _shoot() -> void:
	var muzzle_position := _muzzle.global_position if _muzzle != null else _eye_position()
	var target := player.global_position + Vector3.UP * 1.15
	var to_target := (target - muzzle_position).normalized()
	var accuracy: float = float(_difficulty.get("accuracy", 1.0))
	var spread := clampf(6.5 / maxf(0.5, accuracy), 1.2, 10.0)
	if player.is_crouching:
		spread *= 0.85
	if suppress_timer > 0.0:
		spread *= 1.4
	var direction := Ballistics.spread_direction(to_target, spread, _rng)
	var space := get_world_3d().direct_space_state
	if space == null:
		return
	var query := PhysicsRayQueryParameters3D.create(muzzle_position, muzzle_position + direction * 120.0, 1 | 2)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	var did_hit := false
	if not hit.is_empty():
		var collider = hit["collider"]
		if collider is Player:
			did_hit = true
			var distance := player.global_position.distance_to(global_position)
			var base_damage := 16.0 if _shotguns else 11.0
			var falloff := clampf(1.0 - distance / 120.0, 0.45, 1.0)
			player.take_damage(base_damage * falloff * float(_difficulty.get("damage", 1.0)), global_position)
		else:
			var surface := "concrete"
			if collider != null and collider.has_meta("surface"):
				surface = String(collider.get_meta("surface"))
			var fx := Fx.get_active()
			if fx != null:
				fx.impact(hit["position"], hit["normal"], surface)
	var fx2 := Fx.get_active()
	if fx2 != null:
		fx2.tracer(muzzle_position, hit["position"] if not hit.is_empty() else muzzle_position + direction * 40.0)
		fx2.muzzle_flash(muzzle_position)
	var stats: Dictionary = GameData.weapon("kx15")
	Audio.gunshot(stats, global_position, false)
	if did_hit:
		Audio.play_ui("hitmarker", -22.0)
	# Report the shooter's position to the squad.
	if director != null and _rng.randf() < 0.25:
		director.report_contact(player.global_position, self)


func _move_towards(target: Vector3, speed: float, delta: float) -> void:
	if builder == null:
		return
	_moving_intent = true
	if _repath_timer <= 0.0 or _path.is_empty():
		_path = builder.find_path(global_position, target)
		_path_index = 0
		_repath_timer = 0.65
	if _path.is_empty():
		return
	var next := _path[min(_path_index, _path.size() - 1)]
	var flat := Vector3(next.x - global_position.x, 0, next.z - global_position.z)
	if flat.length() < 0.9 and _path_index < _path.size() - 1:
		_path_index += 1
		next = _path[_path_index]
		flat = Vector3(next.x - global_position.x, 0, next.z - global_position.z)
	if flat.length() > 0.01:
		flat = flat.normalized()
		var target_speed := speed
		if state == State.COMBAT:
			target_speed *= 1.25
		if stagger > 0.0:
			target_speed *= 0.35
		velocity.x = move_toward(velocity.x, flat.x * target_speed, 14.0 * delta)
		velocity.z = move_toward(velocity.z, flat.z * target_speed, 14.0 * delta)
		_face_towards(global_position + flat, delta, 5.0)


func _face_towards(target: Vector3, delta: float, speed: float) -> void:
	var flat := Vector3(target.x - global_position.x, 0, target.z - global_position.z)
	if flat.length_squared() < 0.001:
		return
	_facing = lerp_angle(_facing, atan2(-flat.x, -flat.z), clampf(delta * speed, 0.0, 1.0))
	rotation.y = _facing


func _update_movement(delta: float) -> void:
	if not _moving_intent:
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = -0.2
	move_and_slide()


func _update_visual(delta: float) -> void:
	if _visual == null:
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	var move := clampf(speed / 3.0, 0.0, 1.0)
	var cycle := _anim_time * (5.0 + speed * 1.7)
	var swing := sin(cycle) * 0.8 * move
	var blend := clampf(delta * 12.0, 0.0, 1.0)
	if _leg_left != null:
		_leg_left.rotation.x = lerpf(_leg_left.rotation.x, swing, blend)
	if _leg_right != null:
		_leg_right.rotation.x = lerpf(_leg_right.rotation.x, -swing, blend)
	if _shin_left != null:
		_shin_left.rotation.x = lerpf(_shin_left.rotation.x, maxf(0.0, -swing) * 1.15, blend)
	if _shin_right != null:
		_shin_right.rotation.x = lerpf(_shin_right.rotation.x, maxf(0.0, swing) * 1.15, blend)
	var crouching := in_cover and not peeking
	_crouch_blend = move_toward(_crouch_blend, 1.0 if crouching else 0.0, delta * 3.5)
	if _hips != null:
		_hips.position.y = 0.92 - 0.34 * _crouch_blend + absf(sin(cycle)) * 0.035 * move
	if _torso != null:
		_torso.rotation.x = lerpf(_torso.rotation.x, 0.5 * _crouch_blend, clampf(delta * 6.0, 0.0, 1.0))
		_torso.rotation.y = lerpf(_torso.rotation.y, sin(cycle) * 0.07 * move, blend)
	var aiming := state == State.COMBAT or state == State.SEARCH
	if _arm_right != null:
		_arm_right.rotation.x = lerpf(_arm_right.rotation.x, -1.15 if aiming else -sin(cycle) * swing * 0.5, clampf(delta * 9.0, 0.0, 1.0))
		_arm_right.rotation.z = lerpf(_arm_right.rotation.z, -0.2 if aiming else 0.0, clampf(delta * 9.0, 0.0, 1.0))
	if _arm_left != null:
		_arm_left.rotation.x = lerpf(_arm_left.rotation.x, -1.35 if aiming else sin(cycle) * swing * 0.5, clampf(delta * 9.0, 0.0, 1.0))
		_arm_left.rotation.z = lerpf(_arm_left.rotation.z, 0.45 if aiming else 0.0, clampf(delta * 9.0, 0.0, 1.0))
	if _forearm_right != null:
		_forearm_right.rotation.x = lerpf(_forearm_right.rotation.x, -0.55 if aiming else -0.15, clampf(delta * 8.0, 0.0, 1.0))
	if _forearm_left != null:
		_forearm_left.rotation.x = lerpf(_forearm_left.rotation.x, -0.8 if aiming else -0.15, clampf(delta * 8.0, 0.0, 1.0))
	if _gun != null:
		_gun.rotation.x = lerpf(_gun.rotation.x, 0.0 if aiming else 0.5, clampf(delta * 8.0, 0.0, 1.0))
	if _head_pivot != null and player != null and aiming:
		var look := player.global_position + Vector3.UP * 1.1 - _head_pivot.global_position
		var wanted := atan2(-look.x, -look.z)
		var local_yaw := clampf(wrapf(wanted - rotation.y, -PI, PI), -0.85, 0.85)
		_head_pivot.rotation.y = lerp_angle(_head_pivot.rotation.y, local_yaw, clampf(delta * 6.0, 0.0, 1.0))


func take_hit(damage: float, direction: Vector3, point: Vector3, headshot: bool, source: Node3D) -> void:
	if is_dead:
		return
	health -= damage
	awareness = 1.5
	last_known = (source.global_position if source != null else player.global_position if player != null else global_position)
	has_last_known = true
	_last_seen_timer = 0.0
	stagger = 0.28
	if state != State.COMBAT:
		state = State.COMBAT
		reaction_timer = float(_difficulty.get("reaction", 1.0)) * 0.4
	var fx := Fx.get_active()
	if fx != null:
		fx.blood(point, -direction)
	if director != null:
		director.report_contact(last_known, self)
	damaged.emit(self, damage)
	if headshot or health <= 0.0:
		_die(headshot)


func _die(headshot: bool = false) -> void:
	if is_dead:
		return
	is_dead = true
	state = State.DEAD
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	if director != null:
		director.unregister(self)
	var fx := Fx.get_active()
	if fx != null:
		fx.blood(global_position + Vector3.UP * 1.4, Vector3.UP)
	if _visual != null:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(_visual, "rotation:z", deg_to_rad(82.0), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(_visual, "position:y", -0.25, 0.8)
	var timer := get_tree().create_timer(14.0)
	timer.timeout.connect(func():
		if is_instance_valid(self):
			var fade := create_tween()
			fade.tween_property(self, "scale", Vector3(1, 0.02, 1), 0.6)
			fade.tween_callback(queue_free)
	)
	died.emit(self)


func alive() -> bool:
	return not is_dead
