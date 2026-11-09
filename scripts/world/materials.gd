class_name Materials
extends RefCounted
## Procedural PBR material library. Every surface in the game is built from
## seeded noise textures, so the project ships without missing external assets.

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
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	return n


static func _texture(seed_value: int, frequency: float, normal: bool = false, bump: float = 2.0) -> NoiseTexture2D:
	var t := NoiseTexture2D.new()
	t.width = texture_resolution()
	t.height = texture_resolution()
	t.seamless = true
	t.noise = _noise(seed_value, frequency)
	t.generate_mipmaps = true
	t.as_normal_map = normal
	t.bump_strength = bump
	return t


static func _base(kind: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.uv1_triplanar = false
	mat.roughness = 0.8
	mat.metallic = 0.0
	match kind:
		"concrete":
			mat.albedo_color = Color(0.44, 0.435, 0.415)
			mat.albedo_texture = _texture(11, 0.05)
			mat.normal_enabled = true
			mat.normal_texture = _texture(12, 0.09, true, 2.5)
			mat.roughness_texture = _texture(13, 0.08)
			mat.uv1_scale = Vector3(2.0, 2.0, 1.0)
			mat.roughness = 0.92
		"concrete_wall":
			mat.albedo_color = Color(0.5, 0.49, 0.47)
			mat.albedo_texture = _texture(21, 0.035)
			mat.normal_enabled = true
			mat.normal_texture = _texture(22, 0.06, true, 2.0)
			mat.roughness_texture = _texture(23, 0.05)
			mat.uv1_scale = Vector3(1.2, 1.2, 1.0)
			mat.roughness = 0.9
		"asphalt":
			mat.albedo_color = Color(0.16, 0.163, 0.17)
			mat.albedo_texture = _texture(31, 0.15)
			mat.normal_enabled = true
			mat.normal_texture = _texture(32, 0.2, true, 1.6)
			mat.roughness = 0.82
			mat.uv1_scale = Vector3(3.0, 3.0, 1.0)
		"metal_panel":
			mat.albedo_color = Color(0.3, 0.32, 0.33)
			mat.albedo_texture = _texture(41, 0.06)
			mat.metallic = 0.82
			mat.metallic_specular = 0.6
			mat.roughness = 0.42
			mat.normal_enabled = true
			mat.normal_texture = _texture(42, 0.08, true, 1.2)
			mat.uv1_scale = Vector3(1.5, 1.5, 1.0)
		"rust":
			mat.albedo_color = Color(0.34, 0.22, 0.15)
			mat.albedo_texture = _texture(51, 0.07)
			mat.metallic = 0.45
			mat.roughness = 0.88
			mat.normal_enabled = true
			mat.normal_texture = _texture(52, 0.12, true, 2.8)
			mat.uv1_scale = Vector3(1.6, 1.6, 1.0)
		"crate_red":
			mat.albedo_color = Color(0.36, 0.13, 0.1)
			mat.albedo_texture = _texture(61, 0.09)
			mat.metallic = 0.6
			mat.roughness = 0.62
			mat.uv1_scale = Vector3(1.4, 1.4, 1.0)
		"crate_blue":
			mat.albedo_color = Color(0.13, 0.21, 0.32)
			mat.albedo_texture = _texture(62, 0.09)
			mat.metallic = 0.6
			mat.roughness = 0.62
			mat.uv1_scale = Vector3(1.4, 1.4, 1.0)
		"crate_green":
			mat.albedo_color = Color(0.16, 0.24, 0.16)
			mat.albedo_texture = _texture(63, 0.09)
			mat.metallic = 0.55
			mat.roughness = 0.66
			mat.uv1_scale = Vector3(1.4, 1.4, 1.0)
		"wood":
			mat.albedo_color = Color(0.33, 0.24, 0.16)
			mat.albedo_texture = _texture(71, 0.12)
			mat.normal_enabled = true
			mat.normal_texture = _texture(72, 0.16, true, 2.0)
			mat.roughness = 0.78
			mat.uv1_scale = Vector3(1.5, 1.5, 1.0)
		"wood_plank":
			mat.albedo_color = Color(0.42, 0.33, 0.22)
			mat.albedo_texture = _texture(73, 0.2)
			mat.roughness = 0.82
			mat.uv1_scale = Vector3(2.0, 2.0, 1.0)
		"dirt":
			mat.albedo_color = Color(0.27, 0.24, 0.19)
			mat.albedo_texture = _texture(81, 0.1)
			mat.normal_enabled = true
			mat.normal_texture = _texture(82, 0.18, true, 2.2)
			mat.roughness = 0.95
			mat.uv1_scale = Vector3(4.0, 4.0, 1.0)
		"grass":
			mat.albedo_color = Color(0.19, 0.24, 0.14)
			mat.albedo_texture = _texture(91, 0.13)
			mat.normal_enabled = true
			mat.normal_texture = _texture(92, 0.22, true, 2.6)
			mat.roughness = 0.94
			mat.uv1_scale = Vector3(4.0, 4.0, 1.0)
		"foliage":
			mat.albedo_color = Color(0.13, 0.2, 0.11)
			mat.albedo_texture = _texture(93, 0.2)
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.roughness = 0.9
			mat.uv1_scale = Vector3(2.0, 2.0, 1.0)
		"glass":
			mat.albedo_color = Color(0.22, 0.26, 0.28, 0.28)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.metallic = 0.1
			mat.metallic_specular = 0.9
			mat.roughness = 0.06
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.uv1_scale = Vector3(1.0, 1.0, 1.0)
		"rubber":
			mat.albedo_color = Color(0.07, 0.07, 0.075)
			mat.roughness = 0.92
		"fabric":
			mat.albedo_color = Color(0.32, 0.31, 0.24)
			mat.albedo_texture = _texture(101, 0.18)
			mat.roughness = 0.95
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.uv1_scale = Vector3(2.0, 2.0, 1.0)
		"sandbag":
			mat.albedo_color = Color(0.42, 0.38, 0.27)
			mat.albedo_texture = _texture(111, 0.24)
			mat.normal_enabled = true
			mat.normal_texture = _texture(112, 0.3, true, 2.5)
			mat.roughness = 0.96
			mat.uv1_scale = Vector3(2.5, 2.5, 1.0)
		"brick":
			mat.albedo_color = Color(0.34, 0.19, 0.15)
			mat.albedo_texture = _texture(121, 0.14)
			mat.normal_enabled = true
			mat.normal_texture = _texture(122, 0.2, true, 3.0)
			mat.roughness = 0.9
			mat.uv1_scale = Vector3(2.0, 2.0, 1.0)
		"roof":
			mat.albedo_color = Color(0.2, 0.21, 0.21)
			mat.albedo_texture = _texture(131, 0.16)
			mat.roughness = 0.85
			mat.uv1_scale = Vector3(3.0, 3.0, 1.0)
		"puddle":
			mat.albedo_color = Color(0.11, 0.13, 0.15, 0.85)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.roughness = 0.05
			mat.metallic = 0.35
			mat.metallic_specular = 1.0
		"lamp":
			mat.albedo_color = Color(1.0, 0.88, 0.66)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.83, 0.55)
			mat.emission_energy_multiplier = 6.0
			mat.roughness = 0.4
		"lamp_cool":
			mat.albedo_color = Color(0.8, 0.9, 1.0)
			mat.emission_enabled = true
			mat.emission = Color(0.72, 0.86, 1.0)
			mat.emission_energy_multiplier = 5.0
		"alarm_light":
			mat.albedo_color = Color(1.0, 0.2, 0.15)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.18, 0.12)
			mat.emission_energy_multiplier = 4.0
		"screen":
			mat.albedo_color = Color(0.1, 0.2, 0.18)
			mat.emission_enabled = true
			mat.emission = Color(0.2, 0.75, 0.55)
			mat.emission_energy_multiplier = 2.5
			mat.roughness = 0.2
		"intel":
			mat.albedo_color = Color(0.85, 0.68, 0.2)
			mat.emission_enabled = true
			mat.emission = Color(0.95, 0.72, 0.2)
			mat.emission_energy_multiplier = 2.0
			mat.metallic = 0.6
			mat.roughness = 0.3
		"target":
			mat.albedo_color = Color(0.75, 0.72, 0.66)
			mat.roughness = 0.7
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
		"metal_panel", "rust", "crate_red", "crate_blue", "crate_green", "lamp", "lamp_cool":
			return "metal"
		"wood", "wood_plank":
			return "wood"
		"glass":
			return "glass"
		"dirt":
			return "dirt"
		"grass", "foliage":
			return "grass"
		"fabric", "sandbag", "brick":
			return "sandbag" if kind == "sandbag" else "concrete"
		_:
			return "concrete"
