class_name WorldBuilder
extends Node3D
## Builds map geometry with collision, world-space UVs, cover points and a
## navigation grid. Everything gameplay needs (cover, paths, spawn offsets,
## objective markers) is produced here so maps contain no dead geometry.

const FLOOR_LAYER := 1

var bounds: Rect2 = Rect2(-60, -60, 120, 120)
var cell_size := 1.0
var nav := AStarGrid2D.new()
var cover_points: Array[Dictionary] = []
var obstacles: Array[Dictionary] = []
var lights: Array[Light3D] = []
var _nav_ready := false
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 773311


# ------------------------------------------------------------------ meshes ---

static func box_mesh(size: Vector3, tiles_per_meter: float = 1.0) -> ArrayMesh:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Each face: four corners + normal + uv scaled by real size.
	_add_face(st, Vector3(-hx, -hy, hz), Vector3(hx, -hy, hz), Vector3(hx, hy, hz), Vector3(-hx, hy, hz), Vector3(0, 0, 1), Vector2(size.x, size.y) * tiles_per_meter)
	_add_face(st, Vector3(hx, -hy, -hz), Vector3(-hx, -hy, -hz), Vector3(-hx, hy, -hz), Vector3(hx, hy, -hz), Vector3(0, 0, -1), Vector2(size.x, size.y) * tiles_per_meter)
	_add_face(st, Vector3(hx, -hy, hz), Vector3(hx, -hy, -hz), Vector3(hx, hy, -hz), Vector3(hx, hy, hz), Vector3(1, 0, 0), Vector2(size.z, size.y) * tiles_per_meter)
	_add_face(st, Vector3(-hx, -hy, -hz), Vector3(-hx, -hy, hz), Vector3(-hx, hy, hz), Vector3(-hx, hy, -hz), Vector3(-1, 0, 0), Vector2(size.z, size.y) * tiles_per_meter)
	_add_face(st, Vector3(-hx, hy, hz), Vector3(hx, hy, hz), Vector3(hx, hy, -hz), Vector3(-hx, hy, -hz), Vector3(0, 1, 0), Vector2(size.x, size.z) * tiles_per_meter)
	_add_face(st, Vector3(-hx, -hy, -hz), Vector3(hx, -hy, -hz), Vector3(hx, -hy, hz), Vector3(-hx, -hy, hz), Vector3(0, -1, 0), Vector2(size.x, size.z) * tiles_per_meter)
	st.generate_tangents()
	return st.commit()


static func _add_face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, uv_size: Vector2) -> void:
	var u := uv_size
	st.set_normal(normal)
	st.set_uv(Vector2(0, u.y))
	st.add_vertex(a)
	st.set_uv(Vector2(u.x, u.y))
	st.add_vertex(b)
	st.set_uv(Vector2(u.x, 0))
	st.add_vertex(c)
	st.set_uv(Vector2(0, u.y))
	st.add_vertex(a)
	st.set_uv(Vector2(u.x, 0))
	st.add_vertex(c)
	st.set_uv(Vector2(0, 0))
	st.add_vertex(d)


func add_box(pos: Vector3, size: Vector3, material_id: String, opts: Dictionary = {}) -> Node3D:
	var mat := Materials.get_material(material_id)
	var mesh := box_mesh(size, float(opts.get("uv_scale", 0.5)))
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.name = String(opts.get("name", "Box"))
	var holder := Node3D.new()
	holder.name = mi.name
	holder.position = pos
	if opts.has("rotation"):
		holder.rotation_degrees = opts["rotation"]
	holder.add_child(mi)
	add_child(holder)
	var surface := String(opts.get("surface", Materials.surface_for_material(material_id)))
	mi.set_meta("surface", surface)
	if bool(opts.get("collide", true)):
		var body := StaticBody3D.new()
		body.collision_layer = FLOOR_LAYER
		body.collision_mask = 0
		body.set_meta("surface", surface)
		body.set_meta("map_geometry", true)
		body.name = "Body"
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		holder.add_child(body)
		_register_obstacle(holder, size, material_id, opts)
	return holder


