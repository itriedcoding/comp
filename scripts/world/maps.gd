class_name Maps
extends RefCounted
## Hand-authored level layouts. Each map returns the built geometry plus the
## gameplay data (spawns, patrols, markers, ambience) the modes consume.


static func build(map_id: String) -> Dictionary:
	match map_id:
		"urban":
			return _urban()
		"outpost":
			return _outpost()
		_:
			return _industrial()


static func _spawn(pos: Vector3, yaw_degrees: float = 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_degrees)), pos)


static func _perimeter_fence(b: WorldBuilder, rect: Rect2, gate_width: float = 10.0) -> void:
	var minp := rect.position
	var maxp := rect.position + rect.size
	var gate := gate_width * 0.5
	# North and east/west sides are solid.
	b.add_fence(Vector3((minp.x + maxp.x) * 0.5, 0, minp.y), rect.size.x, 0.0, 3.0)
	b.add_fence(Vector3(minp.x, 0, (minp.y + maxp.y) * 0.5), rect.size.y, 90.0, 3.0)
	b.add_fence(Vector3(maxp.x, 0, (minp.y + maxp.y) * 0.5), rect.size.y, 90.0, 3.0)
	# South side has a gate.
	var half := rect.size.x * 0.5
	var seg := half - gate
	b.add_fence(Vector3((minp.x + maxp.x) * 0.5 - gate - seg * 0.5, 0, maxp.y), seg, 0.0, 3.0)
	b.add_fence(Vector3((minp.x + maxp.x) * 0.5 + gate + seg * 0.5, 0, maxp.y), seg, 0.0, 3.0)


static func _ceiling_lights(b: WorldBuilder, positions: Array, color: Color, energy: float, height: float) -> void:
	for p in positions:
		b.add_omni(Vector3(p.x, height, p.z), color, energy, 16.0, false)
		var fixture := b.add_visual_box(Vector3(p.x, height + 0.2, p.z), Vector3(1.2, 0.12, 0.4), "lamp")
		fixture.name = "Fixture"


# --------------------------------------------------------------- industrial ---

