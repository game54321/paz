extends Control
# 世界地图主界面：处理右下角"植物"按钮，点开后弹出植物面板。

const LEVEL_CARD_SCENE := preload("res://main/level_card.tscn")
const MOCK_LEVELS := [
	{"chapter": "序章", "name": "任家庄 上", "subtitle": "夜色降临，守住第一条街", "status": "可挑战", "locked": false, "level_path": "res://levels/任家庄上.tscn"},
	{"chapter": "序章", "name": "任家庄 中", "subtitle": "木门后传来低声响动", "status": "可挑战", "locked": false, "level_path": "res://levels/任家庄中.tscn"},
	{"chapter": "序章", "name": "任家庄 下", "subtitle": "杂草遮住了回家的路", "status": "可挑战", "locked": false, "level_path": "res://levels/任家庄下.tscn"},
]

@onready var plant_panel: Control = $PlantListPanel
@onready var system_panel: CanvasLayer = $SystemPanel
@onready  var level_card_grid: GridContainer =$LevelCardScroll/LevelCardGrid

func _ready() -> void:
	# PlantButton 按下时显示植物面板。
	$BottomButtons/PlantButton.pressed.connect(_on_plant_button_pressed)
	$BottomButtons/SystemButton.pressed.connect(_on_system_button_pressed)
	# 面板默认隐藏。
	plant_panel.close()
	system_panel.close()

	_create_mock_level_cards()

func _on_plant_button_pressed() -> void:
	plant_panel.open()

func _on_system_button_pressed() -> void:
	system_panel.open()


func _create_mock_level_cards() -> void:
	for child in level_card_grid.get_children():
		child.queue_free()

	for i in MOCK_LEVELS.size():
		var data = MOCK_LEVELS[i]
		var card := LEVEL_CARD_SCENE.instantiate()
		card.set("chapter_text", data["chapter"])
		card.set("location_name", data["name"])
		card.set("subtitle", data["subtitle"])
		card.set("status_text", data["status"])
		card.set("locked", not PlayerData.is_level_unlocked(i))
		card.set("level_index", i)
		card.set("level_path", data.get("level_path", ""))
		level_card_grid.add_child(card)
