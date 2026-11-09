extends Node
## Cold-start benchmark: run in a fresh process to measure a first map build
## with every procedural material generated from scratch.
##   godot --headless --path . res://tests/bench_cold.tscn

func _ready() -> void:
	var started := Time.get_ticks_msec()
	var result: Dictionary = Maps.build("industrial")
	var build_ms := Time.get_ticks_msec() - started
	var builder: WorldBuilder = result["builder"]
	add_child(builder)
	var merge_started := Time.get_ticks_msec()
	var stats: Dictionary = builder.merge_static_geometry()
	var merge_ms := Time.get_ticks_msec() - merge_started
	var mem := Performance.get_monitor(Performance.MEMORY_STATIC) / (1024.0 * 1024.0)
	print("COLD  industrial build %d ms   merge %d ms   material batches %d   verts %d   static memory %.0f MB" % [
		build_ms, merge_ms, int(stats["groups"]), int(stats["vertices"]), mem,
	])
	await get_tree().process_frame
	get_tree().quit(0)
