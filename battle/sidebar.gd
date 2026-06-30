extends Control

@onready var sun_count = $SunContainer/SunCount
const SEED_CARD_SCENE := preload("res://units/plants/seed_card.tscn")
const SEED_CARD_SCRIPT := preload("res://units/plants/seed_card.gd")
const CARD_SPACING_Y := 120.0                     # 卡片之间的垂直间距（像素）。
const CARD_START_Y := 50.0                        # 第一张卡片的 y 坐标。
const TILE_PX := 64.0                              # 每格像素，和 seed_card 缩放、tile_size 一致。
const CARD_PADDING_Y := 20.0                       # 卡片之间的额外留白（像素）。
func _ready() -> void:
	PlacementManager.sun_changed.connect(_on_sun_changed)
	_on_sun_changed()                              # 首次刷新。
	_refresh_cards()
func _on_sun_changed() -> void:
	sun_count.text = "%d" % PlacementManager.sun


func _refresh_cards() -> void:
	# 清掉旧卡片（tscn 里可能预放，统一动态生成）。

	# 从 PlayerData 读已解锁植物，生成卡片，按 y 堆叠。
	var y := CARD_START_Y
	for data in PlayerData.get_unlocked_plants():
		var def: Resource = data.get_def()         # PlantDef 静态配置。
		if def == null:
			continue
		var card := SEED_CARD_SCENE.instantiate()
		card.plant_scene = load(def.scene_path)
		card.display_name = def.display_name
		card.icon = def.icon
		card.star = data.star
		card.cost = def.cost
		card.size = def.size     
		card.level = data.level
		# 卡片是中心定位，左边对齐到 LEFT_X：position.x = LEFT_X + 半宽。
		const LEFT_X := -50.0
		card.position = Vector2(LEFT_X + SEED_CARD_SCRIPT.CARD_W * 0.5, y)
		$CardContainer.add_child(card)
		y += def.size.y * TILE_PX + SEED_CARD_SCRIPT.DESC_H + CARD_PADDING_Y
