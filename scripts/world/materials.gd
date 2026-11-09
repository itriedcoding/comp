class_name Materials
extends RefCounted
## Procedural PBR material library. Every surface is built from seeded noise
## (albedo ramp + normal + roughness + AO), so the project ships without
## external assets while keeping per-surface variation instead of flat colours.

static var _cache: Dictionary = {}


static func texture_resolution() -> int:
	var quality := "High"
	if Game != null:
		quality = String(Game.settings["texture_quality"])
	match quality:
		"Low":
			return 256
		"Medium":
			return 512
		"Ultra":
			return 2048
		_:
			return 1024


static func _noise(seed_value: int, frequency: float, octaves: int = 4) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.frequency = frequency
	n.fractal_octaves = octaves
	n.fractal_gain = 0.55
	n.fractal_lacunarity = 2.05
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	return n


static func _texture(seed_value: int, frequency: float, normal: bool = false, bump: float = 2.0, res_div: int = 1) -> NoiseTexture2D:
	var t := NoiseTexture2D.new()
	var res: int = maxi(64, texture_resolution() / maxi(1, res_div))
	t.width = res
	t.height = res
	t.seamless = true
	t.noise = _noise(seed_value, frequency)
	t.generate_mipmaps = true
	t.as_normal_map = normal
	t.bump_strength = bump
	return t


static func _ramp(seed_value: int, frequency: float, dark: Color, light: Color) -> NoiseTexture2D:
	var t := _texture(seed_value, frequency)
	var ramp := Gradient.new()
	ramp.set_color(0, dark)
	ramp.set_color(1, light)
	t.color_ramp = ramp
	return t


## Applies a full PBR set: ramped albedo, tangent-space normals, roughness and
## ambient occlusion. Normal/roughness/AO are generated at half resolution to
## keep the texture budget small (roughly 200 MB of VRAM at "High").
static func _pbr(mat: StandardMaterial3D, alb_seed: int, freq: float, dark: Color, light: Color,
		rough_seed: int, normal_seed: int, bump: float, ao_seed: int,
		metal: float = 0.0, rough: float = 1.0) -> void:
	mat.albedo_texture = _ramp(alb_seed, freq, dark, light)
	mat.albedo_color = Color.WHITE
	mat.normal_enabled = true
	mat.normal_texture = _texture(normal_seed, freq * 1.7, true, bump, 2)
	mat.normal_scale = 1.0
	mat.roughness_texture = _texture(rough_seed, freq * 1.3, false, 2.0, 2)
	mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	mat.roughness = rough
	mat.metallic = metal
	if ao_seed > 0:
		mat.ao_enabled = true
		mat.ao_texture = _texture(ao_seed, freq * 2.2, false, 2.0, 2)
		mat.ao_light_affect = 0.65