func add_visual_box(pos: Vector3, size: Vector3, material_id: String, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = box_mesh(size)
	mi.material_override = Materials.get_material(material_id)
	mi.position = pos
	mi.rotation_degrees = rotation
	add_child(mi)
	return mi


func add_cylinder(pos: Vector3, radius: float, height: float, material_id: String, opts: Dictionary = {}) -> Node3D:
	var holder := Node3D.new()
	holder.position = pos
	holder.name = String(opts.get("name", "Cylinder"))
	add_child(holder)
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = int(opts.get("segments", 16))
	mesh.rings = 2
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Materials.get_material(material_id)
	if opts.has("rotation"):
		mi.rotation_degrees = opts["rotation"]
	holder.add_child(mi)
	var surface := String(opts.get("surface", Materials.surface_for_material(material_id)))
	mi.set_meta("surface", surface)
	if bool(opts.get("collide", false)):
		var body := StaticBody3D.new()
		body.collision_layer = FLOOR_LAYER
		body.collision_mask = 0
		body.set_meta("surface", surface)
		body.set_meta("map_geometry", true)
		var shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = radius
		cyl.height = height
		shape.shape = cyl
		body.add_child(shape)
		holder.add_child(body)
	return holder


func add_omni(pos: Vector3, color: Color, energy: float, range_m: float, shadow: bool = false) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_m
	light.shadow_enabled = shadow
	light.light_specular = 0.6
	add_child(light)
	lights.append(light)
	return light


func add_spot(pos: Vector3, color: Color, energy: float, range_m: float, angle: float, direction: Vector3) -> SpotLight3D:
	var light := SpotLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.spot_range = range_m
	light.spot_angle = angle
	light.shadow_enabled = true
	light.look_at_from_position(pos, pos + direction, Vector3.UP)
	add_child(light)
	lights.append(light)
	return light


func lighting_quality() -> String:
	return String(Game.settings["shadow_quality"])


# ------------------------------------------------------------------ props ---

func add_wall(pos: Vector3, size: Vector3, material_id: String = "concrete_wall") -> Node3D:
	return add_box(pos, size, material_id, {"name": "Wall", "uv_scale": 0.35})


func add_wall_with_openings(pos: Vector3, size: Vector3, material_id: String, openings: Array, axis: String = "x") -> void:
	## openings: array of {center: float, width: float, bottom: float, top: float}
	var sorted := openings.duplicate()
	sorted.sort_custom(func(a, b): return float(a["center"]) < float(b["center"]))
	var cursor := -size.x * 0.5 if axis == "x" else -size.z * 0.5
	var full := size.x if axis == "x" else size.z
	var y_center := pos.y
	for op in sorted:
		var left := float(op["center"]) - float(op["width"]) * 0.5
		var seg_w := left - cursor
		if seg_w > 0.05:
			_add_wall_segment(pos, size, material_id, axis, cursor + seg_w * 0.5, seg_w, y_center, size.y)
		var op_w := float(op["width"])
		var top: float = float(op.get("top", size.y * 0.5))
		var bottom: float = float(op.get("bottom", -size.y * 0.5))
		var lintel_h := size.y * 0.5 - top
		if lintel_h > 0.05:
			var cy := y_center + (top + size.y * 0.5) * 0.5
			_add_wall_segment(pos, size, material_id, axis, left + op_w * 0.5, op_w, cy, lintel_h)
		if bottom > -size.y * 0.5 + 0.05:
			var sill_h := bottom + size.y * 0.5
			var cy2 := y_center - size.y * 0.5 + sill_h * 0.5
			_add_wall_segment(pos, size, material_id, axis, left + op_w * 0.5, op_w, cy2, sill_h)
		cursor = left + op_w
	var remaining := full * 0.5 - cursor
	if remaining > 0.05:
		_add_wall_segment(pos, size, material_id, axis, cursor + remaining * 0.5, remaining, y_center, size.y)


func _add_wall_segment(pos: Vector3, size: Vector3, material_id: String, axis: String, offset: float, length: float, y_center: float, height: float) -> void:
	var seg_size := size
	var seg_pos := pos
	if axis == "x":
		seg_size.x = length
		seg_pos.x += offset
	else:
		seg_size.z = length
		seg_pos.z += offset
	seg_pos.y = y_center
	add_box(seg_pos, seg_size, material_id, {"name": "Wall", "uv_scale": 0.35})


func add_stairs(pos: Vector3, width: float, height: float, depth: float, steps: int, material_id: String = "concrete", facing: float = 0.0) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation_degrees.y = facing
	holder.name = "Stairs"
	add_child(holder)
	var step_h := height / float(steps)
	var step_d := depth / float(steps)
	for i in steps:
		var step_size := Vector3(width, step_h, step_d)
		var step_pos := Vector3(0, step_h * (i + 0.5), -depth * 0.5 + step_d * (i + 0.5))
		var mi := MeshInstance3D.new()
		mi.mesh = box_mesh(step_size)
		mi.material_override = Materials.get_material(material_id)
		mi.position = step_pos
		holder.add_child(mi)
		var body := StaticBody3D.new()
		body.collision_layer = FLOOR_LAYER
		body.set_meta("surface", Materials.surface_for_material(material_id))
		body.set_meta("map_geometry", true)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = step_size
		shape.shape = box
		body.add_child(shape)
		body.position = step_pos
		holder.add_child(body)
	# A single ramp collider on top so movement up the stairs is smooth.
	var ramp := StaticBody3D.new()
	ramp.collision_layer = FLOOR_LAYER
	ramp.set_meta("surface", Materials.surface_for_material(material_id))
	ramp.set_meta("map_geometry", true)
	ramp.name = "StairRamp"
	var ramp_shape := CollisionShape3D.new()
	var ramp_box := BoxShape3D.new()
	ramp_box.size = Vector3(width, 0.25, sqrt(depth * depth + height * height))
	ramp_shape.shape = ramp_box
	var angle := atan2(height, depth)
	ramp_shape.rotation.x = -angle
	ramp_shape.position = Vector3(0, height * 0.5, 0)
	ramp.add_child(ramp_shape)
	holder.add_child(ramp)


func add_crate(pos: Vector3, size: float = 1.2, color: String = "wood") -> Node3D:
	var mat := color
	if color == "wood":
		var crates := ["crate_red", "crate_blue", "crate_green", "wood_plank"]
		mat = crates[_rng.randi_range(0, crates.size() - 1)]
	var holder := add_box(pos + Vector3(0, size * 0.5, 0), Vector3(size, size, size), mat, {"name": "Crate", "uv_scale": 0.8})
	return holder


func add_crate_stack(pos: Vector3, size: float = 1.2, count: int = 3) -> void:
	for i in count:
		var offset := Vector3(_rng.randf_range(-0.15, 0.15), 0, _rng.randf_range(-0.15, 0.15))
		add_crate(pos + Vector3(0, float(i) * size, 0) + offset, size, "wood")


func add_barrel(pos: Vector3, color: String = "rust") -> void:
	var material := "rust"
	match color:
		"red":
			material = "crate_red"
		"blue":
			material = "crate_blue"
		"green":
			material = "crate_green"
	add_cylinder(pos + Vector3(0, 0.45, 0), 0.3, 0.9, material, {"name": "Barrel", "collide": true, "segments": 14})


func add_container(pos: Vector3, rotation_y: float = 0.0, color: int = 0, open: bool = false) -> Node3D:
	var mats := ["crate_red", "crate_blue", "crate_green", "rust"]
	var mat: String = mats[color % mats.size()]
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation_degrees.y = rotation_y
	holder.name = "Container"
	add_child(holder)
	var size := Vector3(12.0, 2.6, 2.5)
	var shell := MeshInstance3D.new()
	shell.mesh = box_mesh(size, 0.4)
	shell.material_override = Materials.get_material(mat)
	shell.position.y = 1.3
	holder.add_child(shell)
	var body := StaticBody3D.new()
	body.collision_layer = FLOOR_LAYER
	body.set_meta("surface", "metal")
	body.set_meta("map_geometry", true)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position.y = 1.3
	holder.add_child(body)
	# Corrugation ribs for readability.
	var rib_mesh := box_mesh(Vector3(size.x + 0.02, 0.06, size.z + 0.04))
	var rib_mat := Materials.get_material("metal_panel")
	for i in range(-5, 6):
		for y in [0.35, 2.3]:
			var rib := MeshInstance3D.new()
			rib.mesh = rib_mesh
			rib.material_override = rib_mat
			rib.position = Vector3(float(i) * 1.05, y, 0)
			holder.add_child(rib)
	if open:
		var door := MeshInstance3D.new()
		door.mesh = box_mesh(Vector3(2.2, 2.2, 0.08))
		door.material_override = rib_mat
		door.position = Vector3(-4.6, 1.25, size.z * 0.5 + 0.05)
		door.rotation.z = deg_to_rad(8)
		holder.add_child(door)
	_register_obstacle(holder, size, mat, {"cover": true})
	return holder


func add_jersey_barrier(pos: Vector3, rotation_y: float = 0.0) -> Node3D:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation_degrees.y = rotation_y
	holder.name = "Barrier"
	add_child(holder)
	var base := MeshInstance3D.new()
	base.mesh = box_mesh(Vector3(2.4, 0.5, 0.8))
	base.material_override = Materials.get_material("concrete")
	base.position.y = 0.25
	holder.add_child(base)
	var top := MeshInstance3D.new()
	top.mesh = box_mesh(Vector3(2.4, 0.5, 0.4))
	top.material_override = Materials.get_material("concrete")
	top.position.y = 0.75
	holder.add_child(top)
	var body := StaticBody3D.new()
	body.collision_layer = FLOOR_LAYER
	body.set_meta("surface", "concrete")
	body.set_meta("map_geometry", true)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.4, 1.0, 0.8)
	shape.shape = box
	body.add_child(shape)
	body.position.y = 0.5
	holder.add_child(body)
	_register_obstacle(holder, Vector3(2.4, 1.0, 0.8), "concrete", {"cover": true})
	return holder


