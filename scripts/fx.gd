class_name Fx
extends Node3D
## Pooled visual effects: bullet impacts, decals, tracers, muzzle flash,
## blood and debris. Registered as a singleton for weapon/AI code.

static var active: Fx

const MAX_DECALS := 90

var _decals: Array[Node3D] = []
var _decal_textures: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	active = self
	_rng.seed = 424242


func _exit_tree() -> void:
	if active == self:
		active = null


static func get_active() -> Fx:
	return active if active != null and is_instance_valid(active) else null


func _particle_count(base: int) -> int:
	match String(Game.settings["effects_quality"]):
		"Low":
			return maxi(2, base / 3)
		"Medium":
			return maxi(3, base / 2)
		"Ultra":
			return base * 2
		_:
			return base


func _decal_texture(surface: String) -> Texture2D:
	if _decal_textures.has(surface):
		return _decal_textures[surface]
	var size := 96
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var base := Color(0.03, 0.03, 0.03, 0.9)
	var crack_rng := RandomNumberGenerator.new()
	crack_rng.seed = surface.hash()
	var cracks: Array[float] = []
	for i in 9:
		cracks.append(crack_rng.randf_range(0.0, TAU))
	match surface:
		"metal":
			base = Color(0.06, 0.06, 0.065, 0.92)
		"wood":
			base = Color(0.11, 0.07, 0.04, 0.92)
		"glass":
			base = Color(0.4, 0.45, 0.5, 0.55)
		"blood":
			base = Color(0.22, 0.02, 0.02, 0.85)
		"dirt":
			base = Color(0.13, 0.11, 0.08, 0.9)
	for x in size:
		for y in size:
			var dx := (float(x) - size * 0.5) / (size * 0.5)
			var dy := (float(y) - size * 0.5) / (size * 0.5)
			var r := sqrt(dx * dx + dy * dy)
			if r > 1.0:
				continue
			var alpha: float = clampf((1.0 - r) * 1.6, 0.0, 1.0)
			if r < 0.22:
				alpha = 1.0
			var c := base
			# Radial crack lines and a dusty rim read as a real impact instead
			# of a soft blob.
			var angle := atan2(dy, dx)
			var crack := 0.0
			for a in cracks:
				var delta := absf(wrapf(angle - a, -PI, PI))
				if delta < 0.09 and r > 0.28:
					crack = maxf(crack, (0.09 - delta) / 0.09 * (r - 0.28))
			if crack > 0.0:
				alpha = maxf(alpha * 0.5, crack * 0.9)
			if r > 0.42 and r < 0.56:
				c = c.lerp(Color(0.32, 0.3, 0.27, 1.0), 0.35)
				alpha = maxf(alpha, 0.22)
			c.a = base.a * alpha
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_decal_textures[surface] = tex
	return tex


func _add_decal(point: Vector3, normal: Vector3, surface: String, size_mult: float = 1.0) -> void:
	var decal := Decal.new()
	var up := normal.normalized()
	var right := up.cross(Vector3.UP)
	if right.length_squared() < 0.001:
		right = up.cross(Vector3.RIGHT)
	right = right.normalized()
	var forward := right.cross(up).normalized()
	decal.basis = Basis(right, up, forward)
	decal.position = point + up * 0.015
	decal.size = Vector3(0.16, 0.3, 0.16) * size_mult
	decal.texture_albedo = _decal_texture(surface)
	decal.upper_fade = 0.3
	decal.lower_fade = 0.3
	decal.distance_fade_enabled = true
	decal.distance_fade_begin = 35.0
	decal.distance_fade_length = 12.0
	decal.cull_mask = 1
	decal.modulate = Color(1, 1, 1, 0.95)
	var holder := Node3D.new()
	holder.add_child(decal)
	add_child(holder)
	_decals.append(holder)
	if _decals.size() > MAX_DECALS:
		var oldest: Node3D = _decals.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()


