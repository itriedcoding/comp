class_name WeaponSystem
extends Node3D
## Weapon handling: ammunition state, fire modes, recoil, spread, ADS, reload
## state machine, attachments, switching and the animated first-person model.

signal ammo_changed(mag: int, reserve: int, chambered: bool)
signal weapon_changed(weapon_id: String, display_name: String)
signal shot_hit(headshot: bool, killed: bool)
signal fired
signal reload_state(active: bool)

const SLOT_NAMES := ["PRIMARY", "SECONDARY", "SIDEARM"]

var player: Player
var camera: Camera3D
var slots: Array[Dictionary] = []
var current_index := 0

var viewmodel: Node3D
var muzzle: Node3D
var _flash_mesh: MeshInstance3D
var _flash_light: OmniLight3D
var _flash_timer := 0.0

var ads := false
var ads_progress := 0.0
var trigger := false
var state := "idle"
var cooldown := 0.0
var state_timer := 0.0
var state_duration := 0.0
var reload_was_empty := false
var recoil_accum := 0.0
var _kick := 0.0
var _sway := Vector2.ZERO
var _sway_target := Vector2.ZERO
var _bob_time := 0.0
var _rng := RandomNumberGenerator.new()
var _eject_point: Node3D
var _sound_stage := 0


func setup(p: Player, cam: Camera3D, loadout: Dictionary) -> void:
	player = p
	camera = cam
	_rng.seed = int(Time.get_ticks_usec() % 1000000)
	var ids := [
		String(loadout.get("primary", "kx15")),
		String(loadout.get("secondary", "mp5")),
		String(loadout.get("sidearm", "p226")),
	]
	for id in ids:
		var att: Dictionary = Game.attachments_for(id)
		var stats: Dictionary = GameData.resolved_weapon(id, att)
		var capacity: int = int(stats["mag"])
		slots.append({
			"id": id,
			"stats": stats,
			"attachments": att,
			"mag": capacity - 1,
			"chamber": true,
			"reserve": int(stats["reserve"]),
		})
	_build_muzzle_nodes()
	_equip(0, true)


func _build_muzzle_nodes() -> void:
	muzzle = Node3D.new()
	muzzle.name = "Muzzle"
	add_child(muzzle)
	_flash_mesh = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.22, 0.22)
	_flash_mesh.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.85, 0.45, 0.9)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.25)
	mat.emission_energy_multiplier = 6.0
	quad.material = mat
	_flash_mesh.material_override = mat
	_flash_mesh.visible = false
	muzzle.add_child(_flash_mesh)
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color(1.0, 0.8, 0.45)
	_flash_light.light_energy = 0.0
	_flash_light.omni_range = 6.0
	_flash_light.shadow_enabled = false
	muzzle.add_child(_flash_light)


func current_slot() -> Dictionary:
	if slots.is_empty():
		return {}
	return slots[current_index]


func current_stats() -> Dictionary:
	var slot := current_slot()
	return slot.get("stats", {})


func current_weapon_id() -> String:
	return String(current_slot().get("id", "kx15"))


func current_weapon_name() -> String:
	return String(current_stats().get("name", "Weapon"))


func current_zoom() -> float:
	return float(current_stats().get("ads_zoom", 1.0))


func ammo_total() -> int:
	var slot := current_slot()
	if slot.is_empty():
		return 0
	return int(slot["mag"]) + (1 if bool(slot["chamber"]) else 0)


func reserve_ammo() -> int:
	return int(current_slot().get("reserve", 0))


func is_reloading() -> bool:
	return state == "reloading"