func add_sandbag_wall(pos: Vector3, length: float, rotation_y: float = 0.0, height: float = 1.1) -> Node3D:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation_degrees.y = rotation_y
	holder.name = "Sandbags"
	add_child(holder)
	var bag_w := 0.62
	var rows := int(ceil(height / 0.25))
	var count := int(length / bag_w)
	for row in rows:
		for i in count:
			var mi := MeshInstance3D.new()
			var bag := SphereMesh.new()
			bag.radius = 0.34
			bag.height = 0.34
			bag.radial_segments = 8
			bag.rings = 4
			mi.mesh = bag
			mi.material_override = Materials.get_material("sandbag")
			mi.position = Vector3(-length * 0.5 + bag_w * (i + 0.5) + (0.2 if row % 2 == 1 else 0.0), 0.17 + row * 0.22, 0)
			mi.scale = Vector3(0.95, 0.6, 0.8)
			holder.add_child(mi)
	var body := StaticBody3D.new()
	body.collision_layer = FLOOR_LAYER
	body.set_meta("surface", "sandbag")
	body.set_meta("map_geometry", true)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(length, height, 0.7)
	shape.shape = box
	body.add_child(shape)
	body.position.y = height * 0.5
	holder.add_child(body)
	_register_obstacle(holder, Vector3(length, height, 0.7), "sandbag", {"cover": true})
	return holder


func add_fence(pos: Vector3, length: float, rotation_y: float = 0.0, height: float = 3.0) -> Node3D:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation_degrees.y = rotation_y
	holder.name = "Fence"
	add_child(holder)
	var panels := int(ceil(length / 3.0))
	for i in panels:
		var panel := MeshInstance3D.new()
		panel.mesh = box_mesh(Vector3(3.0, height, 0.06))
		panel.material_override = Materials.get_material("metal_panel")
		panel.position = Vector3(-length * 0.5 + 3.0 * (i + 0.5), height * 0.5, 0)
		holder.add_child(panel)
		var post := MeshInstance3D.new()
		post.mesh = box_mesh(Vector3(0.1, height + 0.2, 0.1))
		post.material_override = Materials.get_material("metal_panel")
		post.position = Vector3(-length * 0.5 + 3.0 * i, (height + 0.2) * 0.5, 0)
		holder.add_child(post)
	var body := StaticBody3D.new()
	body.collision_layer = FLOOR_LAYER
	body.set_meta("surface", "metal")
	body.set_meta("map_geometry", true)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(length, height, 0.15)
	shape.shape = box
	body.add_child(shape)
	body.position.y = height * 0.5
	holder.add_child(body)
	_register_obstacle(holder, Vector3(length, height, 0.15), "metal", {"cover": true})
	return holder


func add_railing(pos: Vector3, length: float, rotation_y: float = 0.0, height: float = 1.05) -> Node3D:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation_degrees.y = rotation_y
	holder.name = "Railing"
	add_child(holder)
	var top := MeshInstance3D.new()
	top.mesh = box_mesh(Vector3(length, 0.06, 0.06))
	top.material_override = Materials.get_material("metal_panel")
	top.position.y = height
	holder.add_child(top)
	var count := int(length / 1.5)
	for i in count + 1:
		var post := MeshInstance3D.new()
		post.mesh = box_mesh(Vector3(0.06, height, 0.06))
		post.material_override = Materials.get_material("metal_panel")
		post.position = Vector3(-length * 0.5 + float(i) * (length / float(maxi(1, count))), height * 0.5, 0)
		holder.add_child(post)
	var body := StaticBody3D.new()
	body.collision_layer = FLOOR_LAYER
	body.set_meta("surface", "metal")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(length, height, 0.12)
	shape.shape = box
	body.add_child(shape)
	body.position.y = height * 0.5
	holder.add_child(body)
	return holder


func add_pipe_run(start: Vector3, end: Vector3, radius: float, material_id: String = "rust") -> void:
	var dir := end - start
	var length := dir.length()
	if length < 0.01:
		return
	var holder := add_cylinder(start + dir * 0.5, radius, length, material_id, {"collide": false, "segments": 10, "name": "Pipe"})
	var mesh_node := holder.get_child(0) as MeshInstance3D
	if mesh_node != null:
		mesh_node.look_at_from_position(start, end, Vector3.UP)
		mesh_node.rotate_object_local(Vector3.RIGHT, PI * 0.5)


