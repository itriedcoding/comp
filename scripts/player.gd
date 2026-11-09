class_name Player
extends CharacterBody3D
## First-person operator: acceleration-based movement, sprint/stamina, crouch,
## slide, lean, head bob, recoil, armor/health, surface-aware footsteps.

signal died
signal health_changed(current: float, maximum: float)
signal armor_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
signal damaged(direction: Vector3, amount: float)
signal stepped(surface: String)
signal landed
signal adses_changed(active: bool)

const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.2
const EYE_STAND := 1.62
const EYE_CROUCH := 1.05
const WALK_SPEED := 4.4
const SPRINT_SPEED := 7.1
const CROUCH_SPEED := 2.2
const ADS_SPEED := 2.7
const ACCEL := 30.0
const DECEL := 36.0
const AIR_ACCEL := 8.0
const JUMP_SPEED := 5.5
const GRAVITY := 18.0

var camera: Camera3D
var head: Node3D
var weapon_system: WeaponSystem
var flashlight: SpotLight3D
var capsule: CapsuleShape3D
var collision_shape: CollisionShape3D

var max_health := 100.0
var health := 100.0
var max_armor := 100.0
var armor := 100.0
var max_stamina := 100.0
var stamina := 100.0

var is_dead := false
var is_crouching := false
var is_sprinting := false
var is_sliding := false
var ads_progress := 0.0
var lean := 0.0
var yaw := 0.0
var pitch := 0.0
var recoil_pitch := 0.0
var recoil_yaw := 0.0
var recoil_recovery := 8.0

var bob_phase := 0.0
var _bob_cycle := 0.0
var _step_distance := 0.0
var _step_stride := 2.0
var _crouch_amount := 0.0
var _slide_timer := 0.0
var _slide_cooldown := 0.0
var _since_damage := 99.0
var _shake := 0.0
var _land_dip := 0.0
var _was_on_floor := true
var _base_fov := 90.0
var _current_fov := 90.0
var _sensitivity := 1.0
var _ads_sensitivity := 0.65
var _flashlight_on := false
var _surface := "concrete"
var _last_position := Vector3.ZERO
## Automated tests run headless (no mouse capture) and set this to drive input.
var force_input_active := false


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_max_angle = deg_to_rad(50)
	floor_snap_length = 0.35
	_build_body()
	_apply_settings()
	Game.settings_changed.connect(_apply_settings)
	health_changed.emit(health, max_health)
	armor_changed.emit(armor, max_armor)
	stamina_changed.emit(stamina, max_stamina)
	_last_position = global_position


func _build_body() -> void:
	collision_shape = CollisionShape3D.new()
	capsule = CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = STAND_HEIGHT
	collision_shape.shape = capsule
	collision_shape.position.y = STAND_HEIGHT * 0.5
	add_child(collision_shape)

	head = Node3D.new()
	head.name = "Head"
	head.position.y = EYE_STAND
	add_child(head)

	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 90.0
	camera.near = 0.02
	camera.far = 600.0
	head.add_child(camera)
	camera.current = true

	weapon_system = WeaponSystem.new()
	weapon_system.name = "WeaponSystem"
	camera.add_child(weapon_system)

	flashlight = SpotLight3D.new()
	flashlight.name = "Flashlight"
	flashlight.light_color = Color(0.92, 0.96, 1.0)
	flashlight.light_energy = 3.4
	flashlight.spot_range = 30.0
	flashlight.spot_angle = 32.0
	flashlight.spot_attenuation = 1.2
	flashlight.shadow_enabled = true
	flashlight.visible = false
	camera.add_child(flashlight)
	flashlight.position = Vector3(0.12, -0.1, 0.0)


func setup(spawn: Transform3D, loadout: Dictionary) -> void:
	global_position = spawn.origin
	yaw = spawn.basis.get_euler().y
	pitch = 0.0
	rotation.y = yaw
	_last_position = global_position
	weapon_system.setup(self, camera, loadout)
	Game.capture_mouse(true)


func _apply_settings() -> void:
	_sensitivity = float(Game.settings["sensitivity"])
	_ads_sensitivity = float(Game.settings["ads_sensitivity"])
	_base_fov = float(Game.settings["fov"])
	_current_fov = _base_fov
	camera.fov = _base_fov
	camera.far = 200.0 + 600.0 * float(Game.settings["view_distance"])
	if weapon_system != null:
		weapon_system.ads_progress = 0.0