func _spark_burst(point: Vector3, normal: Vector3, surface: String) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = _particle_count(10)
	particles.lifetime = 0.45
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = true
	particles.local_coords = false
	particles.visibility_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))
	var pm := ParticleProcessMaterial.new()
	pm.direction = normal
	pm.spread = 55.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 5.5
	pm.gravity = Vector3(0, -9.0, 0)
	pm.scale_min = 0.4
	pm.scale_max = 1.1
	pm.color = Color(1.0, 0.72, 0.35)
	if surface == "concrete" or surface == "dirt":
		pm.color = Color(0.55, 0.52, 0.46)
		pm.initial_velocity_min = 0.6
		pm.initial_velocity_max = 2.2
		pm.spread = 30.0
	if surface == "flesh":
		pm.color = Color(0.35, 0.02, 0.02)
		pm.initial_velocity_min = 0.8
		pm.initial_velocity_max = 3.0
		pm.gravity = Vector3(0, -4.0, 0)
	particles.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.035, 0.035)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = pm.color
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.emission_enabled = surface == "metal"
	mat.emission = Color(1.0, 0.6, 0.2)
	mat.emission_energy_multiplier = 2.0
	quad.material = mat
	particles.draw_pass_1 = quad
	add_child(particles)
	particles.global_position = point
	get_tree().create_timer(1.4).timeout.connect(particles.queue_free)


func _dust_puff(point: Vector3, normal: Vector3) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = _particle_count(5)
	particles.lifetime = 1.1
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.emitting = true
	particles.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = normal
	pm.spread = 40.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 1.0
	pm.gravity = Vector3(0, 0.3, 0)
	pm.scale_min = 1.0
	pm.scale_max = 2.4
	pm.damping_min = 0.6
	pm.damping_max = 1.2
	particles.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.3, 0.3)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.55, 0.52, 0.47, 0.22)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material = mat
	particles.draw_pass_1 = quad
	add_child(particles)
	particles.global_position = point
	get_tree().create_timer(1.8).timeout.connect(particles.queue_free)


func impact(point: Vector3, normal: Vector3, surface: String) -> void:
	if not is_inside_tree():
		return
	Audio.impact(surface, point)
	var decal_surface := surface
	match surface:
		"flesh":
			decal_surface = "blood"
		"grass", "sandbag":
			decal_surface = "dirt"
		"glass":
			decal_surface = "glass"
	_add_decal(point, normal, decal_surface)
	_spark_burst(point, normal, surface)
	if surface == "concrete" or surface == "dirt" or surface == "wood":
		_dust_puff(point, normal)


func blood(point: Vector3, direction: Vector3) -> void:
	_spark_burst(point, direction, "flesh")


func tracer(from: Vector3, to: Vector3) -> void:
	var dist := from.distance_to(to)
	if dist < 0.5:
		return
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.012, 0.012, dist)
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.55, 0.75)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.3)
	mi.material_override = mat
	add_child(mi)
	mi.global_position = (from + to) * 0.5
	var dir := (to - from).normalized()
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
	mi.look_at(to, up)
	var tween := create_tween()
	tween.tween_property(mi, "scale", Vector3(0.2, 0.2, 1.0), 0.07)
	tween.tween_callback(mi.queue_free)


func muzzle_flash(position: Vector3) -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.82, 0.5)
	light.light_energy = 3.2
	light.omni_range = 6.0
	light.shadow_enabled = false
	add_child(light)
	light.global_position = position
	var tween := create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.07)
	tween.tween_callback(light.queue_free)


func shell_eject(position: Vector3, direction: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.006
	mesh.bottom_radius = 0.006
	mesh.height = 0.045
	mesh.radial_segments = 6
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.58, 0.28)
	mat.metallic = 0.9
	mat.roughness = 0.35
	mi.material_override = mat
	add_child(mi)
	mi.global_position = position
	mi.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	var target := position + direction * 0.7 + Vector3(0, -0.9, 0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(mi, "global_position", target, 0.4)
	tween.tween_property(mi, "rotation", mi.rotation + Vector3(6, 4, 3), 0.4)
	tween.chain().tween_callback(mi.queue_free)
	Audio.play_3d("shell_drop", position, -12.0, randf_range(0.95, 1.15), 14.0)


func explosion_light(position: Vector3, color: Color = Color(1.0, 0.55, 0.2), energy: float = 8.0, radius: float = 14.0) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.shadow_enabled = false
	add_child(light)
	light.global_position = position
	var tween := create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.5)
	tween.tween_callback(light.queue_free)
