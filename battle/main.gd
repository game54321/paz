extends Control

@onready var level_host: Node2D = $LevelHost
@onready var grid_overlay = $GridOverlay
@onready var camera: Camera2D = $Camera2D
@onready var defeat_panel: Control = $DefeatLayer/DefeatPanel
@onready var retry_btn: Button = $DefeatLayer/DefeatPanel/RetryBtn
@onready var return_btn: Button = $DefeatLayer/DefeatPanel/ReturnBtn
@onready var victory_panel: CanvasLayer = $VictoryPanel

const BASE_SUNFLOWER_SCENE := preload("res://units/plants/基地向日葵.tscn")

var current_level: Node

func _center_camera_on_initial_lit(tile_map: TileMapLayer) -> void:
	# 把相机居中到开局默认点亮的左上角 5x5 区域中心。
	var used := tile_map.get_used_rect()
	# 5x5 中心 = used.position + (2.5, 2.5) 格（INITIAL_LIT_COLS/ROWS 的一半）。
	var center_cell_f := Vector2(used.position) + Vector2(
		float(PlacementManager.INITIAL_LIT_COLS) * 0.5,
		float(PlacementManager.INITIAL_LIT_ROWS) * 0.5
	)
	# map_to_local 接受 Vector2 浮点，转出地图本地坐标，再转世界坐标。
	var world_pos := tile_map.to_global(tile_map.map_to_local(center_cell_f))
	camera.global_position = world_pos
func _ready() -> void:
	PlacementManager.reset()                       # autoload 跨场景不清空，进战斗时保险清一次。
	retry_btn.pressed.connect(_on_retry)
	return_btn.pressed.connect(_on_return)
	victory_panel.return_pressed.connect(_on_return)
	var path := SceneManager.pending_level_path
	if path.is_empty():
		push_error("BattleMain: no pending level path.")
		return
	load_level(load(path))

func _process(_delta: float) -> void:
	# 胜利判定：基地未失 + zombie 组空（墓碑和真僵尸都死光）。
	if defeat_panel.visible or victory_panel.is_shown():
		return
	if get_tree().get_nodes_in_group("zombie").is_empty():
		# 取关卡掉落（关卡根节点挂 level_drops.gd 才有 get_drops）。
		var drops: Array = []
		if current_level != null and current_level.has_method("get_drops"):
			drops = current_level.get_drops()
		if SceneManager.pending_level_index >= 0:
			PlayerData.mark_level_cleared(SceneManager.pending_level_index)
		victory_panel.show_panel(drops)
	
func load_level(scene: PackedScene) -> void:
	if scene == null:
		push_error("BattleMain: level_scene is empty.")
		return

	if current_level != null:
		current_level.queue_free()
	print(scene)
	current_level = scene.instantiate()
	add_child(current_level)

	var tile_map := _find_tile_map_layer(current_level)
	if tile_map == null:
		push_error("BattleMain: level scene needs a TileMapLayer.")
		return

	grid_overlay.bind_tile_map(tile_map)           # 先 bind 视觉层，存好新 tile_map 并连信号。
	PlacementManager.bind_tile_map(tile_map)       # 再 bind manager，recompute 后 emit 信号，overlay 已能用新地图响应。
	_center_camera_on_initial_lit(tile_map)
	_spawn_base_sunflower(tile_map)

func _spawn_base_sunflower(tile_map: TileMapLayer) -> void:
	# 在地图左上角格子生成基地向日葵，注册到 PlacementManager 占格 + 点亮迷雾。
	var used := tile_map.get_used_rect()
	var base := BASE_SUNFLOWER_SCENE.instantiate()
	level_host.add_child(base)
	# 设 anchor_cell 让 register_plant 算占格，再按占格中心对齐位置（复用 plant_base._end_drag 逻辑）。
	PlacementManager.anchor_cell = used.position
	var cells := PlacementManager.register_plant(base)
	var center := Vector2.ZERO
	for c in cells:
		center += tile_map.to_global(tile_map.map_to_local(c))
	center /= cells.size()
	base.global_position = center
	base.base_destroyed.connect(_on_base_destroyed)

func _on_base_destroyed() -> void:
	defeat_panel.visible = true

func _on_retry() -> void:
	get_tree().reload_current_scene()

func _on_return() -> void:
	SceneManager.return_to_menu()

func _find_tile_map_layer(root: Node) -> TileMapLayer:
	if root is TileMapLayer:
		return root

	for child in root.get_children():
		var found := _find_tile_map_layer(child)
		if found != null:
			return found

	return null