func add_floodlight(pos: Vector3, rotation_y: float = 0.0) -> void:
	var pole := add_cylinder(pos + Vector3(0, 4.0, 0), 0.09, 8.0, "metal_panel", {"collide": true, "segments": 8, "name": "LightPole"})
	var head := add_visual_box(pos + Vector3(0, 8.0, 0), Vector3(0.9, 0.35, 0.45), "lamp")
	head.rotation_degrees.y = rotation_y
	add_omni(pos + Vector3(0, 7.7, 0), Color(1.0, 0.9, 0.72), 3.2, 22.0, true)
	var housing := add_visual_box(pos + Vector3(0, 8.25, 0), Vector3(1.0, 0.15, 0.55), "metal_panel")
	housing.rotation_degrees.y = rotation_y
	pole.name = "Floodlight"


func add_streetlight(pos: Vector3, rotation_y: float = 0.0) -> void:
	add_cylinder(pos + Vector3(0, 3.6, 0), 0.08, 7.2, "metal_panel", {"collide": true, "segments": 8, "name": "Streetlight"})
	var arm := add_visual_box(pos + Vector3(cos(deg_to_rad(rotation_y)) * 1.1, 7.1, sin(deg_to_rad(rotation_y)) * 1.1), Vector3(2.2, 0.09, 0.09), "metal_panel")
	arm.rotation_degrees.y = rotation_y
	var lamp := add_visual_box(pos + Vector3(cos(deg_to_rad(rotation_y)) * 2.1, 6.95, sin(deg_to_rad(rotation_y)) * 2.1), Vector3(0.7, 0.16, 0.35), "lamp")
	lamp.rotation_degrees.y = rotation_y
	add_omni(pos + Vector3(cos(deg_to_rad(rotation_y)) * 2.1, 6.7, sin(deg_to_rad(rotation_y)) * 2.1), Color(1.0, 0.86, 0.62), 4.0, 16.0, true)


func add_truck(pos: Vector3, rotation_y: float = 0.0, color: String = "crate_green") -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation_degrees.y = rotation_y
	holder.name = "Truck"
	add_child(holder)
	_add_part(holder, Vector3(0, 1.0, 0), Vector3(6.5, 1.4, 2.4), color)
	_add_part(holder, Vector3(4.6, 1.1, 0), Vector3(1.9, 1.5, 2.3), color)
	_add_part(holder, Vector3(4.9, 1.85, 0), Vector3(1.3, 0.9, 2.1), "glass", false)
	_add_part(holder, Vector3(0, 2.3, 0), Vector3(6.2, 2.2, 2.5), "fabric")
	for sx in [-2.2, 2.0, 4.4]:
		for sz in [-1.15, 1.15]:
			_add_wheel(holder, Vector3(sx, 0.55, sz), 0.55, 0.35)
	var body := StaticBody3D.new()
	body.collision_layer = FLOOR_LAYER
	body.set_meta("surface", "metal")
	body.set_meta("map_geometry", true)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(7.0, 2.4, 2.6)
	shape.shape = box
	body.add_child(shape)
	body.position.y = 1.2
	holder.add_child(body)
	_register_obstacle(holder, Vector3(7.0, 2.4, 2.6), color, {"cover": true})


func add_car(pos: Vector3, rotation_y: float = 0.0, color: String = "crate_blue") -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation_degrees.y = rotation_y
	holder.name = "Car"
	add_child(holder)
	_add_part(holder, Vector3(0, 0.55, 0), Vector3(4.3, 0.6, 1.85), color)
	_add_part(holder, Vector3(-0.15, 1.05, 0), Vector3(2.2, 0.55, 1.7), color)
	_add_part(holder, Vector3(-0.15, 1.08, 0), Vector3(2.0, 0.42, 1.72), "glass", false)
	for sx in [-1.45, 1.45]:
		for sz in [-0.9, 0.9]:
			_add_wheel(holder, Vector3(sx, 0.32, sz), 0.32, 0.22)
	var body := StaticBody3D.new()
	body.collision_layer = FLOOR_LAYER
	body.set_meta("surface", "metal")
	body.set_meta("map_geometry", true)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.3, 1.4, 1.9)
	shape.shape = box
	body.add_child(shape)
	body.position.y = 0.7
	holder.add_child(body)
	_register_obstacle(holder, Vector3(4.3, 1.4, 1.9), color, {"cover": true})


func _add_wheel(holder: Node3D, pos: Vector3, radius: float, width: float) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = width
	cyl.radial_segments = 12
	mi.mesh = cyl
	mi.material_override = Materials.get_material("rubber")
	mi.position = pos
	mi.rotation_degrees.z = 90.0
	holder.add_child(mi)