static func _industrial() -> Dictionary:
	var b := WorldBuilder.new()
	b.name = "Industrial"
	var bounds := Rect2(-70, -70, 140, 140)
	b.add_box(Vector3(0, -0.4, 0), Vector3(140, 0.8, 140), "dirt", {"name": "Ground", "uv_scale": 0.18})
	b.add_box(Vector3(0, 0.03, -6), Vector3(52, 0.08, 30), "concrete", {"name": "WarehouseFloor", "collide": false, "uv_scale": 0.3})
	b.add_box(Vector3(0, 0.04, 30), Vector3(34, 0.08, 52), "asphalt", {"name": "Yard", "collide": false, "uv_scale": 0.3})
	_perimeter_fence(b, Rect2(-68, -68, 136, 136), 10.0)

	# --- warehouse shell ---
	b.add_wall_with_openings(Vector3(0, 3.5, -21), Vector3(52, 7.0, 0.6), "metal_panel", [
		{"center": -12.0, "width": 7.0, "bottom": -3.5, "top": 0.7},
		{"center": 12.0, "width": 7.0, "bottom": -3.5, "top": 0.7},
	], "x")
	b.add_wall_with_openings(Vector3(0, 3.5, 9), Vector3(52, 7.0, 0.6), "metal_panel", [
		{"center": 0.0, "width": 3.6, "bottom": -3.5, "top": 1.0},
	], "x")
	b.add_wall_with_openings(Vector3(26, 3.5, -6), Vector3(0.6, 7.0, 30), "metal_panel", [
		{"center": -10.0, "width": 3.2, "bottom": -1.7, "top": 0.4},
		{"center": 2.0, "width": 3.2, "bottom": -1.7, "top": 0.4},
	], "z")
	b.add_wall_with_openings(Vector3(-26, 3.5, -6), Vector3(0.6, 7.0, 30), "metal_panel", [
		{"center": -10.0, "width": 3.2, "bottom": -1.7, "top": 0.4},
		{"center": 2.0, "width": 3.2, "bottom": -1.7, "top": 0.4},
	], "z")
	b.add_box(Vector3(0, 7.25, -6), Vector3(52.6, 0.4, 30.6), "roof", {"name": "WarehouseRoof", "uv_scale": 0.25})
	# Roof trusses.
	for z in [-18.0, -11.0, -4.0, 3.0]:
		b.add_visual_box(Vector3(0, 6.85, z), Vector3(51.0, 0.22, 0.22), "rust")
	# Columns.
	var columns := [Vector3(-12, 0, -14), Vector3(0, 0, -14), Vector3(12, 0, -14), Vector3(-12, 0, 0), Vector3(0, 0, 0), Vector3(12, 0, 0)]
	for c in columns:
		b.add_box(c + Vector3(0, 3.5, 0), Vector3(0.5, 7.0, 0.5), "metal_panel", {"name": "Column", "uv_scale": 1.0})

	# --- mezzanine with railing and stairs ---
	b.add_box(Vector3(21.2, 3.85, -8), Vector3(8.8, 0.35, 24), "metal_panel", {"name": "Mezzanine", "uv_scale": 0.5, "surface": "metal"})
	b.add_railing(Vector3(16.9, 4.02, -8), 24.0, 90.0, 1.05)
	b.add_stairs(Vector3(21, 0, 5.2), 1.8, 4.02, 5.0, 14, "metal_panel", 180.0)
	# Mezzanine storage.
	b.add_crate_stack(Vector3(22.5, 4.05, -17.5), 1.1, 2)
	b.add_crate(Vector3(19.0, 4.05, -12.0), 1.0, "wood")

	# --- office (intel objective) ---
	b.add_office(Vector3(-19, 0, -15), Vector3(10, 3.2, 8))
	b.add_omni(Vector3(-19, 2.8, -15), Color(0.85, 0.92, 1.0), 1.6, 7.0, false)
	b.add_box(Vector3(-19.5, 0.02, -15.5), Vector3(9.0, 0.05, 7.0), "wood_plank", {"name": "OfficeFloor", "collide": false, "uv_scale": 0.6})

	# --- interior clutter ---
	b.add_pallet_rack(Vector3(-23.0, 0, 0), 90.0, 3)
	b.add_crate_stack(Vector3(-8, 0, -17), 1.2, 3)
	b.add_crate_stack(Vector3(-5.5, 0, -16.6), 1.2, 2)
	b.add_crate_stack(Vector3(6, 0, 4.5), 1.1, 3)
	b.add_crate(Vector3(9.5, 0, 3.5), 1.3, "wood")
	b.add_barrel(Vector3(14, 0, -18), "red")
	b.add_barrel(Vector3(14.8, 0, -17.2), "blue")
	b.add_barrel(Vector3(-14.5, 0, 5.0), "green")
	b.add_workbench(Vector3(2.5, 0, -19.2), 0.0)
	b.add_workbench(Vector3(-21.0, 0, 5.0), 90.0)
	# Forklift.
	b.add_box(Vector3(-2, 0.7, 1.5), Vector3(2.6, 1.4, 1.4), "crate_green", {"name": "Forklift", "uv_scale": 0.8})
	b.add_box(Vector3(-0.6, 1.9, 1.5), Vector3(1.2, 0.9, 1.2), "metal_panel", {"name": "ForkliftCage"})
	b.add_box(Vector3(-3.6, 0.35, 1.5), Vector3(2.0, 0.08, 0.8), "metal_panel", {"name": "Forks", "collide": false})
	# Ceiling pipe runs.
	b.add_pipe_run(Vector3(-25, 6.4, -19), Vector3(25, 6.4, -19), 0.18)
	b.add_pipe_run(Vector3(-25, 6.0, 6), Vector3(25, 6.0, 6), 0.14)
	_ceiling_lights(b, [Vector3(-15, 0, -14), Vector3(0, 0, -14), Vector3(15, 0, -14), Vector3(-15, 0, 0), Vector3(0, 0, 2), Vector3(15, 0, 2)], Color(1.0, 0.88, 0.7), 2.1, 6.2)
	b.add_omni(Vector3(21, 4.9, -8), Color(1.0, 0.82, 0.6), 1.4, 12.0, false)

	# --- yard props ---
	b.add_container(Vector3(-22, 0, 18), 0.0, 0)
	b.add_container(Vector3(-22, 2.6, 18), 0.0, 2)
	b.add_container(Vector3(-22, 0, 26), 0.0, 1)
	b.add_container(Vector3(18, 0, 24), 90.0, 2)
	b.add_container(Vector3(-6, 0, 38), 0.0, 3, true)
	b.add_container(Vector3(26, 0, 42), 90.0, 0)
	b.add_truck(Vector3(6, 0, 48), 90.0, "crate_green")
	b.add_truck(Vector3(-38, 0, 34), 0.0, "crate_blue")
	b.add_jersey_barrier(Vector3(0, 0, 22), 0.0)
	b.add_jersey_barrier(Vector3(-3.2, 0, 22), 0.0)
	b.add_jersey_barrier(Vector3(3.2, 0, 22), 0.0)
	b.add_jersey_barrier(Vector3(30, 0, 16), 90.0)
	b.add_floodlight(Vector3(-42, 0, 56), 0.0)
	b.add_floodlight(Vector3(42, 0, 56), 0.0)
	b.add_floodlight(Vector3(-42, 0, -18), 0.0)
	b.add_floodlight(Vector3(42, 0, -14), 0.0)
	b.add_crate_stack(Vector3(32, 0, 34), 1.2, 2)
	b.add_barrel(Vector3(30.5, 0, 30), "red")
	b.add_barrel(Vector3(31.4, 0, 30.6), "rust")
	b.add_box(Vector3(34, 1.4, 46), Vector3(4.0, 2.8, 4.0), "concrete_wall", {"name": "GuardShack"})
	b.add_box(Vector3(34, 2.85, 46), Vector3(4.4, 0.2, 4.4), "roof", {"name": "GuardRoof", "collide": false})
	b.add_omni(Vector3(34, 2.4, 46), Color(1.0, 0.85, 0.6), 1.4, 8.0, false)
	b.add_dumpster(Vector3(-16, 0, 48), 0.0)
	for i in 4:
		b.add_puddle(Vector3(-6 + i * 4.5, 0.05, 24 + i * 5.0), Vector2(3.4, 2.6))

	# --- loading dock to the north ---
	b.add_box(Vector3(0, 0.6, -26), Vector3(26, 1.2, 7), "concrete", {"name": "Dock", "uv_scale": 0.4})
	b.add_box(Vector3(0, 0.55, -30.5), Vector3(8, 1.0, 3.0), "concrete", {"name": "DockRamp", "rotation": Vector3(-8, 0, 0), "uv_scale": 0.4})
	b.add_crate_stack(Vector3(-8, 1.2, -26), 1.2, 2)
	b.add_crate_stack(Vector3(8, 1.2, -26), 1.1, 3)
	b.add_barrel(Vector3(-11, 1.2, -24), "blue")
	b.add_floodlight(Vector3(20, 0, -28), 180.0)

	b.build_navigation(bounds)
	var data := {
		"id": "industrial",
		"name": "Kessler Industrial Complex",
		"ambience": "industrial",
		"rain": false,
		"time_of_day": "dusk",
		"bounds": bounds,
		"player_spawn": _spawn(Vector3(0, 0.2, 62), 0.0),
		"markers": {
			"entry": Vector3(0, 0.2, -6),
			"intel": Vector3(-19, 1.0, -15.5),
			"extract": Vector3(0, 0.2, 64),
		},
		"enemy_spawns": [
			{"position": Vector3(-6, 0.2, -15), "patrol": [Vector3(-6, 0.2, -15), Vector3(4, 0.2, -8), Vector3(-10, 0.2, 3), Vector3(-6, 0.2, -15)]},
			{"position": Vector3(21, 4.2, -16), "patrol": [Vector3(21, 4.2, -16), Vector3(21, 4.2, 2), Vector3(23, 4.2, -6), Vector3(21, 4.2, -16)]},
			{"position": Vector3(10, 0.2, 2), "patrol": [Vector3(10, 0.2, 2), Vector3(14, 0.2, -12), Vector3(3, 0.2, 4), Vector3(10, 0.2, 2)]},
			{"position": Vector3(18, 0.2, 30), "patrol": [Vector3(18, 0.2, 30), Vector3(0, 0.2, 30), Vector3(18, 0.2, 44), Vector3(18, 0.2, 30)]},
			{"position": Vector3(-20, 0.2, 24), "patrol": [Vector3(-20, 0.2, 24), Vector3(-20, 0.2, 44), Vector3(-34, 0.2, 34), Vector3(-20, 0.2, 24)]},
			{"position": Vector3(34, 0.2, 44), "patrol": [Vector3(34, 0.2, 44), Vector3(30, 0.2, 54), Vector3(34, 0.2, 44)]},
			{"position": Vector3(-16, 1.4, -25), "patrol": [Vector3(-16, 1.4, -25), Vector3(10, 1.4, -25), Vector3(-16, 1.4, -25)]},
			{"position": Vector3(-24, 0.2, -10), "patrol": [Vector3(-24, 0.2, -10), Vector3(-24, 0.2, 10), Vector3(-14, 0.2, 0), Vector3(-24, 0.2, -10)]},
			{"position": Vector3(8, 0.2, -16), "patrol": [Vector3(8, 0.2, -16), Vector3(12, 0.2, -4), Vector3(2, 0.2, -10), Vector3(8, 0.2, -16)]},
			{"position": Vector3(-32, 0.2, 52), "patrol": [Vector3(-32, 0.2, 52), Vector3(-14, 0.2, 56), Vector3(-32, 0.2, 52)]},
		],
	}
	return {"builder": b, "data": data}


