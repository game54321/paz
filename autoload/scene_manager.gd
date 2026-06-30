extends Node

var pending_level_path: String = ""
var pending_level_index: int = -1

func enter_battle(level_path: String, level_index: int = -1) -> void:
	pending_level_path = level_path
	pending_level_index = level_index
	get_tree().change_scene_to_packed(preload("res://battle/main.tscn"))

func return_to_menu() -> void:
	get_tree().change_scene_to_file("res://main/main.tscn")