func _add_part(holder: Node3D, pos: Vector3, size: Vector3, material_id: String, collide: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = box_mesh(size)
	mi.material_override = Materials.get_material(material_id)
	mi.position = pos
	holder.add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		body.collision_layer = FLOOR_LAYER
		body.set_meta("surface", "metal")
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		body.position = pos
		holder.add_child(body)
	return mi


func add_tree(pos: Vector3, scale_factor: float = 1.0) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.name = "Tree"
	holder.rotation_degrees.y = _rng.randf_range(0, 360)
	add_child(holder)
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.18 * scale_factor
	trunk_mesh.bottom_radius = 0.3 * scale_factor
	trunk_mesh.height = 4.6 * scale_factor
	trunk_mesh.radial_segments = 8
	trunk.mesh = trunk_mesh
	trunk.material_override = Materials.get_material("wood")
	trunk.position.y = 2.3 * scale_factor
	holder.add_child(trunk)
	for i in 4:
		var foliage := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		var r := (2.3 - i * 0.42) * scale_factor
		cone.top_radius = 0.15 * scale_factor
		cone.bottom_radius = r
		cone.height = 2.4 * scale_factor
		cone.radial_segments = 9
		foliage.mesh = cone
		foliage.material_override = Materials.get_material("foliage")
		foliage.position.y = (3.2 + i * 1.15) * scale_factor
		holder.add_child(foliage)
	var body := StaticBody3D.new()
	body.collision_layer = FLOOR_LAYER
	body.set_meta("surface", "wood")
	body.set_meta("map_geometry", true)
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.35 * scale_factor
	cyl.height = 4.6 * scale_factor
	shape.shape = cyl
	body.add_child(shape)
	body.position.y = 2.3 * scale_factor
	holder.add_child(body)
	_register_obstacle(holder, Vector3(0.7, 4.0, 0.7) * scale_factor, "wood", {"cover": true})


func add_rock(pos: Vector3, scale_factor: float = 1.0) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.name = "Rock"
	add_child(holder)
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 1.6
	sphere.radial_segments = 8
	sphere.rings = 5
	mi.mesh = sphere
	mi.material_override = Materials.get_material("concrete")
	mi.scale = Vector3(1.4, 0.8, 1.1) * scale_factor
	mi.rotation_degrees.y = _rng.randf_range(0, 360)
	holder.add_child(mi)
	var body := StaticBody3D.new()
	body.collision_layer = FLOOR_LAYER
	body.set_meta("surface", "concrete")
	body.set_meta("map_geometry", true)
	var shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 1.0 * scale_factor
	shape.shape = sphere_shape
	body.add_child(shape)
	body.position.y = 0.35 * scale_factor
	holder.add_child(body)
	_register_obstacle(holder, Vector3(2.4, 1.3, 1.9) * scale_factor, "concrete", {"cover": true})


func add_ladder(pos: Vector3, height: float, rotation_y: float = 0.0) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation_degrees.y = rotation_y
	holder.name = "Ladder"
	add_child(holder)
	for sx in [-0.25, 0.25]:
		var rail := MeshInstance3D.new()
		rail.mesh = box_mesh(Vector3(0.08, height, 0.08))
		rail.material_override = Materials.get_material("metal_panel")
		rail.position = Vector3(sx, height * 0.5, 0)
		holder.add_child(rail)
	var rungs := int(height / 0.35)
	for i in rungs:
		var rung := MeshInstance3D.new()
		rung.mesh = box_mesh(Vector3(0.55, 0.05, 0.05))
		rung.material_override = Materials.get_material("metal_panel")
		rung.position = Vector3(0, 0.3 + i * 0.35, 0)
		holder.add_child(rung)


func add_workbench(pos: Vector3, rotation_y: float = 0.0) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation_degrees.y = rotation_y
	holder.name = "Workbench"
	add_child(holder)
	_add_part(holder, Vector3(0, 0.9, 0), Vector3(2.4, 0.1, 0.9), "wood_plank")
	for sx in [-1.05, 1.05]:
		_add_part(holder, Vector3(sx, 0.45, 0), Vector3(0.1, 0.9, 0.8), "metal_panel")
	_add_part(holder, Vector3(0.5, 1.05, 0), Vector3(0.5, 0.3, 0.35), "metal_panel")
	_register_obstacle(holder, Vector3(2.4, 1.0, 0.9), "wood", {"cover": true})


func add_office(pos: Vector3, size: Vector3, door_side: String = "south") -> Node3D:
	## Small interior room whose front wall is glass panes flanking an open doorway.
	var holder := Node3D.new()
	holder.position = pos
	holder.name = "Office"
	add_child(holder)
	var t := 0.25
	var half_y := size.y * 0.5
	var back_z := pos.z - size.z * 0.5
	add_box(Vector3(pos.x, half_y, back_z), Vector3(size.x, size.y, t), "concrete_wall", {"name": "OfficeWall", "uv_scale": 0.35})
	add_box(Vector3(pos.x - size.x * 0.5, half_y, pos.z), Vector3(t, size.y, size.z), "concrete_wall", {"name": "OfficeWall", "uv_scale": 0.35})
	add_box(Vector3(pos.x + size.x * 0.5, half_y, pos.z), Vector3(t, size.y, size.z), "concrete_wall", {"name": "OfficeWall", "uv_scale": 0.35})
	var front_z := pos.z + size.z * 0.5
	var door_w := 1.5
	var pane_w := (size.x - door_w) * 0.5
	for sign_x in [-1.0, 1.0]:
		var px: float = pos.x + sign_x * (door_w * 0.5 + pane_w * 0.5)
		var pane := add_visual_box(Vector3(px, half_y + 0.1, front_z), Vector3(pane_w, size.y * 0.86, 0.06), "glass")
		pane.name = "OfficeGlass"
		var gbody := StaticBody3D.new()
		gbody.collision_layer = FLOOR_LAYER
		gbody.set_meta("surface", "glass")
		gbody.set_meta("map_geometry", true)
		var gshape := CollisionShape3D.new()
		var gbox := BoxShape3D.new()
		gbox.size = Vector3(pane_w, size.y * 0.86, 0.1)
		gshape.shape = gbox
		gbody.add_child(gshape)
		gbody.position = Vector3(px, half_y + 0.1, front_z)
		add_child(gbody)
		# Frame above the panes and above the doorway.
		add_visual_box(Vector3(px, size.y * 0.97, front_z), Vector3(pane_w, 0.16, 0.12), "metal_panel")
	add_visual_box(Vector3(pos.x, size.y * 0.97, front_z), Vector3(door_w, 0.16, 0.12), "metal_panel")
	# Desk + monitor + chair (world-space, so nothing needs re-parenting).
	var desk := add_box(Vector3(pos.x - size.x * 0.2, 0.75, pos.z - size.z * 0.2), Vector3(1.8, 0.08, 0.8), "wood_plank", {"name": "Desk", "uv_scale": 0.8})
	desk.name = "Desk"
	_add_part(holder, Vector3(-size.x * 0.2, 1.05, -size.z * 0.2), Vector3(0.6, 0.4, 0.08), "screen")
	_add_part(holder, Vector3(-size.x * 0.2, 0.45, -size.z * 0.38), Vector3(0.5, 0.5, 0.5), "rubber")
	return holder


func add_tent(pos: Vector3, rotation_y: float = 0.0) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation_degrees.y = rotation_y
	holder.name = "Tent"
	add_child(holder)
	_add_part(holder, Vector3(0, 1.2, 0), Vector3(4.4, 2.4, 3.4), "fabric")
	_add_part(holder, Vector3(0, 2.45, 0), Vector3(4.8, 0.1, 3.8), "fabric")
	var body := StaticBody3D.new()
	body.collision_layer = FLOOR_LAYER
	body.set_meta("surface", "fabric")
	body.set_meta("map_geometry", true)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.4, 2.4, 3.4)
	shape.shape = box
	body.add_child(shape)
	body.position.y = 1.2
	holder.add_child(body)
	_register_obstacle(holder, Vector3(4.4, 2.4, 3.4), "fabric", {})