func add_recoil(vertical: float, horizontal: float, recovery: float) -> void:
	recoil_pitch += deg_to_rad(vertical)
	recoil_yaw += deg_to_rad(horizontal)
	recoil_pitch = clampf(recoil_pitch, -0.3, 0.5)
	recoil_yaw = clampf(recoil_yaw, -0.4, 0.4)
	recoil_recovery = maxf(1.0, recovery)


func set_ads_state(progress: float) -> void:
	var was := ads_progress > 0.5
	ads_progress = clampf(progress, 0.0, 1.0)
	if (ads_progress > 0.5) != was:
		adses_changed.emit(ads_progress > 0.5)


func get_aim_origin() -> Vector3:
	return camera.global_position


func get_aim_direction() -> Vector3:
	return -camera.global_transform.basis.z


func _unhandled_input(event: InputEvent) -> void:
	if is_dead or not is_inside_tree():
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		var sensitivity := _sensitivity * 0.0022
		var ads_mult: float = lerpf(1.0, _ads_sensitivity, ads_progress) / maxf(0.2, weapon_system.current_zoom())
		yaw -= event.relative.x * sensitivity * ads_mult
		pitch -= event.relative.y * sensitivity * ads_mult * (-1.0 if bool(Game.settings["invert_y"]) else 1.0)
		pitch = clampf(pitch, -1.45, 1.45)
		weapon_system.add_look_input(event.relative)


func _process(delta: float) -> void:
	if is_dead:
		_update_death(delta)
		return
	_update_camera(delta)
	_since_damage += delta
	if _since_damage > 7.0 and health < max_health:
		heal(7.0 * delta)
	_update_stamina(delta)
	_update_footsteps(delta)
	_update_interaction_state()


func _physics_process(delta: float) -> void:
	if is_dead:
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		move_and_slide()
		return
	var active := force_input_active or (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not get_tree().paused)
	_read_actions(active, delta)
	_apply_movement(active, delta)
	move_and_slide()
	_detect_landing()
	_update_crouch(delta)


func _read_actions(active: bool, delta: float) -> void:
	if not active:
		is_sprinting = false
		weapon_system.set_ads(false)
		weapon_system.trigger_up()
		return
	var sprint_pressed := Input.is_action_pressed("sprint")
	var crouch_pressed := Input.is_action_pressed("crouch")
	var forward := Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	var can_sprint := sprint_pressed and forward > 0.1 and not crouch_pressed and stamina > 5.0 and ads_progress < 0.2 and not is_sliding
	is_sprinting = can_sprint

	# Slide.
	if crouch_pressed and sprint_pressed and is_on_floor() and _slide_cooldown <= 0.0 and Vector2(velocity.x, velocity.z).length() > 4.2 and not is_sliding:
		is_sliding = true
		_slide_timer = 0.9
		_slide_cooldown = 1.4
		var dir := Vector3(velocity.x, 0, velocity.z).normalized()
		velocity.x = dir.x * maxf(8.4, Vector2(velocity.x, velocity.z).length() * 1.25)
		velocity.z = dir.z * maxf(8.4, Vector2(velocity.x, velocity.z).length() * 1.25)
		is_crouching = true
		Audio.play_3d("foot_%s_0" % _surface, global_position, -6.0, 0.85, 22.0)
	if _slide_cooldown > 0.0:
		_slide_cooldown -= delta
	if is_sliding:
		_slide_timer -= delta
		if _slide_timer <= 0.0 or not crouch_pressed:
			is_sliding = false

	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_sliding:
		velocity.y = JUMP_SPEED
		Audio.play_3d("foot_%s_0" % _surface, global_position, -10.0, 0.8, 18.0)
	is_crouching = crouch_pressed or is_sliding
	weapon_system.set_ads(Input.is_action_pressed("aim") and not is_sprinting and not is_sliding)
	if Input.is_action_pressed("fire"):
		weapon_system.trigger_down()
	else:
		weapon_system.trigger_up()
	if Input.is_action_just_pressed("reload"):
		weapon_system.start_reload()
	if Input.is_action_just_pressed("weapon_1"):
		weapon_system.switch_to(0)
	if Input.is_action_just_pressed("weapon_2"):
		weapon_system.switch_to(1)
	if Input.is_action_just_pressed("weapon_3"):
		weapon_system.switch_to(2)
	if Input.is_action_just_pressed("weapon_next"):
		weapon_system.next_weapon(1)
	if Input.is_action_just_pressed("weapon_prev"):
		weapon_system.next_weapon(-1)
	if Input.is_action_just_pressed("tactical_light"):
		_flashlight_on = not _flashlight_on
		flashlight.visible = _flashlight_on
		Audio.play_ui("ui_click", -12.0)
	# Lean.
	var lean_target := 0.0
	if Input.is_action_pressed("lean_left"):
		lean_target -= 1.0
	if Input.is_action_pressed("lean_right"):
		lean_target += 1.0
	lean = move_toward(lean, lean_target, 3.5 * delta)