static func _base(kind: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.roughness = 0.8
	mat.metallic = 0.0
	match kind:
		"concrete":
			_pbr(mat, 11, 0.05, Color(0.26, 0.255, 0.245), Color(0.62, 0.61, 0.585),
				13, 12, 2.6, 14)
			mat.uv1_scale = Vector3(2.0, 2.0, 1.0)
		"concrete_wall":
			_pbr(mat, 21, 0.04, Color(0.3, 0.295, 0.28), Color(0.66, 0.645, 0.62),
				23, 22, 2.2, 24)
			mat.uv1_scale = Vector3(1.2, 1.2, 1.0)
		"asphalt":
			_pbr(mat, 31, 0.16, Color(0.08, 0.082, 0.09), Color(0.25, 0.255, 0.26),
				33, 32, 1.7, 34, 0.0, 0.9)
			mat.uv1_scale = Vector3(3.0, 3.0, 1.0)
		"metal_panel":
			_pbr(mat, 41, 0.06, Color(0.17, 0.18, 0.19), Color(0.5, 0.52, 0.53),
				43, 42, 1.2, 44, 0.78, 0.55)
			mat.metallic_specular = 0.62
			mat.uv1_scale = Vector3(1.5, 1.5, 1.0)
		"rust":
			_pbr(mat, 51, 0.07, Color(0.2, 0.11, 0.06), Color(0.55, 0.36, 0.22),
				53, 52, 3.0, 54, 0.35, 0.9)
			mat.uv1_scale = Vector3(1.6, 1.6, 1.0)
		"crate_red":
			_pbr(mat, 61, 0.09, Color(0.19, 0.06, 0.05), Color(0.5, 0.18, 0.14),
				0, 62, 1.4, 0, 0.45, 0.7)
			mat.uv1_scale = Vector3(1.4, 1.4, 1.0)
		"crate_blue":
			_pbr(mat, 63, 0.09, Color(0.06, 0.11, 0.19), Color(0.16, 0.3, 0.45),
				0, 64, 1.4, 0, 0.45, 0.7)
			mat.uv1_scale = Vector3(1.4, 1.4, 1.0)
		"crate_green":
			_pbr(mat, 65, 0.09, Color(0.08, 0.13, 0.08), Color(0.22, 0.33, 0.2),
				0, 66, 1.4, 0, 0.4, 0.72)
			mat.uv1_scale = Vector3(1.4, 1.4, 1.0)
		"wood":
			_pbr(mat, 71, 0.12, Color(0.18, 0.12, 0.07), Color(0.52, 0.38, 0.24),
				0, 72, 2.2, 0, 0.0, 0.82)
			mat.uv1_scale = Vector3(1.5, 1.5, 1.0)
		"wood_plank":
			_pbr(mat, 73, 0.22, Color(0.22, 0.16, 0.09), Color(0.58, 0.45, 0.3),
				0, 74, 2.0, 0, 0.0, 0.85)
			mat.uv1_scale = Vector3(2.0, 2.0, 1.0)
		"dirt":
			_pbr(mat, 81, 0.1, Color(0.13, 0.11, 0.08), Color(0.42, 0.36, 0.27),
				0, 82, 2.4, 84, 0.0, 0.96)
			mat.uv1_scale = Vector3(4.0, 4.0, 1.0)
		"grass":
			_pbr(mat, 91, 0.13, Color(0.07, 0.1, 0.05), Color(0.3, 0.38, 0.2),
				0, 92, 2.6, 94, 0.0, 0.95)
			mat.uv1_scale = Vector3(4.0, 4.0, 1.0)
		"foliage":
			mat.albedo_texture = _ramp(93, 0.2, Color(0.05, 0.09, 0.04), Color(0.24, 0.34, 0.15))
			mat.albedo_color = Color.WHITE
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.roughness = 0.92
			mat.uv1_scale = Vector3(2.0, 2.0, 1.0)
			mat.normal_enabled = true
			mat.normal_texture = _texture(95, 0.35, true, 2.4, 2)
		"glass":
			mat.albedo_color = Color(0.18, 0.22, 0.24, 0.22)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.metallic = 0.15
			mat.metallic_specular = 0.95
			mat.roughness = 0.04
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.uv1_scale = Vector3(1.0, 1.0, 1.0)
		"rubber":
			mat.albedo_color = Color(0.045, 0.045, 0.05)
			mat.roughness = 0.9
			mat.normal_enabled = true
			mat.normal_texture = _texture(96, 0.4, true, 1.4, 2)
		"fabric":
			_pbr(mat, 101, 0.18, Color(0.16, 0.155, 0.12), Color(0.42, 0.4, 0.31),
				0, 102, 1.8, 0, 0.0, 0.97)
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.uv1_scale = Vector3(2.0, 2.0, 1.0)
		"vest":
			_pbr(mat, 103, 0.24, Color(0.09, 0.095, 0.085), Color(0.26, 0.27, 0.24),
				0, 104, 2.0, 0, 0.0, 0.94)
			mat.uv1_scale = Vector3(2.5, 2.5, 1.0)
		"glove":
			_pbr(mat, 105, 0.3, Color(0.11, 0.1, 0.085), Color(0.3, 0.28, 0.23),
				0, 106, 2.0, 0, 0.0, 0.93)
			mat.uv1_scale = Vector3(3.0, 3.0, 1.0)
		"skin":
			mat.albedo_color = Color(0.47, 0.35, 0.28)
			mat.roughness = 0.62
			mat.metallic_specular = 0.35
			mat.normal_enabled = true
			mat.normal_texture = _texture(107, 0.5, true, 0.8, 2)
		"sandbag":
			_pbr(mat, 111, 0.24, Color(0.2, 0.18, 0.12), Color(0.52, 0.47, 0.34),
				0, 112, 2.8, 114, 0.0, 0.97)
			mat.uv1_scale = Vector3(2.5, 2.5, 1.0)
		"brick":
			_pbr(mat, 121, 0.14, Color(0.16, 0.08, 0.06), Color(0.48, 0.27, 0.2),
				0, 122, 3.2, 124, 0.0, 0.92)
			mat.uv1_scale = Vector3(2.0, 2.0, 1.0)
		"roof":
			_pbr(mat, 131, 0.16, Color(0.09, 0.095, 0.1), Color(0.3, 0.31, 0.32),
				0, 132, 1.6, 0, 0.2, 0.88)
			mat.uv1_scale = Vector3(3.0, 3.0, 1.0)
		"puddle":
			mat.albedo_color = Color(0.05, 0.06, 0.07, 0.88)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.roughness = 0.02
			mat.metallic = 0.4
			mat.metallic_specular = 1.0
		"lamp":
			mat.albedo_color = Color(1.0, 0.9, 0.7)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.84, 0.6)
			mat.emission_energy_multiplier = 7.0
			mat.roughness = 0.35
		"lamp_cool":
			mat.albedo_color = Color(0.82, 0.9, 1.0)
			mat.emission_enabled = true
			mat.emission = Color(0.7, 0.86, 1.0)
			mat.emission_energy_multiplier = 6.0
		"alarm_light":
			mat.albedo_color = Color(1.0, 0.2, 0.15)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.18, 0.12)
			mat.emission_energy_multiplier = 5.0
		"screen":
			mat.albedo_color = Color(0.06, 0.12, 0.11)
			mat.emission_enabled = true
			mat.emission = Color(0.2, 0.8, 0.6)
			mat.emission_energy_multiplier = 2.8
			mat.roughness = 0.15
		"intel":
			mat.albedo_color = Color(0.85, 0.68, 0.2)
			mat.emission_enabled = true
			mat.emission = Color(0.95, 0.72, 0.2)
			mat.emission_energy_multiplier = 2.4
			mat.metallic = 0.6
			mat.roughness = 0.3
		"target":
			_pbr(mat, 141, 0.2, Color(0.55, 0.52, 0.46), Color(0.88, 0.86, 0.8),
				0, 142, 1.4, 0, 0.0, 0.75)
		_:
			mat.albedo_color = Color(0.5, 0.5, 0.5)
	return mat


static func get_material(kind: String) -> StandardMaterial3D:
	if _cache.has(kind):
		return _cache[kind]
	var mat := _base(kind)
	_cache[kind] = mat
	return mat


static func clear_cache() -> void:
	_cache.clear()


static func surface_for_material(kind: String) -> String:
	match kind:
		"metal_panel", "rust", "crate_red", "crate_blue", "crate_green", "lamp", "lamp_cool", "intel":
			return "metal"
		"wood", "wood_plank":
			return "wood"
		"glass":
			return "glass"
		"dirt":
			return "dirt"
		"grass", "foliage":
			return "grass"
		"fabric", "vest", "glove", "sandbag", "brick":
			return "sandbag" if kind == "sandbag" else "concrete"
		_:
			return "concrete"