# -------------------------------------------------------------------- urban ---

static func _urban() -> Dictionary:
	var b := WorldBuilder.new()
	b.name = "Urban"
	var bounds := Rect2(-60, -60, 120, 120)
	b.add_box(Vector3(0, -0.4, 0), Vector3(130, 0.8, 130), "asphalt", {"name": "Ground", "uv_scale": 0.2})
	# Street + sidewalks.
	b.add_box(Vector3(0, 0.02, 0), Vector3(28, 0.06, 120), "asphalt", {"name": "Road", "collide": false, "uv_scale": 0.35})
	for side in [-1.0, 1.0]:
		b.add_box(Vector3(side * 16.5, 0.12, 0), Vector3(5, 0.24, 120), "concrete", {"name": "Sidewalk", "uv_scale": 0.3})
	for i in range(-5, 6):
		b.add_visual_box(Vector3(0, 0.07, i * 9.0), Vector3(0.18, 0.02, 3.4), "target")
	# Crosswalk near the plaza.
	for i in range(-3, 4):
		b.add_visual_box(Vector3(i * 2.0, 0.07, -22), Vector3(1.1, 0.02, 5.0), "target")

	# --- building A (east, fully enterable to the roof) ---
	var ax0 := 20.0
	var ax1 := 40.0
	var az0 := -12.0
	var az1 := 12.0
	var mid_y := 4.2
	var wall_h := 8.4
	var cx := (ax0 + ax1) * 0.5
	var cz := (az0 + az1) * 0.5
	b.add_wall_with_openings(Vector3(ax0, mid_y, cz), Vector3(0.6, wall_h, az1 - az0), "brick", [
		{"center": 0.0, "width": 3.2, "bottom": -4.2, "top": -1.9},
		{"center": -8.0, "width": 4.0, "bottom": -2.8, "top": -1.0},
		{"center": 7.5, "width": 4.0, "bottom": -2.8, "top": -1.0},
	], "z")
	b.add_wall_with_openings(Vector3(ax1, mid_y, cz), Vector3(0.6, wall_h, az1 - az0), "brick", [
		{"center": -6.0, "width": 3.0, "bottom": -2.8, "top": -1.0},
		{"center": 6.0, "width": 3.0, "bottom": -2.8, "top": -1.0},
		{"center": 0.0, "width": 3.0, "bottom": 1.0, "top": 2.6},
	], "z")
	b.add_wall_with_openings(Vector3(cx, mid_y, az0), Vector3(ax1 - ax0, wall_h, 0.6), "brick", [
		{"center": -5.0, "width": 4.0, "bottom": -2.8, "top": -1.0},
		{"center": 5.0, "width": 4.0, "bottom": -2.8, "top": -1.0},
		{"center": 0.0, "width": 3.0, "bottom": 1.2, "top": 2.8},
	], "x")
	b.add_wall_with_openings(Vector3(cx, mid_y, az1), Vector3(ax1 - ax0, wall_h, 0.6), "brick", [
		{"center": -6.0, "width": 4.0, "bottom": -2.8, "top": -1.0},
		{"center": 6.0, "width": 4.0, "bottom": -2.8, "top": -1.0},
	], "x")
	# Second floor with a stairwell opening.
	b.add_box(Vector3(27.0, mid_y - 0.15, cz), Vector3(14.0, 0.3, az1 - az0), "concrete", {"name": "Floor2", "uv_scale": 0.4})
	b.add_box(Vector3(37.0, mid_y - 0.15, -8.0), Vector3(6.0, 0.3, 8.0), "concrete", {"name": "Floor2", "uv_scale": 0.4})
	b.add_box(Vector3(37.0, mid_y - 0.15, 8.0), Vector3(6.0, 0.3, 8.0), "concrete", {"name": "Floor2", "uv_scale": 0.4})
	b.add_railing(Vector3(34.0, mid_y + 0.0, cz), 24.0, 90.0, 1.0)
	b.add_stairs(Vector3(37.0, 0.0, 0.0), 1.7, mid_y, 5.0, 14, "concrete", 180.0)
	# Roof with stair opening (x 20.5..23.5, z 8..12).
	b.add_box(Vector3(30.0, wall_h + 0.15, -2.0), Vector3(20.0, 0.3, 20.0), "roof", {"name": "Roof", "uv_scale": 0.3})
	b.add_box(Vector3(31.75, wall_h + 0.15, 10.0), Vector3(16.5, 0.3, 4.0), "roof", {"name": "Roof", "uv_scale": 0.3})
	b.add_box(Vector3(20.25, wall_h + 0.15, 10.0), Vector3(0.5, 0.3, 4.0), "roof", {"name": "Roof", "uv_scale": 0.3})
	b.add_stairs(Vector3(22.0, mid_y, 9.5), 1.7, mid_y, 4.5, 12, "metal_panel", 0.0)
	b.add_railing(Vector3(30.0, wall_h + 0.3, -11.8), 19.5, 0.0, 1.05)
	b.add_railing(Vector3(39.8, wall_h + 0.3, 0.0), 23.5, 90.0, 1.05)
	b.add_railing(Vector3(22.0, wall_h + 0.3, -11.8), 4.0, 0.0, 1.05)
	# Rooftop comms relay (mission objective site).
	b.add_box(Vector3(31.0, wall_h + 0.9, -4.0), Vector3(1.4, 1.8, 1.0), "metal_panel", {"name": "RelayCabinet"})
	b.add_antenna(Vector3(31.0, wall_h + 0.3, -6.0), 5.0)
	b.add_omni(Vector3(31.0, wall_h + 1.4, -4.0), Color(0.55, 0.9, 1.0), 1.6, 8.0)
	# Ground floor lobby props.
	b.add_box(Vector3(27.0, 0.65, -8.0), Vector3(4.0, 1.3, 1.2), "wood_plank", {"name": "ReceptionDesk"})
	b.add_visual_box(Vector3(27.0, 1.05, -8.6), Vector3(1.2, 0.5, 0.1), "screen")
	b.add_box(Vector3(23.5, 0.95, 8.5), Vector3(1.0, 1.9, 0.9), "crate_blue", {"name": "Vending"})
	b.add_box(Vector3(25.0, 0.95, 8.5), Vector3(1.0, 1.9, 0.9), "crate_red", {"name": "Vending"})
	b.add_box(Vector3(33.0, 0.6, 6.0), Vector3(2.6, 1.2, 1.0), "wood_plank", {"name": "Counter"})
	b.add_crate_stack(Vector3(34.0, 0.0, -6.0), 1.0, 2)
	# Second floor offices.
	b.add_wall_with_openings(Vector3(28.0, mid_y + 1.4, 2.0), Vector3(8.0, 2.8, 0.4), "concrete_wall", [
		{"center": 2.0, "width": 1.4, "bottom": -1.4, "top": 0.0},
	], "x")
	b.add_wall(Vector3(31.0, mid_y + 1.4, -2.0), Vector3(0.4, 2.8, 8.0), "concrete_wall")
	b.add_box(Vector3(29.0, mid_y + 0.55, -5.0), Vector3(2.0, 0.9, 0.9), "wood_plank", {"name": "Desk2"})
	b.add_box(Vector3(24.0, mid_y + 0.55, 0.0), Vector3(2.4, 0.9, 0.9), "wood_plank", {"name": "Desk2"})
	b.add_omni(Vector3(30, mid_y + 2.6, 0), Color(1.0, 0.9, 0.75), 2.0, 12.0)
	b.add_omni(Vector3(30, 2.8, 0), Color(0.9, 0.95, 1.0), 1.8, 14.0, false)

	# --- building B (west, sealed commercial block with fire escape) ---
	var bx0 := -44.0
	var bx1 := -20.0
	var bz0 := -14.0
	var bz1 := 22.0
	var bcz := (bz0 + bz1) * 0.5
	b.add_box(Vector3((bx0 + bx1) * 0.5, 6.0, bcz), Vector3(bx1 - bx0, 12.0, bz1 - bz0), "brick", {"name": "BuildingB", "uv_scale": 0.3, "cover": false})
	# Storefront band and awning.
	b.add_box(Vector3(bx1 + 0.1, 1.7, bcz), Vector3(0.2, 3.4, bz1 - bz0 - 4.0), "glass", {"name": "Storefront", "collide": false})
	b.add_box(Vector3(bx1 + 0.9, 3.6, bcz), Vector3(1.8, 0.15, bz1 - bz0 - 3.0), "fabric", {"name": "Awning", "collide": false, "rotation": Vector3(0, 0, -8)})
	for i in 4:
		b.add_box(Vector3(bx1 + 0.15, 5.6 + i * 1.1, bz0 + 5.0 + i * 4.0), Vector3(0.1, 2.2, 0.9), "screen", {"name": "Sign", "collide": false})
	# Fire escape.
	b.add_box(Vector3(bx1 + 1.0, 4.5, bz0 + 6.0), Vector3(2.0, 0.2, 5.0), "metal_panel", {"name": "FireEscape", "surface": "metal"})
	b.add_box(Vector3(bx1 + 1.0, 8.0, bz0 + 12.0), Vector3(2.0, 0.2, 5.0), "metal_panel", {"name": "FireEscape", "surface": "metal"})
	b.add_stairs(Vector3(bx1 + 1.4, 0.0, bz0 + 2.0), 1.2, 4.4, 3.0, 10, "metal_panel", 180.0)

	# --- building C (north, sealed civic block with plaza entrance) ---
	b.add_box(Vector3(0, 7.0, -48), Vector3(30.0, 14.0, 18.0), "concrete_wall", {"name": "BuildingC", "uv_scale": 0.25, "cover": false})
	b.add_box(Vector3(0, 2.2, -38.9), Vector3(10.0, 4.4, 0.4), "metal_panel", {"name": "Shutter", "surface": "metal"})
	b.add_visual_box(Vector3(0, 5.2, -38.7), Vector3(12.0, 0.6, 0.4), "screen")
	for i in 5:
		b.add_visual_box(Vector3(-12.0 + i * 6.0, 10.0, -38.8), Vector3(3.0, 2.4, 0.2), "glass")
	b.add_omni(Vector3(0, 4.6, -36.0), Color(1.0, 0.9, 0.72), 2.4, 18.0, false)

	# --- plaza ---
	for i in 3:
		var px := -10.0 + i * 10.0
		b.add_box(Vector3(px, 0.3, -26.0), Vector3(2.4, 0.6, 2.4), "concrete", {"name": "Planter"})
		b.add_bush(Vector3(px, 0.6, -26.0), 0.8)
	b.add_box(Vector3(0, 0.25, -16.0), Vector3(4.5, 0.5, 4.5), "concrete", {"name": "FountainBase"})
	b.add_puddle(Vector3(0, 0.52, -16.0), Vector2(4.0, 4.0))
	b.add_box(Vector3(-9.0, 0.45, -14.0), Vector3(2.2, 0.15, 1.4), "wood_plank", {"name": "Bench"})
	b.add_box(Vector3(9.0, 0.45, -14.0), Vector3(2.2, 0.15, 1.4), "wood_plank", {"name": "Bench"})
	b.add_fence(Vector3(-14.0, 0, -30.0), 8.0, 90.0, 2.0)
	# Kiosk with cover.
	b.add_box(Vector3(12.0, 1.4, -32.0), Vector3(3.0, 2.8, 2.4), "crate_green", {"name": "Kiosk"})
	b.add_box(Vector3(12.0, 2.9, -32.0), Vector3(3.6, 0.15, 3.0), "fabric", {"name": "KioskRoof", "collide": false})
	# Street furniture.
	b.add_streetlight(Vector3(-16.0, 0.2, 20.0), 0.0)
	b.add_streetlight(Vector3(16.0, 0.2, 8.0), 180.0)
	b.add_streetlight(Vector3(-16.0, 0.2, -12.0), 0.0)
	b.add_streetlight(Vector3(16.0, 0.2, -32.0), 180.0)
	b.add_car(Vector3(-8.0, 0.0, 32.0), 0.0, "crate_blue")
	b.add_car(Vector3(7.0, 0.0, 14.0), 180.0, "crate_red")
	b.add_car(Vector3(-7.0, 0.0, -34.0), 0.0, "rust")
	b.add_truck(Vector3(8.0, 0.0, 40.0), 90.0, "crate_green")
	b.add_dumpster(Vector3(43.0, 0.0, 18.0), 0.0)
	b.add_dumpster(Vector3(43.0, 0.0, 20.5), 0.0)
	b.add_crate_stack(Vector3(42.0, 0.0, 24.0), 1.0, 2)
	b.add_jersey_barrier(Vector3(-3.0, 0.0, -8.0), 0.0)
	b.add_jersey_barrier(Vector3(3.0, 0.0, -8.0), 0.0)
	# Bus shelter.
	b.add_box(Vector3(-18.5, 1.4, 26.0), Vector3(0.15, 2.8, 4.0), "metal_panel", {"name": "Shelter"})
	b.add_box(Vector3(-18.5, 2.85, 26.0), Vector3(2.4, 0.12, 4.4), "glass", {"name": "ShelterRoof", "collide": false})
	# Puddles and wet patches.
	for i in 6:
		b.add_puddle(Vector3(-10.0 + i * 4.2, 0.08, -6.0 + i * 6.5), Vector2(3.0, 2.0))
	b.build_navigation(bounds)
	var data := {
		"id": "urban",
		"name": "Sokol Heights",
		"ambience": "urban",
		"rain": true,
		"time_of_day": "night",
		"bounds": bounds,
		"player_spawn": _spawn(Vector3(0, 0.3, 54), 0.0),
		"markers": {
			"plaza": Vector3(0, 0.3, -28),
			"relay": Vector3(31, 8.9, -4),
			"extract": Vector3(44, 0.3, 28),
		},
		"enemy_spawns": [
			{"position": Vector3(0, 0.3, 26), "patrol": [Vector3(0, 0.3, 26), Vector3(-8, 0.3, 10), Vector3(8, 0.3, 0), Vector3(0, 0.3, 26)]},
			{"position": Vector3(-8, 0.3, -26), "patrol": [Vector3(-8, 0.3, -26), Vector3(8, 0.3, -24), Vector3(0, 0.3, -12), Vector3(-8, 0.3, -26)]},
			{"position": Vector3(27, 0.3, 4), "patrol": [Vector3(27, 0.3, 4), Vector3(33, 0.3, -4), Vector3(24, 0.3, 8), Vector3(27, 0.3, 4)]},
			{"position": Vector3(30, 4.5, 0), "patrol": [Vector3(30, 4.5, 0), Vector3(24, 4.5, -6), Vector3(32, 4.5, 8), Vector3(30, 4.5, 0)]},
			{"position": Vector3(28, 8.8, 2), "patrol": [Vector3(28, 8.8, 2), Vector3(33, 8.8, -8), Vector3(24, 8.8, 6), Vector3(28, 8.8, 2)]},
			{"position": Vector3(42, 0.3, 16), "patrol": [Vector3(42, 0.3, 16), Vector3(42, 0.3, 30), Vector3(38, 0.3, 20), Vector3(42, 0.3, 16)]},
			{"position": Vector3(-24, 0.3, -6), "patrol": [Vector3(-24, 0.3, -6), Vector3(-18, 0.3, 6), Vector3(-24, 0.3, 18), Vector3(-24, 0.3, -6)]},
			{"position": Vector3(2, 0.3, -40), "patrol": [Vector3(2, 0.3, -40), Vector3(-10, 0.3, -34), Vector3(12, 0.3, -34), Vector3(2, 0.3, -40)]},
			{"position": Vector3(12, 0.3, -30), "patrol": [Vector3(12, 0.3, -30), Vector3(14, 0.3, -18), Vector3(4, 0.3, -22), Vector3(12, 0.3, -30)]},
			{"position": Vector3(-12, 0.3, 44), "patrol": [Vector3(-12, 0.3, 44), Vector3(-2, 0.3, 38), Vector3(-16, 0.3, 30), Vector3(-12, 0.3, 44)]},
		],
	}
	return {"builder": b, "data": data}


