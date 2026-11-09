class_name CampaignMode
extends GameMode
## Story operations: sequential objectives, checkpoints and mission unlocks.


func _prepare() -> void:
	mission = GameData.mission(mission_id if mission_id != "" else "m1")
	mission_id = String(mission["id"])
	map_id = String(mission["map"])
	mode_title = String(mission["name"])


func _finish_title(victory: bool) -> String:
	return "OPERATION COMPLETE" if victory else "OPERATION FAILED"


func _hud_score_text() -> String:
	return "KILLS %d   ACCURACY %.0f%%" % [kills, Game.accuracy() * 100.0]


func _result_stats() -> Array:
	var stats: Array = super._result_stats()
	stats.insert(1, {"label": "Location", "value": String(mission.get("location", ""))})
	return stats


func _continue_label() -> String:
	if GameData.mission_index(mission_id) < GameData.MISSIONS.size() - 1:
		return "NEXT OPERATION"
	return "MAIN MENU"


func _continue_after_results() -> void:
	var index := GameData.mission_index(mission_id)
	if index >= 0 and index + 1 < GameData.MISSIONS.size():
		var next_id := String(GameData.MISSIONS[index + 1]["id"])
		Game.start_run("campaign", next_id, {})
	else:
		Game.return_to_menu()