func add_dumpster(pos: Vector3, rotation_y: float = 0.0) -> void:
	add_box(pos + Vector3(0, 0.65, 0), Vector3(2.0, 1.3, 1.2), "crate_green", {"name": "Dumpster", "rotation": Vector3(0, rotation_y, 0), "uv_scale": 0.6})


func add_pallet_rack(pos: Vector3, rotation_y: float = 0.0, bays: int = 3) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation_degrees.y = rotation_y
	holder.name = "PalletRack"
	add_child(holder)
	var width := 3.2 * bays
	for i in bays + 1:
		var x := -width * 0.5 + 3.2 * i
		for z in [-0.55, 0.55]:
			_add_part(holder, Vector3(x, 2.2, z), Vector3(0.09, 4.4, 0.09), "metal_panel")
	for level in 3:
		var y := 0.8 + level * 1.5
		_add_part(holder, Vector3(0, y, -0.55), Vector3(width, 0.08, 0.06), "metal_panel")
		_add_part(holder, Vector3(0, y, 0.55), Vector3(width, 0.08, 0.06), "metal_panel")
		for i in bays:
			var cx := -width * 0.5 + 1.6 + 3.2 * i
			_add_part(holder, Vector3(cx, y + 0.45, 0), Vector3(2.6, 0.85, 1.0), "wood_plank")
	var body := StaticBody3D.new()
	body.collision_layer = FLOOR_LAYER
	body.set_meta("surface", "metal")
	body.set_meta("map_geometry", true)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, 4.4, 1.3)
	shape.shape = box
	body.add_child(shape)
	body.position.y = 2.2
	holder.add_child(body)
	_register_obstacle(holder, Vector3(width, 4.4, 1.3), "metal", {})


func add_generator(pos: Vector3) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.name = "Generator"
	add_child(holder)
	_add_part(holder, Vector3(0, 0.8, 0), Vector3(2.6, 1.6, 1.4), "metal_panel")
	_add_part(holder, Vector3(0, 1.75, 0), Vector3(2.2, 0.2, 1.2), "rust")
	_add_part(holder, Vector3(1.4, 1.0, 0), Vector3(0.4, 0.4, 0.4), "crate_red")
	var body := StaticBody3D.new()
	body.collision_layer = FLOOR_LAYER
	body.set_meta("surface", "metal")
	body.set_meta("map_geometry", true)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.8, 1.9, 1.5)
	shape.shape = box
	body.add_child(shape)
	body.position.y = 0.95
	holder.add_child(body)
	add_omni(pos + Vector3(0, 1.6, 0), Color(1.0, 0.55, 0.3), 0.8, 5.0)
	_register_obstacle(holder, Vector3(2.8, 1.9, 1.5), "metal", {"cover": true})


func add_watchtower(pos: Vector3, height: float = 6.0) -> void:
	for sx in [-1.4, 1.4]:
		for sz in [-1.4, 1.4]:
			add_box(pos + Vector3(sx, height * 0.5, sz), Vector3(0.16, height, 0.16), "wood", {"name": "TowerLeg", "uv_scale": 1.0})
	add_box(pos + Vector3(0, height, 0), Vector3(3.6, 0.25, 3.6), "wood_plank", {"name": "TowerDeck", "uv_scale": 0.6, "cover": false})
	add_railing(pos + Vector3(0, height + 0.15, -1.75), 3.6, 0.0, 1.05)
	add_railing(pos + Vector3(1.75, height + 0.15, 0), 3.6, 90.0, 1.05)
	add_railing(pos + Vector3(-1.75, height + 0.15, 0), 3.6, 90.0, 1.05)
	add_box(pos + Vector3(0, height + 2.3, 0), Vector3(4.0, 0.12, 4.0), "rust", {"name": "TowerRoof", "collide": false})
	add_stairs(pos + Vector3(2.6, 0, 0), 1.2, height, 4.2, 12, "wood", 90.0)
	add_omni(pos + Vector3(0, height + 1.6, 0), Color(1.0, 0.82, 0.55), 1.6, 9.0, true)


func add_antenna(pos: Vector3, height: float = 12.0) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.name = "Antenna"
	add_child(holder)
	_add_part(holder, Vector3(0, height * 0.5, 0), Vector3(0.22, height, 0.22), "metal_panel")
	for i in 4:
		var y := height * (0.45 + i * 0.14)
		_add_part(holder, Vector3(0, y, 0), Vector3(1.4 - i * 0.25, 0.06, 0.06), "metal_panel")
		_add_part(holder, Vector3(0, y, 0), Vector3(0.06, 0.06, 1.4 - i * 0.25), "metal_panel")
	_add_part(holder, Vector3(0, height, 0), Vector3(0.12, 0.6, 0.12), "lamp")
	add_omni(pos + Vector3(0, height, 0), Color(1.0, 0.2, 0.15), 2.0, 12.0, false)