# ------------------------------------------------------------------ outpost ---

static func _outpost() -> Dictionary:
	var b := WorldBuilder.new()
	b.name = "Outpost"
	var bounds := Rect2(-80, -80, 160, 160)
	b.add_box(Vector3(0, -0.4, 0), Vector3(160, 0.8, 160), "dirt", {"name": "Ground", "uv_scale": 0.15})
	b.add_box(Vector3(0, 0.03, 15), Vector3(9, 0.06, 100), "asphalt", {"name": "Road", "collide": false, "uv_scale": 0.3})
	_perimeter_fence(b, Rect2(-56, -56, 112, 112), 12.0)
	# Perimeter sandbag positions.
	b.add_sandbag_wall(Vector3(-18, 0, 52), 7.0, 0.0)
	b.add_sandbag_wall(Vector3(18, 0, 52), 7.0, 0.0)
	b.add_sandbag_wall(Vector3(-40, 0, 10), 8.0, 90.0)
	b.add_sandbag_wall(Vector3(40, 0, 10), 8.0, 90.0)
	# Command bunker (objective).
	b.add_bunker(Vector3(0, 0, -34), 0.0, "CommandBunker")
	b.add_omni(Vector3(0, 0.6, -27.0), Color(0.7, 0.85, 1.0), 1.2, 6.0)
	# Second bunker.
	b.add_bunker(Vector3(-30, 0, -24), 35.0, "WestBunker")
	# Watchtowers.
	b.add_watchtower(Vector3(-34, 0, 36))
	b.add_watchtower(Vector3(34, 0, -36))
	# Tents, vehicles, generators.
	b.add_tent(Vector3(-18, 0, 14), 0.0)
	b.add_tent(Vector3(-18, 0, 24), 0.0)
	b.add_tent(Vector3(18, 0, 14), 180.0)
	b.add_tent(Vector3(18, 0, 24), 180.0)
	b.add_truck(Vector3(12, 0, 38), 90.0, "crate_green")
	b.add_car(Vector3(-12, 0, 42), 0.0, "crate_green")
	b.add_generator(Vector3(-8, 0, -18))
	b.add_generator(Vector3(10, 0, 6))
	b.add_antenna(Vector3(22, 0, -20), 12.0)
	# Supply clusters.
	b.add_crate_stack(Vector3(-6, 0, 20), 1.2, 3)
	b.add_crate_stack(Vector3(-4.5, 0, 21.2), 1.2, 2)
	b.add_crate_stack(Vector3(6, 0, 18), 1.1, 2)
	b.add_crate_stack(Vector3(8, 0, -8), 1.2, 3)
	b.add_barrel(Vector3(4, 0, -12), "red")
	b.add_barrel(Vector3(4.8, 0, -12.7), "rust")
	b.add_barrel(Vector3(-12, 0, 4), "blue")
	b.add_barrel(Vector3(-12.8, 0, 4.6), "green")
	b.add_workbench(Vector3(14, 0, -6), 0.0)
	b.add_jersey_barrier(Vector3(0, 0, 40), 0.0)
	b.add_jersey_barrier(Vector3(-2.8, 0, 40), 0.0)
	b.add_jersey_barrier(Vector3(2.8, 0, 40), 0.0)
	b.add_pallet_rack(Vector3(30, 0, 6), 90.0, 2)
	b.add_dumpster(Vector3(-38, 0, -4), 0.0)
	# Landing zone marker.
	var pad := b.add_cylinder(Vector3(0, 0.05, 64), 6.0, 0.1, "concrete", {"collide": false, "segments": 32, "name": "Helipad"})
	for i in 4:
		b.add_omni(Vector3(cos(TAU * i / 4.0) * 6.0, 0.4, 64.0 + sin(TAU * i / 4.0) * 6.0), Color(0.4, 1.0, 0.55), 1.2, 10.0)
	b.add_box(Vector3(-3.0, 0.03, 64.0), Vector3(2.4, 0.02, 0.4), "target", {"collide": false})
	b.add_box(Vector3(3.0, 0.03, 64.0), Vector3(2.4, 0.02, 0.4), "target", {"collide": false})
	pad.name = "HelipadBase"
	# Forest ring + rocks + grass outside the fence.
	var forest_rng := RandomNumberGenerator.new()
	forest_rng.seed = 5150
	for i in 70:
		var angle := forest_rng.randf_range(0.0, TAU)
		var dist := forest_rng.randf_range(60.0, 78.0)
		var pos := Vector3(cos(angle) * dist, 0, sin(angle) * dist)
		if absf(pos.x) < 10.0 and pos.z > 52.0:
			continue
		b.add_tree(pos, forest_rng.randf_range(0.85, 1.35))
	for i in 18:
		var angle := forest_rng.randf_range(0.0, TAU)
		var dist := forest_rng.randf_range(42.0, 58.0)
		var pos := Vector3(cos(angle) * dist, 0, sin(angle) * dist)
		b.add_rock(pos, forest_rng.randf_range(0.5, 1.4))
	for i in 22:
		var angle := forest_rng.randf_range(0.0, TAU)
		var dist := forest_rng.randf_range(20.0, 54.0)
		var pos := Vector3(cos(angle) * dist, 0, sin(angle) * dist)
		b.add_bush(pos, forest_rng.randf_range(0.5, 1.0))
	# Grass patches inside the perimeter.
	for i in 12:
		var gx := forest_rng.randf_range(-48.0, 48.0)
		var gz := forest_rng.randf_range(-48.0, 48.0)
		b.add_grass_patch(Vector3(gx, 0.0, gz), Vector2(forest_rng.randf_range(6.0, 16.0), forest_rng.randf_range(6.0, 14.0)))
	b.build_navigation(bounds)
	var data := {
		"id": "outpost",
		"name": "Verkhout Ridge Outpost",
		"ambience": "outpost",
		"rain": false,
		"time_of_day": "dawn",
		"bounds": bounds,
		"player_spawn": _spawn(Vector3(0, 0.3, 66), 0.0),
		"markers": {
			"bunker": Vector3(0, 0.3, -26),
			"ledger": Vector3(0, 1.0, -32),
			"extract": Vector3(0, 0.3, 64),
		},
		"enemy_spawns": [
			{"position": Vector3(0, 0.3, 44), "patrol": [Vector3(0, 0.3, 44), Vector3(-14, 0.3, 44), Vector3(0, 0.3, 34), Vector3(0, 0.3, 44)]},
			{"position": Vector3(-18, 0.3, 20), "patrol": [Vector3(-18, 0.3, 20), Vector3(-26, 0.3, 26), Vector3(-14, 0.3, 30), Vector3(-18, 0.3, 20)]},
			{"position": Vector3(18, 0.3, 20), "patrol": [Vector3(18, 0.3, 20), Vector3(26, 0.3, 12), Vector3(12, 0.3, 8), Vector3(18, 0.3, 20)]},
			{"position": Vector3(-24, 0.3, -18), "patrol": [Vector3(-24, 0.3, -18), Vector3(-14, 0.3, -10), Vector3(-24, 0.3, -30), Vector3(-24, 0.3, -18)]},
			{"position": Vector3(0, 0.3, -26), "patrol": [Vector3(0, 0.3, -26), Vector3(10, 0.3, -30), Vector3(-10, 0.3, -30), Vector3(0, 0.3, -26)]},
			{"position": Vector3(28, 0.3, -32), "patrol": [Vector3(28, 0.3, -32), Vector3(38, 0.3, -24), Vector3(28, 0.3, -16), Vector3(28, 0.3, -32)]},
			{"position": Vector3(22, 0.3, -16), "patrol": [Vector3(22, 0.3, -16), Vector3(28, 0.3, -8), Vector3(16, 0.3, -12), Vector3(22, 0.3, -16)]},
			{"position": Vector3(-8, 0.3, -12), "patrol": [Vector3(-8, 0.3, -12), Vector3(2, 0.3, -6), Vector3(-12, 0.3, 0), Vector3(-8, 0.3, -12)]},
			{"position": Vector3(8, 0.3, -2), "patrol": [Vector3(8, 0.3, -2), Vector3(16, 0.3, 4), Vector3(2, 0.3, 8), Vector3(8, 0.3, -2)]},
			{"position": Vector3(-34, 0.3, 30), "patrol": [Vector3(-34, 0.3, 30), Vector3(-42, 0.3, 20), Vector3(-30, 0.3, 16), Vector3(-34, 0.3, 30)]},
			{"position": Vector3(34, 0.3, -34), "patrol": [Vector3(34, 0.3, -34), Vector3(40, 0.3, -44), Vector3(28, 0.3, -44), Vector3(34, 0.3, -34)]},
			{"position": Vector3(-12, 0.3, 34), "patrol": [Vector3(-12, 0.3, 34), Vector3(-4, 0.3, 30), Vector3(-16, 0.3, 28), Vector3(-12, 0.3, 34)]},
		],
	}
	return {"builder": b, "data": data}