func _apply_movement(active: bool, delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	if not active:
		var hv := Vector3(velocity.x, 0, velocity.z).move_toward(Vector3.ZERO, DECEL * delta)
		velocity.x = hv.x
		velocity.z = hv.z
		return
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := (transform.basis * Vector3(input_dir.x, 0, input_dir.y))
	if wish.length() > 1.0:
		wish = wish.normalized()
	var speed := WALK_SPEED
	if is_crouching:
		speed = CROUCH_SPEED
	elif is_sprinting:
		speed = SPRINT_SPEED
	if ads_progress > 0.35:
		speed = minf(speed, ADS_SPEED)
	if is_sliding:
		speed = 0.0
	var target := wish * speed
	var horizontal := Vector3(velocity.x, 0, velocity.z)
	var rate := ACCEL
	if is_sliding:
		rate = 6.0
	elif not is_on_floor():
		rate = AIR_ACCEL
	elif wish.length_squared() < 0.01:
		rate = DECEL
	horizontal = horizontal.move_toward(target, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if is_sliding:
		var slide_dir := Vector3(velocity.x, 0, velocity.z)
		velocity.x = move_toward(velocity.x, 0, 3.4 * delta)
		velocity.z = move_toward(velocity.z, 0, 3.4 * delta)
		if slide_dir.length() < 2.2:
			is_sliding = false


func _update_crouch(delta: float) -> void:
	var target := 1.0 if (is_crouching or is_sliding) else 0.0
	_crouch_amount = move_toward(_crouch_amount, target, delta * 6.0)
	var height: float = lerpf(STAND_HEIGHT, CROUCH_HEIGHT, _crouch_amount)
	capsule.height = height
	collision_shape.position.y = height * 0.5


func _update_camera(delta: float) -> void:
	# Recoil recovery.
	recoil_pitch = lerpf(recoil_pitch, 0.0, clampf(delta * recoil_recovery, 0.0, 1.0))
	recoil_yaw = lerpf(recoil_yaw, 0.0, clampf(delta * recoil_recovery, 0.0, 1.0))
	rotation.y = yaw + recoil_yaw
	var speed := Vector2(velocity.x, velocity.z).length()
	var bob_strength := float(Game.settings["headbob"]) * clampf(speed / WALK_SPEED, 0.0, 1.6)
	bob_phase += delta * (5.0 + speed * 1.4)
	_bob_cycle = sin(bob_phase)
	var bob_x := cos(bob_phase * 0.5) * 0.022 * bob_strength * (1.0 - ads_progress * 0.8)
	var bob_y := absf(_bob_cycle) * 0.035 * bob_strength * (1.0 - ads_progress * 0.85)
	var eye: float = lerpf(EYE_STAND, EYE_CROUCH, _crouch_amount)
	_land_dip = lerpf(_land_dip, 0.0, clampf(delta * 6.0, 0.0, 1.0))
	_shake = maxf(0.0, _shake - delta * 2.4)
	var shake_pitch := (randf() - 0.5) * _shake * 0.06
	var shake_yaw := (randf() - 0.5) * _shake * 0.06
	var eye_pos := Vector3(bob_x + lean * 0.18, eye + bob_y - _land_dip * 0.14, 0)
	head.position = head.position.lerp(eye_pos, clampf(delta * 18.0, 0.0, 1.0))
	head.rotation.x = pitch + recoil_pitch + shake_pitch
	head.rotation.z = lerp(head.rotation.z, -lean * 0.16 + (randf() - 0.5) * _shake * 0.03, clampf(delta * 12.0, 0.0, 1.0))
	# FOV.
	var zoom: float = maxf(1.0, weapon_system.current_zoom())
	var target_fov: float = lerpf(_base_fov, _base_fov / zoom, ads_progress)
	var sprint_fov: float = lerpf(target_fov, _base_fov + 4.0, 0.6 if is_sprinting and ads_progress < 0.05 else 0.0)
	_current_fov = lerpf(_current_fov, sprint_fov, clampf(delta * 10.0, 0.0, 1.0))
	camera.fov = _current_fov
	camera.rotation.z = lerp(camera.rotation.z, -lean * 0.02, clampf(delta * 10.0, 0.0, 1.0))


func _update_stamina(delta: float) -> void:
	var moving := Vector2(velocity.x, velocity.z).length() > 1.0
	if is_sprinting and moving:
		stamina = maxf(0.0, stamina - delta * 17.0)
	else:
		stamina = minf(max_stamina, stamina + delta * (14.0 if moving else 20.0))
	stamina_changed.emit(stamina, max_stamina)


func _update_footsteps(delta: float) -> void:
	if not is_on_floor() or is_sliding:
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed < 0.5:
		return
	_step_distance += speed * delta
	_step_stride = 1.5 if is_sprinting else (2.1 if not is_crouching else 2.6)
	if _step_distance >= _step_stride:
		_step_distance = 0.0
		_detect_surface()
		var loudness := 1.0
		if is_crouching:
			loudness = 0.35
		elif is_sprinting:
			loudness = 1.35
		Audio.footstep(_surface, global_position + Vector3(0, 0.05, 0), loudness)
		stepped.emit(_surface)
		var noise_radius := 7.0 if is_sprinting else (2.0 if is_crouching else 4.5)
		get_tree().call_group("enemies", "hear_noise", global_position, noise_radius, "player")


func _detect_surface() -> void:
	var space := get_world_3d().direct_space_state
	if space == null:
		return
	var from := global_position + Vector3(0, 0.3, 0)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 1.6, 1)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return
	var collider = hit.get("collider")
	if collider != null and collider.has_meta("surface"):
		_surface = String(collider.get_meta("surface"))


func _detect_landing() -> void:
	var on_floor_now := is_on_floor()
	if on_floor_now and not _was_on_floor and velocity.y <= 0.1:
		_land_dip = 1.0
		_shake = maxf(_shake, 0.4)
		_detect_surface()
		Audio.footstep(_surface, global_position, 1.3)
		landed.emit()
	_was_on_floor = on_floor_now


func _update_interaction_state() -> void:
	pass


func _update_death(delta: float) -> void:
	head.position = head.position.lerp(Vector3(0.2, 0.35, 0.0), clampf(delta * 2.4, 0.0, 1.0))
	head.rotation.x = lerp(head.rotation.x, 0.6, clampf(delta * 2.0, 0.0, 1.0))
	head.rotation.z = lerp(head.rotation.z, 1.2, clampf(delta * 1.6, 0.0, 1.0))


func take_damage(amount: float, source_position: Vector3) -> void:
	if is_dead or amount <= 0.0:
		return
	_since_damage = 0.0
	var absorbed := minf(armor, amount * 0.55)
	armor -= absorbed
	var to_health := amount - absorbed
	health = maxf(0.0, health - to_health)
	_shake = minf(1.4, _shake + 0.5 + amount * 0.005)
	armor_changed.emit(armor, max_armor)
	health_changed.emit(health, max_health)
	var direction := (source_position - global_position)
	damaged.emit(direction, amount)
	Audio.play_ui("damage", -4.0)
	if health <= 0.0:
		_die()


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector3.ZERO
	weapon_system.trigger_up()
	weapon_system.set_ads(false)
	Game.capture_mouse(false)
	Audio.play_ui("damage", 0.0)
	died.emit()


func heal(amount: float) -> void:
	if is_dead:
		return
	health = minf(max_health, health + amount)
	health_changed.emit(health, max_health)


func add_armor(amount: float) -> void:
	if is_dead:
		return
	armor = minf(max_armor, armor + amount)
	armor_changed.emit(armor, max_armor)


func revive_at(transform_in: Transform3D, health_value: float = 100.0, armor_value: float = 50.0) -> void:
	is_dead = false
	global_position = transform_in.origin
	health = health_value
	armor = armor_value
	stamina = max_stamina
	_since_damage = 99.0
	head.position = Vector3(0, EYE_STAND, 0)
	head.rotation = Vector3.ZERO
	_recoil_reset()
	health_changed.emit(health, max_health)
	armor_changed.emit(armor, max_armor)
	stamina_changed.emit(stamina, max_stamina)
	Game.capture_mouse(true)


func _recoil_reset() -> void:
	recoil_pitch = 0.0
	recoil_yaw = 0.0


func current_surface() -> String:
	return _surface


func get_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func is_moving() -> bool:
	return get_speed() > 0.4