func _process(delta: float) -> void:
	if player == null:
		return
	cooldown = maxf(0.0, cooldown - delta)
	recoil_accum = maxf(0.0, recoil_accum - delta * 7.0)
	_kick = lerpf(_kick, 0.0, clampf(delta * 18.0, 0.0, 1.0))
	_flash_timer = maxf(0.0, _flash_timer - delta)
	if _flash_timer <= 0.0:
		_flash_mesh.visible = false
		_flash_light.light_energy = 0.0

	# Aim down sights blend.
	var target := 1.0 if ads else 0.0
	var ads_speed := 1.0 / maxf(0.05, float(current_stats().get("ads_time", 0.18)))
	ads_progress = move_toward(ads_progress, target, delta * ads_speed)
	if player != null:
		player.set_ads_state(ads_progress)

	# State machine timers.
	if state == "reloading":
		state_timer += delta
		var slot := current_slot()
		var progress := state_timer / maxf(0.01, state_duration)
		if progress > 0.35 and _sound_stage == 0:
			_sound_stage = 1
			Audio.play_3d("mag_in", player.global_position, -4.0, _rng.randf_range(0.95, 1.05), 22.0)
		if progress >= 1.0:
			_finish_reload()
	elif state == "equipping":
		state_timer += delta
		if state_timer >= state_duration:
			state = "idle"
			trigger = false

	# Trigger behaviour.
	if state == "idle" and trigger and cooldown <= 0.0 and not player.is_dead:
		var mode := String(current_stats().get("fire_mode", "auto"))
		if mode == "auto" or mode == "pump":
			_try_fire()
	_update_viewmodel(delta)


func trigger_down() -> void:
	trigger = true
	if state == "idle" and cooldown <= 0.0 and not player.is_dead:
		var mode := String(current_stats().get("fire_mode", "auto"))
		if mode == "semi":
			_try_fire()


func trigger_up() -> void:
	trigger = false


func set_ads(value: bool) -> void:
	ads = value
	if ads and state == "reloading":
		ads = false


func add_look_input(relative: Vector2) -> void:
	_sway_target += relative * 0.00035
	_sway_target = _sway_target.limit_length(0.05)


func _try_fire() -> void:
	var slot := current_slot()
	if slot.is_empty():
		return
	if ammo_total() <= 0:
		if cooldown <= 0.0:
			Audio.play_3d("dry_fire", player.global_position, -8.0, 1.0, 16.0)
			cooldown = 0.28
			if int(slot["reserve"]) > 0:
				start_reload()
		return
	var stats := current_stats()
	_fire_round(stats)
	var rpm: float = float(stats.get("rpm", 600.0))
	var interval := 60.0 / maxf(30.0, rpm)
	if String(stats.get("fire_mode", "auto")) == "pump":
		interval = maxf(interval, float(stats.get("pump_time", 0.75)))
	cooldown = interval
	_kick = minf(_kick + 1.0, 2.2)
	if String(stats.get("fire_mode", "")) == "pump":
		Audio.play_3d("pump", player.global_position, -14.0, 1.0, 12.0)