# -------------------------------------------------------------- environment ---

static func make_environment(map_data: Dictionary) -> WorldEnvironment:
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	var env := Environment.new()
	var tod := String(map_data.get("time_of_day", "dusk"))
	# Physically based atmosphere (Rayleigh/Mie scattering) instead of a
	# hand-painted gradient: real aerial perspective and a sun disc.
	var sky_mat := PhysicalSkyMaterial.new()
	match tod:
		"night":
			sky_mat.rayleigh_coefficient = 0.35
			sky_mat.mie_coefficient = 0.002
			sky_mat.turbidity = 3.0
			sky_mat.energy_multiplier = 0.3
			sky_mat.ground_color = Color(0.012, 0.015, 0.02)
		"dawn":
			sky_mat.rayleigh_coefficient = 2.6
			sky_mat.mie_coefficient = 0.006
			sky_mat.turbidity = 11.0
			sky_mat.energy_multiplier = 1.15
			sky_mat.ground_color = Color(0.09, 0.08, 0.07)
		_:
			sky_mat.rayleigh_coefficient = 3.2
			sky_mat.mie_coefficient = 0.005
			sky_mat.turbidity = 8.0
			sky_mat.energy_multiplier = 1.0
			sky_mat.ground_color = Color(0.11, 0.09, 0.07)
	sky_mat.mie_eccentricity = 0.82
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.85
	env.ambient_light_energy = 0.9 if tod != "night" else 0.35
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.0
	env.glow_strength = 1.05
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.ssao_enabled = bool(Game.settings["ssao"])
	env.ssao_radius = 1.5
	env.ssao_intensity = 1.8
	env.ssao_power = 1.8
	env.ssao_detail = 0.65
	env.ssao_light_affect = 0.35
	env.ssao_ao_channel_affect = 0.25
	env.ssr_enabled = bool(Game.settings["ssr"])
	env.ssr_max_steps = 48
	env.ssr_fade_in = 0.15
	env.ssr_fade_out = 2.0
	env.ssr_depth_tolerance = 0.35
	env.ssil_enabled = bool(Game.settings["ssao"]) and String(Game.settings["shadow_quality"]) != "Low"
	env.ssil_radius = 2.4
	env.ssil_intensity = 0.85
	env.ssil_sharpness = 0.98
	env.ssil_normal_rejection = 1.0
	env.fog_enabled = true
	env.fog_sky_affect = 0.35
	match tod:
		"night":
			env.fog_light_color = Color(0.09, 0.12, 0.18)
			env.fog_light_energy = 0.8
			env.fog_density = 0.012
		"dawn":
			env.fog_light_color = Color(0.52, 0.55, 0.6)
			env.fog_light_energy = 1.1
			env.fog_density = 0.028 if map_data.get("id", "") == "outpost" else 0.016
		_:
			env.fog_light_color = Color(0.55, 0.46, 0.38)
			env.fog_light_energy = 0.9
			env.fog_density = 0.012
	env.fog_aerial_perspective = 0.4
	env.volumetric_fog_enabled = bool(Game.settings["volumetric_fog"])
	env.volumetric_fog_density = 0.02 if tod == "dawn" else 0.012
	env.volumetric_fog_albedo = Color(0.85, 0.85, 0.88)
	env.volumetric_fog_anisotropy = 0.2
	env.volumetric_fog_length = 96.0
	env.volumetric_fog_detail_spread = 1.4
	env.volumetric_fog_gi_inject = 0.4
	env.adjustment_enabled = true
	env.adjustment_brightness = float(Game.settings["brightness"])
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.04
	we.environment = env
	return we