func add_bunker(pos: Vector3, rot: float = 0.0, name: String = "Bunker") -> Node3D:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation_degrees.y = rot
	holder.name = name
	add_child(holder)
	# Concrete shell with a front entrance and firing slit.
	_add_part(holder, Vector3(0, 1.6, -3.0), Vector3(8.0, 3.2, 0.5), "concrete_wall")
	_add_part(holder, Vector3(-3.8, 1.6, 0), Vector3(0.5, 3.2, 6.0), "concrete_wall")
	_add_part(holder, Vector3(3.8, 1.6, 0), Vector3(0.5, 3.2, 6.0), "concrete_wall")
	_add_part(holder, Vector3(-2.4, 1.6, 3.0), Vector3(3.0, 3.2, 0.5), "concrete_wall")
	_add_part(holder, Vector3(2.4, 1.6, 3.0), Vector3(3.0, 3.2, 0.5), "concrete_wall")
	_add_part(holder, Vector3(0, 3.3, 0), Vector3(8.2, 0.4, 6.4), "concrete")
	_add_part(holder, Vector3(0, 2.9, 3.05), Vector3(3.2, 0.5, 0.4), "concrete")
	_add_part(holder, Vector3(0, 1.4, 3.1), Vector3(1.6, 0.08, 0.1), "metal_panel")
	for i in 3:
		_add_part(holder, Vector3(-2.0 + i * 2.0, 2.2, -2.72), Vector3(0.9, 0.45, 0.06), "screen")
	# Collision for walls.
	for entry in [[Vector3(0, 1.6, -3.0), Vector3(8.0, 3.2, 0.5)], [Vector3(-3.8, 1.6, 0), Vector3(0.5, 3.2, 6.0)], [Vector3(3.8, 1.6, 0), Vector3(0.5, 3.2, 6.0)], [Vector3(-2.4, 1.6, 3.0), Vector3(3.0, 3.2, 0.5)], [Vector3(2.4, 1.6, 3.0), Vector3(3.0, 3.2, 0.5)], [Vector3(0, 3.3, 0), Vector3(8.2, 0.4, 6.4)]]:
		var body := StaticBody3D.new()
		body.collision_layer = FLOOR_LAYER
		body.set_meta("surface", "concrete")
		body.set_meta("map_geometry", true)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = entry[1]
		shape.shape = box
		body.add_child(shape)
		body.position = entry[0]
		holder.add_child(body)
	add_omni(pos + Vector3(0, 2.7, 0), Color(0.75, 0.85, 1.0), 1.4, 7.0, true)
	_register_obstacle(holder, Vector3(8.2, 3.5, 6.4), "concrete", {})
	return holder


func add_puddle(pos: Vector3, size: Vector2) -> void:
	var mi := MeshInstance3D.new()
	var quad := PlaneMesh.new()
	quad.size = size
	mi.mesh = quad
	mi.material_override = Materials.get_material("puddle")
	mi.position = pos + Vector3(0, 0.012, 0)
	add_child(mi)


func add_grass_patch(pos: Vector3, size: Vector2) -> void:
	var mi := MeshInstance3D.new()
	var quad := PlaneMesh.new()
	quad.size = size
	mi.mesh = quad
	mi.material_override = Materials.get_material("grass")
	mi.position = pos + Vector3(0, 0.02, 0)
	mi.rotation_degrees.x = -0.2
	add_child(mi)


func add_bush(pos: Vector3, scale_factor: float = 1.0) -> void:
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.9 * scale_factor
	sphere.height = 1.0 * scale_factor
	sphere.radial_segments = 7
	sphere.rings = 4
	mi.mesh = sphere
	mi.material_override = Materials.get_material("foliage")
	mi.position = pos + Vector3(0, 0.4 * scale_factor, 0)
	add_child(mi)


# ---------------------------------------------------------------- nav/cover ---

func _register_obstacle(holder: Node3D, size: Vector3, material_id: String, opts: Dictionary) -> void:
	var aabb := _world_aabb(holder, size)
	obstacles.append({
		"node": holder,
		"aabb": aabb,
		"height": size.y,
		"material": material_id,
	})
	if bool(opts.get("cover", size.y >= 0.9 and size.y <= 2.2 and maxf(size.x, size.z) >= 0.7)):
		_add_cover_from_aabb(aabb, holder.transform.basis)


func _world_aabb(holder: Node3D, size: Vector3) -> AABB:
	var t := holder.transform
	var half := size * 0.5
	var minp := Vector3(INF, INF, INF)
	var maxp := Vector3(-INF, -INF, -INF)
	for i in 8:
		var corner := Vector3(
			half.x if (i & 1) else -half.x,
			half.y if (i & 2) else -half.y,
			half.z if (i & 4) else -half.z
		)
		var world: Vector3 = t * corner
		minp = minp.min(world)
		maxp = maxp.max(world)
	return AABB(minp, maxp - minp)


func _add_cover_from_aabb(aabb: AABB, basis: Basis) -> void:
	var center := aabb.get_center()
	var ext := aabb.size * 0.5
	var sides := [
		{"dir": Vector3(0, 0, 1), "extent": ext.z, "lateral": ext.x},
		{"dir": Vector3(0, 0, -1), "extent": ext.z, "lateral": ext.x},
		{"dir": Vector3(1, 0, 0), "extent": ext.x, "lateral": ext.z},
		{"dir": Vector3(-1, 0, 0), "extent": ext.x, "lateral": ext.z},
	]
	for side in sides:
		var dir: Vector3 = side["dir"]
		var lateral: float = side["lateral"]
		if lateral < 0.35:
			continue
		var positions := [-lateral * 0.55, 0.0, lateral * 0.55]
		for lateral_offset in positions:
			var lateral_dir := Vector3(-dir.z, 0, dir.x)
			var pos: Vector3 = center + dir * (float(side["extent"]) + 0.75) + lateral_dir * float(lateral_offset)
			pos.y = 0.0
			cover_points.append({
				"position": pos,
				"normal": dir,
				"height": aabb.size.y,
				"quality": clampf(aabb.size.y / 1.6, 0.3, 1.0),
			})


