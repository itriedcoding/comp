extends Node
## Procedural audio: synthesises every weapon, footstep, impact and ambience
## stream at boot so the build ships with no missing sound assets. Handles
## 3D positional playback, occlusion (raycast -> muffled bus) and reverb.

const RATE := 44100
const POOL_3D := 40
const POOL_2D := 10

var sounds: Dictionary = {}

var _pool3d: Array[AudioStreamPlayer3D] = []
var _pool2d: Array[AudioStreamPlayer] = []
var _ambience: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _sfx_reverb: AudioEffectReverb


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 90210
	_setup_buses()
	_build_all()
	apply_volumes()


func _setup_buses() -> void:
	for bus_name in ["SFX", "SFX_Occluded", "Ambience", "UI"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	var occluded := AudioServer.get_bus_index("SFX_Occluded")
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 1100.0
	lp.resonance = 0.4
	AudioServer.add_bus_effect(occluded, lp)
	var sfx := AudioServer.get_bus_index("SFX")
	for i in AudioServer.get_bus_effect_count(sfx):
		AudioServer.remove_bus_effect(sfx, 0)
	_sfx_reverb = AudioEffectReverb.new()
	_sfx_reverb.room_size = 0.35
	_sfx_reverb.damping = 0.55
	_sfx_reverb.wet = 0.08
	_sfx_reverb.dry = 1.0
	AudioServer.add_bus_effect(sfx, _sfx_reverb)
	for bus_name in ["SFX", "SFX_Occluded", "Ambience", "UI"]:
		AudioServer.set_bus_mute(AudioServer.get_bus_index(bus_name), false)


func apply_volumes() -> void:
	var master := clampf(float(Game.settings["master_volume"]), 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, master)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(0.0001, float(Game.settings["sfx_volume"]))))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX_Occluded"), linear_to_db(maxf(0.0001, float(Game.settings["sfx_volume"]))))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ambience"), linear_to_db(maxf(0.0001, float(Game.settings["ambience_volume"]))))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("UI"), linear_to_db(maxf(0.0001, float(Game.settings["ui_volume"]))))


func set_reverb(amount: float) -> void:
	if _sfx_reverb != null:
		_sfx_reverb.wet = clampf(amount, 0.0, 0.6)


# --------------------------------------------------------------- synthesis ---

func _wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32760.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = bytes
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples.size()
	return stream