static func add_sun(parent: Node3D, map_data: Dictionary) -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	var tod := String(map_data.get("time_of_day", "dusk"))
	match tod:
		"night":
			sun.light_color = Color(0.42, 0.52, 0.78)
			sun.light_energy = 0.16
			sun.rotation_degrees = Vector3(-28, 140, 0)
		"dawn":
			sun.light_color = Color(0.95, 0.8, 0.66)
			sun.light_energy = 1.25
			sun.rotation_degrees = Vector3(-10, 75, 0)
		_:
			sun.light_color = Color(1.0, 0.72, 0.5)
			sun.light_energy = 1.6
			sun.rotation_degrees = Vector3(-12, 205, 0)
	sun.shadow_enabled = true
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	sun.light_angular_distance = 0.75
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.2
	match String(Game.settings["shadow_quality"]):
		"Low":
			sun.directional_shadow_max_distance = 60.0
			sun.shadow_blur = 1.0
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		"Medium":
			sun.directional_shadow_max_distance = 100.0
			sun.shadow_blur = 1.4
		"High":
			sun.directional_shadow_max_distance = 160.0
			sun.shadow_blur = 1.8
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		"Ultra":
			sun.directional_shadow_max_distance = 240.0
			sun.shadow_blur = 2.2
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	parent.add_child(sun)
	return sun