func build_navigation(bounds_rect: Rect2, ground_y: float = 0.0) -> void:
	bounds = bounds_rect
	nav = AStarGrid2D.new()
	nav.region = Rect2i(0, 0, int(bounds_rect.size.x / cell_size), int(bounds_rect.size.y / cell_size))
	nav.cell_size = Vector2(cell_size, cell_size)
	nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	nav.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	nav.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	nav.update()
	# Carve blocked cells from each obstacle footprint. One pass over obstacles
	# instead of testing every cell against every obstacle keeps loads fast.
	for ob in obstacles:
		var aabb: AABB = ob["aabb"]
		if aabb.position.y + aabb.size.y <= ground_y + 0.35:
			continue
		if aabb.position.y > ground_y + 1.7:
			continue
		var min_cell := world_to_grid(Vector3(aabb.position.x, ground_y, aabb.position.z))
		var max_cell := world_to_grid(Vector3(aabb.position.x + aabb.size.x, ground_y, aabb.position.z + aabb.size.z))
		for gx in range(min_cell.x, max_cell.x + 1):
			for gz in range(min_cell.y, max_cell.y + 1):
				var cell := Vector2i(gx, gz)
				if not nav.region.has_point(cell):
					continue
				var center := grid_to_world(cell, ground_y)
				if center.x >= aabb.position.x - 0.02 and center.x <= aabb.position.x + aabb.size.x + 0.02 \
					and center.z >= aabb.position.z - 0.02 and center.z <= aabb.position.z + aabb.size.z + 0.02:
					nav.set_point_solid(cell, true)
	# Validate cover: only keep points the AI can actually stand on.
	var valid: Array[Dictionary] = []
	for cp in cover_points:
		var pos: Vector3 = cp["position"]
		if not bounds.has_point(Vector2(pos.x, pos.z)):
			continue
		if _point_blocked(pos):
			continue
		cp["grid"] = world_to_grid(pos)
		valid.append(cp)
	cover_points = valid
	_nav_ready = true


func _point_blocked(world: Vector3) -> bool:
	for ob in obstacles:
		var aabb: AABB = ob["aabb"]
		if world.y + 0.1 < aabb.position.y - 0.3:
			continue
		if aabb.position.y > world.y + 1.7:
			continue
		var shrunk := aabb.grow(-0.3)
		if shrunk.size.x <= 0.0 or shrunk.size.z <= 0.0:
			shrunk = aabb
		if world.x > shrunk.position.x and world.x < shrunk.position.x + shrunk.size.x \
			and world.z > shrunk.position.z and world.z < shrunk.position.z + shrunk.size.z:
			if aabb.position.y + aabb.size.y > world.y + 0.35:
				return true
	return false


func is_nav_ready() -> bool:
	return _nav_ready


func world_to_grid(world: Vector3) -> Vector2i:
	return Vector2i(
		int(floor((world.x - bounds.position.x) / cell_size)),
		int(floor((world.z - bounds.position.y) / cell_size))
	)


func grid_to_world(cell: Vector2i, ground_y: float = 0.0) -> Vector3:
	return Vector3(
		bounds.position.x + (float(cell.x) + 0.5) * cell_size,
		ground_y,
		bounds.position.y + (float(cell.y) + 0.5) * cell_size
	)


func is_walkable(world: Vector3) -> bool:
	if not _nav_ready:
		return not _point_blocked(world)
	var cell := world_to_grid(world)
	if not nav.region.has_point(cell):
		return false
	return not nav.is_point_solid(cell)


func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	if not _nav_ready:
		out.append(to)
		return out
	var a := world_to_grid(from)
	var b := world_to_grid(to)
	if not nav.region.has_point(a) or not nav.region.has_point(b):
		out.append(to)
		return out
	if nav.is_point_solid(a):
		a = _nearest_open(a)
	if nav.is_point_solid(b):
		b = _nearest_open(b)
	if nav.is_point_solid(a) or nav.is_point_solid(b):
		out.append(to)
		return out
	var id_path := nav.get_id_path(a, b)
	for id in id_path:
		out.append(grid_to_world(id, from.y))
	if out.is_empty():
		out.append(to)
	else:
		out[out.size() - 1] = Vector3(to.x, from.y, to.z)
	return _smooth_path(out)


func _nearest_open(cell: Vector2i) -> Vector2i:
	for radius in range(1, 6):
		for dx in range(-radius, radius + 1):
			for dz in range(-radius, radius + 1):
				var c := cell + Vector2i(dx, dz)
				if nav.region.has_point(c) and not nav.is_point_solid(c):
					return c
	return cell


func _smooth_path(path: PackedVector3Array) -> PackedVector3Array:
	if path.size() <= 2:
		return path
	var out := PackedVector3Array()
	out.append(path[0])
	var i := 0
	while i < path.size() - 1:
		var furthest := i + 1
		for j in range(path.size() - 1, i + 1, -1):
			if _clear_line(path[i], path[j]):
				furthest = j
				break
		out.append(path[furthest])
		i = furthest
	return out


func _clear_line(a: Vector3, b: Vector3) -> bool:
	var dist := a.distance_to(b)
	var steps := int(dist / 0.6)
	if steps < 1:
		return true
	for s in range(1, steps):
		var p := a.lerp(b, float(s) / float(steps))
		p.y = a.y
		if not is_walkable(p):
			return false
	return true


func find_cover_near(origin: Vector3, threat: Vector3, max_distance: float = 22.0) -> Dictionary:
	var best: Dictionary = {}
	var best_score := -INF
	for cp in cover_points:
		var pos: Vector3 = cp["position"]
		var d := origin.distance_to(pos)
		if d > max_distance or d < 0.8:
			continue
		var to_threat := (threat - pos).normalized()
		var protection := -Vector3(cp["normal"]).dot(to_threat)
		if protection < 0.1:
			continue
		var score := protection * 2.0 + float(cp["quality"]) - d * 0.06
		if score > best_score:
			best_score = score
			best = cp
	if best.is_empty():
		return {}
	var path := find_path(origin, best["position"])
	if path.is_empty():
		return {}
	return best


func cover_for_positions(origin: Vector3, threat: Vector3, max_distance: float = 20.0) -> Array:
	var scored: Array = []
	for cp in cover_points:
		var pos: Vector3 = cp["position"]
		var d := origin.distance_to(pos)
		if d > max_distance:
			continue
		var to_threat := (threat - pos).normalized()
		var protection := -Vector3(cp["normal"]).dot(to_threat)
		if protection < 0.15:
			continue
		scored.append({"cover": cp, "score": protection * 2.0 + float(cp["quality"]) - d * 0.05})
	scored.sort_custom(func(a, b): return float(a["score"]) > float(b["score"]))
	return scored


func register_patrol_route(points: Array) -> Array:
	var route: Array[Vector3] = []
	for p in points:
		if not is_walkable(p):
			# Snap to the closest walkable grid cell so authored routes never get stuck.
			var cell := _nearest_open(world_to_grid(p))
			p = grid_to_world(cell)
		route.append(p)
	return route
