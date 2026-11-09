class_name TrainingTarget
extends StaticBody3D
## Pop-up steel target for the shooting range.

signal hit(target: TrainingTarget, points: int)
signal expired(target: TrainingTarget)

var is_target := true
var lifetime := 3.6
var base_points := 100
var _mesh: Node3D
var _time := 0.0
var _dead := false


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	add_to_group("targets")
	set_meta("surface", "metal")
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.45
	shape.shape = sphere
	add_child(shape)
	_mesh = Node3D.new()
	add_child(_mesh)
	var outer := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.42
	cyl.bottom_radius = 0.42
	cyl.height = 0.06
	cyl.radial_segments = 24
	outer.mesh = cyl
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.8, 0.79, 0.72)
	white.metallic = 0.4
	white.roughness = 0.55
	outer.material_override = white
	outer.rotation_degrees.x = 90.0
	_mesh.add_child(outer)
	var inner := MeshInstance3D.new()
	var inner_cyl := CylinderMesh.new()
	inner_cyl.top_radius = 0.18
	inner_cyl.bottom_radius = 0.18
	inner_cyl.height = 0.07
	inner_cyl.radial_segments = 20
	inner.mesh = inner_cyl
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.65, 0.12, 0.09)
	red.roughness = 0.6
	inner.material_override = red
	inner.rotation_degrees.x = 90.0
	_mesh.add_child(inner)
	var post := MeshInstance3D.new()
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.04
	post_mesh.bottom_radius = 0.04
	post_mesh.height = 1.0
	post.mesh = post_mesh
	post.material_override = Materials.get_material("metal_panel")
	post.position.y = -0.5
	add_child(post)
	scale = Vector3(0.001, 0.001, 0.001)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if _dead:
		return
	_time += delta
	lifetime -= delta
	_mesh.rotation.y += delta * 1.4
	if lifetime <= 0.0:
		_dead = true
		expired.emit(self)
		var tween := create_tween()
		tween.tween_property(self, "scale", Vector3(0.001, 0.001, 0.001), 0.12)
		tween.tween_callback(queue_free)


func take_hit(_damage: float, direction: Vector3, point: Vector3, _headshot: bool, _shooter: Node3D) -> void:
	if _dead:
		return
	_dead = true
	var fx := Fx.get_active()
	if fx != null:
		fx.impact(point, -direction, "metal")
	Audio.play_ui("hitmarker", -4.0)
	hit.emit(self, base_points)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3.ZERO, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "rotation:z", deg_to_rad(85.0), 0.18)
	tween.chain().tween_callback(queue_free)