func _buf(duration: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(maxi(1, int(duration * RATE)))
	return samples


func _noise(duration: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := _buf(duration)
	for i in out.size():
		out[i] = rng.randf_range(-1.0, 1.0)
	return out


func _lowpass(src: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(src.size())
	var a := 1.0 - exp(-TAU * cutoff / float(RATE))
	var y := 0.0
	for i in src.size():
		y += a * (src[i] - y)
		out[i] = y
	return out


func _highpass(src: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(src.size())
	var a := 1.0 - exp(-TAU * cutoff / float(RATE))
	var y := 0.0
	for i in src.size():
		y += a * (src[i] - y)
		out[i] = src[i] - y
	return out


func _envelope(src: PackedFloat32Array, attack: float, decay: float, power: float = 2.0) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(src.size())
	var attack_samples := maxf(1.0, attack * RATE)
	var decay_samples := maxf(1.0, decay * RATE)
	for i in src.size():
		var t := float(i)
		var a := clampf(t / attack_samples, 0.0, 1.0)
		var d := pow(clampf(1.0 - (t - attack_samples) / decay_samples, 0.0, 1.0), power)
		out[i] = src[i] * a * d
	return out


func _add_tone(dst: PackedFloat32Array, start: float, duration: float, f_start: float, f_end: float, amp: float, decay_power: float = 2.0) -> void:
	var start_i := int(start * RATE)
	var count := int(duration * RATE)
	var phase := 0.0
	for i in count:
		var idx := start_i + i
		if idx < 0 or idx >= dst.size():
			continue
		var t := float(i) / float(count)
		var freq := lerpf(f_start, f_end, t)
		phase += TAU * freq / float(RATE)
		var env := pow(1.0 - t, decay_power)
		dst[idx] += sin(phase) * amp * env


func _mix(dst: PackedFloat32Array, src: PackedFloat32Array, gain: float = 1.0) -> void:
	var n := mini(dst.size(), src.size())
	for i in n:
		dst[i] += src[i] * gain


func _normalize(src: PackedFloat32Array, peak: float = 0.9) -> PackedFloat32Array:
	var maxv := 0.0001
	for v in src:
		maxv = maxf(maxv, absf(v))
	var g := peak / maxv
	for i in src.size():
		src[i] = src[i] * g
	return src


func _softclip(src: PackedFloat32Array) -> PackedFloat32Array:
	for i in src.size():
		src[i] = tanh(src[i] * 1.4)
	return src


func _gunshot(base_freq: float, body_decay: float, rng: RandomNumberGenerator, bright: float = 1.0) -> AudioStreamWAV:
	var out := _buf(0.85)
	var crack := _envelope(_highpass(_noise(0.05, rng), 1800.0), 0.001, 0.05, 1.6)
	_mix(out, crack, 0.85)
	var body := _envelope(_lowpass(_noise(body_decay, rng), 2600.0 * bright), 0.001, body_decay, 2.4)
	_mix(out, body, 0.9)
	var tail := _envelope(_lowpass(_noise(0.6, rng), 900.0), 0.01, 0.55, 3.0)
	_mix(out, tail, 0.28)
	_add_tone(out, 0.0, 0.22, base_freq * 2.2, base_freq * 0.55, 0.55, 3.0)
	var delayed := _envelope(_lowpass(_noise(0.5, rng), 1400.0), 0.01, 0.45, 2.0)
	_mix(out, delayed, 0.12)
	_normalize(out, 0.92)
	return _wav(_softclip(out))


func _suppressed_shot(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var out := _buf(0.35)
	var thump := _envelope(_lowpass(_noise(0.22, rng), 1200.0), 0.001, 0.2, 2.6)
	_mix(out, thump, 0.7)
	_add_tone(out, 0.0, 0.12, 220.0, 90.0, 0.5, 2.6)
	var click := _envelope(_highpass(_noise(0.02, rng), 3000.0), 0.001, 0.02, 1.0)
	_mix(out, click, 0.18)
	_normalize(out, 0.55)
	return _wav(_softclip(out))


func _metallic(duration: float, base: float, rng: RandomNumberGenerator, noise_amp: float = 0.5) -> AudioStreamWAV:
	var out := _buf(duration)
	_mix(out, _envelope(_highpass(_noise(duration, rng), base), 0.001, duration, 2.0), noise_amp)
	_add_tone(out, 0.0, duration, base * 1.2, base * 0.9, 0.4, 3.0)
	_add_tone(out, 0.004, duration * 0.8, base * 1.9, base * 1.6, 0.2, 4.0)
	_normalize(out, 0.7)
	return _wav(_softclip(out))


func _impact(surface: String, rng: RandomNumberGenerator) -> AudioStreamWAV:
	match surface:
		"metal":
			var out := _buf(0.3)
			_mix(out, _envelope(_highpass(_noise(0.3, rng), 2500.0), 0.001, 0.28, 2.2), 0.5)
			_add_tone(out, 0.0, 0.25, 2400.0, 1700.0, 0.35, 3.5)
			_add_tone(out, 0.0, 0.18, 3600.0, 2600.0, 0.22, 4.0)
			_normalize(out, 0.65)
			return _wav(_softclip(out))
		"wood":
			var out := _buf(0.22)
			_mix(out, _envelope(_lowpass(_noise(0.22, rng), 1800.0), 0.001, 0.2, 2.4), 0.6)
			_add_tone(out, 0.0, 0.14, 420.0, 260.0, 0.4, 2.6)
			_normalize(out, 0.6)
			return _wav(_softclip(out))
		"glass":
			var out := _buf(0.4)
			for i in 5:
				var f := rng.randf_range(2400.0, 5200.0)
				_add_tone(out, rng.randf_range(0.0, 0.12), rng.randf_range(0.1, 0.3), f, f * 0.9, 0.18, 3.0)
			_mix(out, _envelope(_highpass(_noise(0.2, rng), 4000.0), 0.001, 0.18, 1.6), 0.3)
			_normalize(out, 0.6)
			return _wav(_softclip(out))
		"flesh":
			var out := _buf(0.2)
			var thud := _envelope(_lowpass(_noise(0.18, rng), 700.0), 0.001, 0.16, 2.2)
			_mix(out, thud, 0.7)
			_add_tone(out, 0.0, 0.1, 140.0, 70.0, 0.35, 2.4)
			_normalize(out, 0.55)
			return _wav(_softclip(out))
		_:
			var out := _buf(0.22)
			_mix(out, _envelope(_lowpass(_noise(0.2, rng), 1900.0), 0.001, 0.18, 2.2), 0.75)
			_add_tone(out, 0.0, 0.1, 210.0, 110.0, 0.22, 3.0)
			_normalize(out, 0.55)
			return _wav(_softclip(out))


func _footstep(surface: String, variant: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + variant * 97 + surface.hash()
	var out := _buf(0.18)
	match surface:
		"metal":
			_mix(out, _envelope(_highpass(_noise(0.16, rng), 1400.0), 0.002, 0.14, 2.0), 0.6)
			_add_tone(out, 0.0, 0.14, 900.0, 600.0, 0.25, 3.0)
			_add_tone(out, 0.0, 0.1, 1800.0, 1200.0, 0.12, 4.0)
		"grass":
			_mix(out, _envelope(_highpass(_noise(0.16, rng), 2200.0), 0.004, 0.14, 1.4), 0.55)
			_mix(out, _envelope(_lowpass(_noise(0.1, rng), 600.0), 0.002, 0.1, 2.0), 0.3)
		"dirt":
			_mix(out, _envelope(_lowpass(_noise(0.14, rng), 1400.0), 0.003, 0.12, 2.0), 0.6)
			_add_tone(out, 0.0, 0.08, 160.0, 90.0, 0.2, 2.5)
		"wood":
			_mix(out, _envelope(_lowpass(_noise(0.13, rng), 1700.0), 0.002, 0.11, 2.2), 0.55)
			_add_tone(out, 0.0, 0.1, 320.0, 220.0, 0.3, 2.6)
		_:
			_mix(out, _envelope(_lowpass(_noise(0.12, rng), 2400.0), 0.002, 0.1, 2.2), 0.6)
			_add_tone(out, 0.0, 0.07, 240.0, 140.0, 0.22, 2.6)
	_normalize(out, 0.5)
	return _wav(_softclip(out))


func _wind_loop() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1911
	var out := _lowpass(_noise(4.0, rng), 420.0)
	var gust := _lowpass(_noise(4.0, rng), 1200.0)
	for i in out.size():
		var t := float(i) / float(RATE)
		var lfo := 0.55 + 0.45 * sin(TAU * t / 4.0) * sin(TAU * t / 2.0 + 0.7)
		out[i] = (out[i] * 1.6 + gust[i] * 0.35) * lfo
	return _wav(_normalize(out, 0.45), true)


func _hum_loop() -> AudioStreamWAV:
	var out := _buf(4.0)
	_add_tone(out, 0.0, 4.0, 60.0, 60.0, 0.35, 0.0)
	_add_tone(out, 0.0, 4.0, 120.0, 120.0, 0.12, 0.0)
	_add_tone(out, 0.0, 4.0, 181.0, 179.0, 0.05, 0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	_mix(out, _lowpass(_noise(4.0, rng), 260.0), 0.12)
	return _wav(_normalize(out, 0.3), true)


func _rain_loop() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7777
	var out := _highpass(_noise(4.0, rng), 900.0)
	out = _lowpass(out, 6500.0)
	return _wav(_normalize(out, 0.32), true)


func _build_all() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	sounds["shot_rifle"] = _gunshot(120.0, 0.3, rng, 1.0)
	sounds["shot_smg"] = _gunshot(150.0, 0.22, rng, 1.15)
	sounds["shot_dmr"] = _gunshot(90.0, 0.42, rng, 0.82)
	sounds["shot_shotgun"] = _gunshot(70.0, 0.5, rng, 0.7)
	sounds["shot_pistol"] = _gunshot(170.0, 0.18, rng, 1.25)
	sounds["shot_suppressed"] = _suppressed_shot(rng)
	sounds["dry_fire"] = _metallic(0.07, 2600.0, rng, 0.35)
	sounds["mag_out"] = _metallic(0.13, 1500.0, rng, 0.45)
	sounds["mag_in"] = _metallic(0.11, 900.0, rng, 0.4)
	sounds["bolt"] = _metallic(0.16, 2100.0, rng, 0.4)
	sounds["shell_drop"] = _metallic(0.2, 3200.0, rng, 0.35)
	sounds["pump"] = _metallic(0.24, 1200.0, rng, 0.55)
	sounds["draw"] = _metallic(0.2, 1800.0, rng, 0.3)
	for surface in ["concrete", "metal", "wood", "dirt", "grass"]:
		for v in 3:
			sounds["foot_%s_%d" % [surface, v]] = _footstep(surface, v)
	for surface in ["concrete", "metal", "wood", "glass", "flesh", "dirt"]:
		sounds["impact_%s" % surface] = _impact(surface, rng)
	# UI
	var click := _buf(0.06)
	_add_tone(click, 0.0, 0.06, 1500.0, 900.0, 0.4, 3.0)
	_mix(click, _envelope(_highpass(_noise(0.02, rng), 2600.0), 0.001, 0.02, 1.0), 0.2)
	sounds["ui_click"] = _wav(_normalize(click, 0.5))
	var hover := _buf(0.04)
	_add_tone(hover, 0.0, 0.04, 2200.0, 1800.0, 0.25, 3.0)
	sounds["ui_hover"] = _wav(_normalize(hover, 0.35))
	var hit := _buf(0.09)
	_add_tone(hit, 0.0, 0.05, 2600.0, 2400.0, 0.4, 4.0)
	_add_tone(hit, 0.035, 0.05, 3100.0, 2900.0, 0.3, 4.0)
	sounds["hitmarker"] = _wav(_normalize(hit, 0.55))
	var head := _buf(0.14)
	_add_tone(head, 0.0, 0.08, 1900.0, 1700.0, 0.4, 3.0)
	_add_tone(head, 0.05, 0.08, 2500.0, 2200.0, 0.3, 3.0)
	sounds["headshot"] = _wav(_normalize(head, 0.6))
	var dmg := _buf(0.3)
	_mix(dmg, _envelope(_lowpass(_noise(0.3, rng), 700.0), 0.001, 0.28, 1.8), 0.7)
	_add_tone(dmg, 0.0, 0.2, 120.0, 60.0, 0.4, 2.4)
	sounds["damage"] = _wav(_normalize(dmg, 0.7))
	sounds["kill"] = _wav(_normalize(_envelope(_lowpass(_noise(0.3, rng), 1200.0), 0.001, 0.28, 2.0), 0.6))
	var wave := _buf(1.2)
	_add_tone(wave, 0.0, 0.9, 110.0, 55.0, 0.5, 2.2)
	_add_tone(wave, 0.0, 0.5, 330.0, 220.0, 0.2, 2.6)
	_mix(wave, _envelope(_lowpass(_noise(0.4, rng), 900.0), 0.01, 0.35, 2.0), 0.25)
	sounds["wave_start"] = _wav(_normalize(wave, 0.7))
	var alarm := _buf(1.0)
	for i in 2:
		_add_tone(alarm, i * 0.5, 0.35, 780.0, 780.0, 0.35, 1.4)
	sounds["alarm"] = _wav(_normalize(alarm, 0.6))
	var rank := _buf(0.5)
	_add_tone(rank, 0.0, 0.25, 660.0, 660.0, 0.25, 2.0)
	_add_tone(rank, 0.15, 0.3, 990.0, 990.0, 0.22, 2.0)
	sounds["rank_up"] = _wav(_normalize(rank, 0.6))
	sounds["wind_loop"] = _wind_loop()
	sounds["hum_loop"] = _hum_loop()
	sounds["rain_loop"] = _rain_loop()
	# Pre-size pools.
	for i in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.bus = "SFX"
		p.unit_size = 7.0
		p.max_distance = 120.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
		p.panning_strength = 1.4
		p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
		add_child(p)
		_pool3d.append(p)
	for i in POOL_2D:
		var p := AudioStreamPlayer.new()
		p.bus = "UI"
		add_child(p)
		_pool2d.append(p)
	for id in ["wind_loop", "hum_loop", "rain_loop"]:
		var amb := AudioStreamPlayer.new()
		amb.bus = "Ambience"
		amb.stream = sounds[id]
		amb.volume_db = -60.0
		add_child(amb)
		_ambience[id] = amb


# --------------------------------------------------------------- playback ---

func stream(id: String) -> AudioStream:
	return sounds.get(id, null)


func play_3d(id: String, position: Vector3, volume_db: float = 0.0, pitch: float = 1.0, max_distance: float = 90.0) -> AudioStreamPlayer3D:
	var p := _free_3d()
	if p == null:
		return null
	var s = sounds.get(id, null)
	if s == null:
		return null
	p.stream = s
	p.global_position = position
	p.volume_db = volume_db
	p.pitch_scale = clampf(pitch, 0.6, 1.6)
	p.max_distance = max_distance
	var occluded := _is_occluded(position)
	p.bus = "SFX_Occluded" if occluded else "SFX"
	if occluded:
		p.volume_db -= 5.0
	p.play()
	return p


func play_ui(id: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var s = sounds.get(id, null)
	if s == null:
		return
	for p in _pool2d:
		if not p.playing:
			p.stream = s
			p.volume_db = volume_db
			p.pitch_scale = pitch
			p.play()
			return


func play_at_ui_position(id: String, volume_db: float = 0.0) -> void:
	play_ui(id, volume_db)


func _free_3d() -> AudioStreamPlayer3D:
	for p in _pool3d:
		if not p.playing:
			return p
	# Steal the quietest one.
	var quietest: AudioStreamPlayer3D = _pool3d[0]
	for p in _pool3d:
		if p.volume_db < quietest.volume_db:
			quietest = p
	quietest.stop()
	return quietest


func _is_occluded(position: Vector3) -> bool:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null:
		return false
	var space := camera.get_world_3d().direct_space_state
	if space == null:
		return false
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, position, 1)
	query.hit_from_inside = false
	var hit := space.intersect_ray(query)
	return not hit.is_empty()


func footstep(surface: String, position: Vector3, loud: float = 1.0) -> void:
	var variants := 3
	var idx := _rng.randi_range(0, variants - 1)
	play_3d("foot_%s_%d" % [surface, idx], position, linear_to_db(loud), _rng.randf_range(0.9, 1.1), 30.0)


func impact(surface: String, position: Vector3) -> void:
	var id := "impact_%s" % surface
	if not sounds.has(id):
		id = "impact_concrete"
	play_3d(id, position, -2.0, _rng.randf_range(0.92, 1.08), 45.0)


func gunshot(weapon_stats: Dictionary, position: Vector3, suppressed: bool) -> void:
	var id := "shot_suppressed" if suppressed else String(weapon_stats.get("sound", "shot_rifle"))
	play_3d(id, position, 0.0 if not suppressed else -6.0, _rng.randf_range(0.96, 1.04), 140.0)


func set_ambience(preset: String, rain: bool = false, indoor: bool = false) -> void:
	var targets := {"wind_loop": -9.0, "hum_loop": -60.0, "rain_loop": -60.0}
	match preset:
		"industrial":
			targets["hum_loop"] = -18.0
			targets["wind_loop"] = -20.0
		"urban":
			targets["hum_loop"] = -22.0
			targets["wind_loop"] = -18.0
		"outpost":
			targets["wind_loop"] = -8.0
			targets["hum_loop"] = -60.0
	if rain:
		targets["rain_loop"] = -14.0
	if indoor:
		targets["wind_loop"] = float(targets["wind_loop"]) - 8.0
	for id in _ambience.keys():
		var p: AudioStreamPlayer = _ambience[id]
		if not p.playing:
			p.play()
		var tw := create_tween()
		tw.tween_property(p, "volume_db", float(targets[id]), 1.5)


func stop_ambience() -> void:
	for p in _ambience.values():
		p.stop()