func _fire_round(stats: Dictionary) -> void:
	var slot := current_slot()
	# Consume a round, cycling from the magazine if a round is chambered.
	if bool(slot["chamber"]):
		if int(slot["mag"]) > 0:
			slot["mag"] = int(slot["mag"]) - 1
			slot["chamber"] = true
		else:
			slot["chamber"] = false
	else:
		if int(slot["mag"]) > 0:
			slot["mag"] = int(slot["mag"]) - 1
			slot["chamber"] = true
		else:
			return
	var suppressed := bool(stats.get("suppressed", false))
	# Recoil.
	var recoil_v: float = float(stats.get("recoil_v", 0.7)) * (1.0 - ads_progress * 0.25)
	var recoil_h: float = float(stats.get("recoil_h", 0.3))
	var crouch_mult := 0.8 if player.is_crouching else 1.0
	player.add_recoil(recoil_v * crouch_mult, _rng.randf_range(-recoil_h, recoil_h), float(stats.get("recoil_recovery", 8.0)))
	recoil_accum = minf(recoil_accum + recoil_v * 0.35, 6.0)
	# Spread.
	var spread := _current_spread(stats)
	var origin := camera.global_position
	var forward := -camera.global_transform.basis.z
	var pellets: int = int(stats.get("pellets", 1))
	var pellet_spread: float = float(stats.get("pellet_spread", 0.0))
	var muzzle_pos := muzzle.global_position
	var shooter_rid := player.get_rid()
	var any_hit := false
	var any_headshot := false
	var any_kill := false
	var tracer_drawn := false
	for i in pellets:
		var dir := Ballistics.spread_direction(forward, spread + pellet_spread, _rng)
		var hits: Array = Ballistics.trace_shot(player.get_world_3d(), origin, dir, stats, [shooter_rid], player)
		for hit in hits:
			var surface := String(hit.get("surface", "air"))
			if surface == "air":
				if not tracer_drawn and player.get_world_3d() != null:
					Ballistics.apply_tracer(Fx.get_active(), muzzle_pos, hit["point"])
					tracer_drawn = true
				continue
			Ballistics.apply_impact_effect(Fx.get_active(), hit)
			if not tracer_drawn:
				Ballistics.apply_tracer(Fx.get_active(), muzzle_pos, hit["point"])
				tracer_drawn = true
			if hit.get("collider") != null and hit["collider"].has_method("take_hit"):
				any_hit = true
				if bool(hit.get("headshot", false)):
					any_headshot = true
				if hit["collider"].get("is_dead") == true:
					any_kill = true
	# FX and audio.
	var fx := Fx.get_active()
	if fx != null:
		fx.shell_eject(muzzle_pos, camera.global_transform.basis.x)
	if not suppressed:
		_flash_mesh.visible = true
		_flash_timer = 0.05
		_flash_light.light_energy = 3.0
	Audio.gunshot(stats, player.global_position, suppressed)
	if fx != null:
		fx.muzzle_flash(muzzle_pos)
	var noise_radius: float = float(stats.get("noise", 50.0))
	player.get_tree().call_group("enemies", "hear_noise", player.global_position, noise_radius, "player")
	player.get_tree().call_group("enemies", "on_rounds_near", muzzle_pos, 9.0)
	Game.record_shot(any_hit)
	ammo_changed.emit(ammo_total(), reserve_ammo(), bool(slot["chamber"]))
	fired.emit()
	if any_hit:
		shot_hit.emit(any_headshot, any_kill)
		Audio.play_ui("headshot" if any_headshot else "hitmarker", -6.0 if any_headshot else -10.0)
		if any_kill:
			Audio.play_ui("kill", -10.0)


func current_spread_degrees() -> float:
	return _current_spread(current_stats())


func _current_spread(stats: Dictionary) -> float:
	var base: float = lerpf(float(stats.get("spread_hip", 2.0)), float(stats.get("spread_ads", 0.2)), ads_progress)
	var speed := 0.0
	if player != null:
		speed = Vector2(player.velocity.x, player.velocity.z).length()
	var move_ratio: float = clampf(speed / Player.WALK_SPEED, 0.0, 1.8)
	base += float(stats.get("spread_move", 1.5)) * move_ratio * (1.0 - ads_progress * 0.75)
	if player != null and not player.is_on_floor():
		base += float(stats.get("spread_air", 4.0)) * 0.5
	if player != null and player.is_crouching:
		base *= 0.72
	base += recoil_accum
	return clampf(base, 0.0, 12.0)


func start_reload() -> void:
	if state != "idle":
		return
	var slot := current_slot()
	if slot.is_empty():
		return
	var capacity: int = int(current_stats().get("mag", 30))
	var total := ammo_total()
	if total >= capacity or int(slot["reserve"]) <= 0:
		return
	reload_was_empty = total == 0
	state = "reloading"
	state_timer = 0.0
	_sound_stage = 0
	state_duration = float(current_stats().get("reload_empty" if reload_was_empty else "reload_tac", 2.4))
	ads = false
	trigger = false
	reload_state.emit(true)
	Audio.play_3d("mag_out", player.global_position, -3.0, _rng.randf_range(0.95, 1.05), 20.0)
	if reload_was_empty:
		Audio.play_3d("bolt", player.global_position, -12.0, 1.0, 18.0)


func _finish_reload() -> void:
	var slot := current_slot()
	var capacity: int = int(current_stats().get("mag", 30))
	var total := ammo_total()
	var reserve := int(slot["reserve"])
	var needed := capacity - total
	var taken := mini(needed, reserve)
	slot["reserve"] = reserve - taken
	var new_total := total + taken
	# Build the final state: chambered round plus magazine.
	slot["chamber"] = new_total > 0
	slot["mag"] = maxi(0, new_total - 1)
	state = "idle"
	trigger = false
	if reload_was_empty:
		Audio.play_3d("bolt", player.global_position, -4.0, 1.0, 20.0)
	reload_state.emit(false)
	ammo_changed.emit(ammo_total(), reserve_ammo(), bool(slot["chamber"]))
	recoil_accum = 0.0