static func add_weather(parent: Node3D, map_data: Dictionary) -> void:
	var effects := String(Game.settings["effects_quality"])
	var amount := 2600
	match effects:
		"Low":
			amount = 700
		"Medium":
			amount = 1500
		"Ultra":
			amount = 4200
	var rain := GPUParticles3D.new()
	rain.name = "Rain"
	rain.amount = maxi(1, amount)
	rain.emitting = bool(map_data.get("rain", false))
	rain.visible = rain.emitting
	rain.lifetime = 1.4
	rain.preprocess = 1.0
	rain.visibility_aabb = AABB(Vector3(-60, -10, -60), Vector3(120, 40, 120))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(55, 1.0, 55)
	pm.direction = Vector3(0.12, -1, 0.04)
	pm.spread = 2.5
	pm.initial_velocity_min = 16.0
	pm.initial_velocity_max = 22.0
	pm.gravity = Vector3(0, -9.8, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	rain.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.02, 0.55)
	var rain_mat := StandardMaterial3D.new()
	rain_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rain_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rain_mat.albedo_color = Color(0.68, 0.74, 0.82, 0.35)
	rain_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	rain_mat.disable_receive_shadows = true
	quad.material = rain_mat
	rain.draw_pass_1 = quad
	rain.position = Vector3(0, 18, 0)
	parent.add_child(rain)

	# Ambient dust motes.
	var dust := GPUParticles3D.new()
	dust.name = "Dust"
	dust.amount = maxi(60, amount / 8)
	dust.lifetime = 12.0
	dust.preprocess = 2.0
	dust.visibility_aabb = AABB(Vector3(-50, -5, -50), Vector3(100, 20, 100))
	var dpm := ParticleProcessMaterial.new()
	dpm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	dpm.emission_box_extents = Vector3(40, 4, 40)
	dpm.direction = Vector3(0.3, 0.1, 0.2)
	dpm.spread = 25.0
	dpm.initial_velocity_min = 0.05
	dpm.initial_velocity_max = 0.25
	dpm.gravity = Vector3(0, -0.02, 0)
	dpm.scale_min = 0.5
	dpm.scale_max = 1.5
	dust.process_material = dpm
	var mote := QuadMesh.new()
	mote.size = Vector2(0.035, 0.035)
	var mote_mat := StandardMaterial3D.new()
	mote_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mote_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mote_mat.albedo_color = Color(0.9, 0.86, 0.78, 0.35)
	mote_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mote.material = mote_mat
	dust.draw_pass_1 = mote
	dust.position = Vector3(0, 2.0, 0)
	parent.add_child(dust)
