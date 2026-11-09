extends Node
## Application bootstrap: swaps between the main menu and a running game mode.

var menu: Menu
var mode: GameMode


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.request_run.connect(_on_request_run)
	Game.request_menu.connect(_show_menu)
	_show_menu()


func _clear() -> void:
	get_tree().paused = false
	if mode != null and is_instance_valid(mode):
		mode.queue_free()
		mode = null
	if menu != null and is_instance_valid(menu):
		menu.queue_free()
		menu = null


func _show_menu() -> void:
	_clear()
	Audio.stop_ambience()
	menu = Menu.new()
	menu.name = "Menu"
	menu.start_requested.connect(_on_menu_start)
	add_child(menu)
	Game.capture_mouse(false)


func _on_menu_start(mode_id: String, mission_id: String, options: Dictionary) -> void:
	Game.settings["difficulty"] = String(options.get("difficulty", Game.settings["difficulty"]))
	Game.save_settings()
	Game.start_run(mode_id, mission_id, options)


func _on_request_run(mode_id: String, mission_id: String, options: Dictionary) -> void:
	_clear()
	if menu != null and is_instance_valid(menu):
		menu.queue_free()
		menu = null
	mode = create_mode(mode_id)
	mode.name = "GameMode"
	add_child(mode)
	mode.start_run(options)


func create_mode(mode_id: String) -> GameMode:
	match mode_id:
		"survival":
			return SurvivalMode.new()
		"training":
			return TrainingMode.new()
		"tactical":
			return TacticalMode.new()
		"botmatch":
			return BotMatchMode.new()
		_:
			return CampaignMode.new()