func switch_to(index: int) -> void:
	if index < 0 or index >= slots.size() or index == current_index:
		return
	if state == "reloading":
		state = "idle"
		reload_state.emit(false)
	_equip(index, false)


func next_weapon(direction: int = 1) -> void:
	var next := (current_index + direction + slots.size()) % slots.size()
	switch_to(next)


func _equip(index: int, initial: bool) -> void:
	current_index = index
	state = "equipping"
	state_timer = 0.0
	state_duration = 0.15 if initial else float(current_stats().get("draw", 0.5))
	ads = false
	trigger = false
	ads_progress = 0.0
	recoil_accum = 0.0
	_build_viewmodel()
	weapon_changed.emit(current_weapon_id(), current_weapon_name())
	ammo_changed.emit(ammo_total(), reserve_ammo(), bool(current_slot().get("chamber", false)))
	if not initial:
		Audio.play_3d("draw", player.global_position, -8.0, 1.0, 16.0)


func _build_viewmodel() -> void:
	if viewmodel != null and is_instance_valid(viewmodel):
		viewmodel.queue_free()
	viewmodel = Node3D.new()
	viewmodel.name = "Viewmodel"
	add_child(viewmodel)
	var stats := current_stats()
	var vm: Dictionary = stats.get("viewmodel", {})
	var length: float = float(vm.get("length", 0.6))
	var height: float = float(vm.get("height", 0.1))
	var width: float = float(vm.get("width", 0.07))
	var barrel: float = float(vm.get("barrel", 0.25))
	if bool(stats.get("suppressed", false)):
		barrel += 0.14
	var metal := Materials.get_material("metal_panel")
	var dark := Materials.get_material("rubber")
	var wood := Materials.get_material("wood")

	# Receiver.
	_add_part(Vector3(0, 0, 0), Vector3(width, height, length * 0.52), metal)
	# Handguard.
	_add_part(Vector3(0, height * 0.02, -length * 0.42), Vector3(width * 0.92, height * 0.78, length * 0.36), dark)
	# Barrel.
	_add_cylinder_part(Vector3(0, height * 0.05, -length * 0.55 - barrel * 0.5), width * 0.26, barrel, metal)
	# Stock.
	if bool(vm.get("stock", true)):
		_add_part(Vector3(0, -height * 0.1, length * 0.4), Vector3(width * 0.8, height * 0.9, length * 0.28), dark)
	# Pistol grip.
	_add_part(Vector3(0, -height * 0.85, length * 0.16), Vector3(width * 0.8, height * 0.9, width * 0.9), dark, Vector3(18, 0, 0))
	# Magazine.
	var mag_kind := String(vm.get("magazine", "curved"))
	if mag_kind == "tube":
		_add_cylinder_part(Vector3(0, -height * 0.25, -length * 0.3), width * 0.3, length * 0.4, metal, Vector3(90, 0, 0))
	else:
		var mag_h := height * 1.25
		var mag_tilt := 0.0
		if mag_kind == "curved":
			mag_tilt = 12.0
		if mag_kind == "pistol":
			mag_h = height * 0.7
		_add_part(Vector3(0, -height * 0.7 - mag_h * 0.35, -length * 0.06), Vector3(width * 0.7, mag_h, width * 0.85), metal, Vector3(mag_tilt, 0, 0))
	# Top rail.
	_add_part(Vector3(0, height * 0.62, -length * 0.08), Vector3(width * 0.5, 0.012, float(vm.get("rail", 0.3))), dark)
	# Optic.
	var optic_id := String(current_slot().get("attachments", {}).get("optic", "none"))
	if optic_id != "none":
		var att: Dictionary = GameData.ATTACHMENTS.get(optic_id, {})
		var tube_len := 0.14
		var tube_r := 0.028
		if optic_id == "scope_4x" or optic_id == "acog":
			tube_len = 0.22
			tube_r = 0.032
		_add_cylinder_part(Vector3(0, height * 0.62 + tube_r + 0.012, -length * 0.08), tube_r, tube_len, metal, Vector3(90, 0, 0))
		var lens := _add_part(Vector3(0, height * 0.62 + tube_r + 0.012, -length * 0.08 - tube_len * 0.5), Vector3(tube_r * 1.6, tube_r * 1.6, 0.008), "glass")
		lens.name = "Lens"
		if optic_id == "red_dot" or optic_id == "holo":
			var dot := _add_part(Vector3(0, height * 0.62 + tube_r + 0.012, -length * 0.08 + tube_len * 0.5), Vector3(tube_r * 1.5, tube_r * 1.5, 0.006), "alarm_light")
			dot.name = "Reticle"
	else:
		# Iron sights.
		_add_part(Vector3(0, height * 0.66, -length * 0.45), Vector3(0.008, 0.03, 0.008), metal)
		_add_part(Vector3(0, height * 0.66, length * 0.05), Vector3(0.012, 0.026, 0.012), metal)
	# Suppressor geometry.
	if bool(stats.get("suppressed", false)):
		_add_cylinder_part(Vector3(0, height * 0.05, -length * 0.55 - barrel * 0.5), width * 0.34, 0.16, dark)
	# Muzzle node placement.
	if muzzle != null:
		muzzle.position = Vector3(0, height * 0.05, -length * 0.55 - barrel - 0.03)
	# Stock butt plate, ejection port, charging handle and sling loop.
	_add_part(Vector3(0, -height * 0.1, length * 0.54), Vector3(width * 0.85, height * 0.95, 0.02), dark)
	_add_part(Vector3(width * 0.53, height * 0.12, length * 0.02), Vector3(0.012, 0.035, 0.09), metal)
	_add_part(Vector3(width * 0.3, height * 0.45, length * 0.18), Vector3(0.02, 0.02, 0.07), metal)
	_add_part(Vector3(width * 0.3, -height * 0.15, length * 0.3), Vector3(0.01, 0.02, 0.04), metal)
	# Gloved hands: right on the grip, left supporting the handguard.
	_add_gloved_hand(Vector3(0.0, -height * 0.95, length * 0.14), true)
	_add_gloved_hand(Vector3(-0.005, -height * 0.55, -length * 0.34), false)
	viewmodel.position = Vector3(0.2, -0.16, -0.34)
	viewmodel.rotation = Vector3.ZERO


func _resolve_material(material: Variant) -> Material:
	if material is Material:
		return material
	return Materials.get_material(String(material))


func _add_part(pos: Vector3, size: Vector3, material: Variant, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = WorldBuilder.box_mesh(size, 4.0)
	mi.material_override = _resolve_material(material)
	mi.position = pos
	mi.rotation_degrees = rotation
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	viewmodel.add_child(mi)
	return mi


func _add_cylinder_part(pos: Vector3, radius: float, length: float, material: Variant, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = length
	cyl.radial_segments = 12
	mi.mesh = cyl
	mi.material_override = _resolve_material(material)
	mi.position = pos
	mi.rotation_degrees = Vector3(90, 0, 0) + rotation
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	viewmodel.add_child(mi)
	return mi


func _add_gloved_hand(pos: Vector3, on_grip: bool) -> void:
	var glove := Materials.get_material("glove")
	var hand := _add_part(pos, Vector3(0.055, 0.085, 0.075), glove)
	hand.name = "Hand"
	for i in 3:
		_add_part(pos + Vector3(0, 0.02, -0.05 - float(i) * 0.022), Vector3(0.05, 0.026, 0.02), glove)
	_add_part(pos + Vector3(-0.038, 0.03, 0.01), Vector3(0.025, 0.06, 0.03), glove)
	if on_grip:
		_add_part(pos + Vector3(0, -0.065, 0.02), Vector3(0.06, 0.07, 0.05), glove)


func _update_viewmodel(delta: float) -> void:
	if viewmodel == null or not is_instance_valid(viewmodel) or player == null:
		return
	_bob_time += delta * (6.0 + Vector2(player.velocity.x, player.velocity.z).length() * 1.2)
	_sway = _sway.lerp(_sway_target, clampf(delta * 8.0, 0.0, 1.0))
	_sway_target = _sway_target.lerp(Vector2.ZERO, clampf(delta * 4.0, 0.0, 1.0))
	var sway_scale := float(Game.settings["weapon_sway"])
	var hip := Vector3(0.2, -0.16, -0.34)
	var vm_data: Dictionary = current_stats().get("viewmodel", {})
	var vm_height := float(vm_data.get("height", 0.1))
	var optic_id := String(current_slot().get("attachments", {}).get("optic", "none"))
	var sight_y := vm_height * 0.7
	if optic_id != "none":
		sight_y = vm_height * 0.62 + (0.05 if optic_id == "scope_4x" or optic_id == "acog" else 0.042)
	var aim := Vector3(0.0, -sight_y, -0.24)
	var target_pos := hip.lerp(aim, ads_progress)
	var bob_amt := 0.012 * float(Game.settings["headbob"]) * (1.0 - ads_progress * 0.85)
	target_pos.x += sin(_bob_time) * bob_amt + _sway.x * 1.4 * sway_scale
	target_pos.y += absf(cos(_bob_time)) * bob_amt * 0.8 + _sway.y * 1.2 * sway_scale
	target_pos.z += _kick * 0.035
	var target_rot := Vector3(
		_kick * 0.12 + _sway.y * 1.6 * sway_scale,
		_sway.x * 1.8 * sway_scale,
		-sin(_bob_time * 0.5) * 0.006 + _sway.x * 0.6 * sway_scale
	)
	if state == "reloading":
		var t: float = clampf(state_timer / maxf(0.01, state_duration), 0.0, 1.0)
		var dip: float = sin(t * PI)
		target_pos.y -= dip * 0.18
		target_rot.x -= dip * 0.55
		target_rot.z += dip * 0.35
		target_pos.z += dip * 0.05
	elif state == "equipping":
		var t: float = clampf(state_timer / maxf(0.01, state_duration), 0.0, 1.0)
		target_pos.y -= (1.0 - t) * 0.32
		target_rot.x -= (1.0 - t) * 0.7
	viewmodel.position = viewmodel.position.lerp(target_pos, clampf(delta * 16.0, 0.0, 1.0))
	viewmodel.rotation = viewmodel.rotation.lerp(target_rot, clampf(delta * 14.0, 0.0, 1.0))


func refill_ammo() -> void:
	for slot in slots:
		var stats: Dictionary = slot["stats"]
		slot["reserve"] = int(stats.get("reserve", 120))
		slot["mag"] = int(stats.get("mag", 30)) - 1
		slot["chamber"] = true
	ammo_changed.emit(ammo_total(), reserve_ammo(), true)


func add_reserve(amount: int) -> void:
	for slot in slots:
		slot["reserve"] = int(slot["reserve"]) + amount
	ammo_changed.emit(ammo_total(), reserve_ammo(), bool(current_slot().get("chamber", false)))


func export_state() -> Array:
	var out: Array = []
	for slot in slots:
		out.append({
			"id": slot["id"],
			"mag": int(slot["mag"]),
			"chamber": bool(slot["chamber"]),
			"reserve": int(slot["reserve"]),
		})
	return out


func import_state(data: Array) -> void:
	for i in mini(data.size(), slots.size()):
		var entry: Dictionary = data[i]
		if String(entry.get("id", "")) != String(slots[i]["id"]):
			continue
		slots[i]["mag"] = int(entry.get("mag", slots[i]["mag"]))
		slots[i]["chamber"] = bool(entry.get("chamber", true))
		slots[i]["reserve"] = int(entry.get("reserve", slots[i]["reserve"]))
	state = "idle"
	ammo_changed.emit(ammo_total(), reserve_ammo(), bool(current_slot().get("chamber", false)))


func hud_data() -> Dictionary:
	return {
		"name": current_weapon_name(),
		"class": String(current_stats().get("class", "")),
		"fire_mode": String(current_stats().get("fire_mode", "auto")),
		"mag": ammo_total(),
		"capacity": int(current_stats().get("mag", 30)),
		"reserve": reserve_ammo(),
		"slot": SLOT_NAMES[current_index] if current_index < SLOT_NAMES.size() else "",
		"reloading": state == "reloading",
		"suppressed": bool(current_stats().get("suppressed", false)),
	}
