extends Node
# 放置管理器（autoload 单例）：承担所有"格子-植物"业务逻辑。
# grid_map（视觉层）和 plant_base（输入层）通过它交互，互不直接通信。
# 状态生命周期：autoload 跨场景不清空，main.gd._ready 调 reset() 保险清一次，
# bind_tile_map 时也 reset 一次。


# ── 信号 ──────────────────────────────────────────────────────────────
signal fog_dirty       # 迷雾数据变化（植物增删/拖拽状态变），grid_map 听到后重算 shader
signal highlight_dirty # 放置预览变化（鼠标移动/size 变），grid_map 听到后重绘高亮
signal sun_changed     # 灵气数变化，HUD 听到后刷新显示

# ── 灵气经济常量 ──────────────────────────────────────────────────────
const INITIAL_SUN := 50           # 开局灵气数。


# ── 迷雾逻辑常量（从 grid_map.gd 搬过来） ────────────────────────────
const FOG_REVEAL_SIZE := 10.0     # 每个向日葵以中心为准点亮 10x10 的正方形区域。
const INITIAL_LIT_COLS := 5       # 开局默认点亮左上角 5x5 格子的宽。
const INITIAL_LIT_ROWS := 5       # 开局默认点亮左上角 5x5 格子的高。
const NOISE_AMP := 0.45           # 迷雾边缘噪声振幅（视觉用，但 seed 在这里算）。
const INITIAL_EDGE_SEED := 4.91   # 默认亮区右边缘的噪声种子。


# ── 状态字段 ──────────────────────────────────────────────────────────
var tile_map: TileMapLayer                              # 当前关卡的 TileMapLayer，由 main.gd bind 注入。
var occupied_cells: Dictionary = {}                     # 已占用格子 -> 占它的植物节点。
var plant_cells: Dictionary = {}                        # 植物节点 -> 它占的所有格子（2x2 就是 4 格）。
var lit_cells: Dictionary = {}                          # 已点亮的格子集合（key 是 Vector2i，value 为 true）。
var fog_blobs: Array[Vector4] = []                      # 视觉用：每个向日葵视野（xy 中心, z 边长, w seed）。
var active_cells: Array[Vector2i] = []                  # 当前放置预览覆盖的格子。
var active_valid: bool = true                           # 当前放置预览是否全部合法。
var anchor_cell: Vector2i = Vector2i(-9999, -9999)      # 当前预览的锚点格子，远值表示无效。
var dragging_plant: Node = null                         # 当前正在拖拽的植物节点，null 表示没在拖。seed_card 用它判断能否再 spawn。
var sun: int = INITIAL_SUN                              # 当前灵气数，阿葵产 + 种植消耗。
var _last_card_center_x: float = NAN                    # 上次卡片中心 x，用于判断左右移动方向，NAN 表示首次。
var _last_card_center_y: float = NAN                    # 上次卡片中心 y，用于判断上下移动方向，NAN 表示首次。
var _drag_dir_left: bool = true                         # 上次水平移动方向，true=左移用左边缘。首帧/静止保持。
var _drag_dir_up: bool = true                           # 上次垂直移动方向，true=上移用上边缘。首帧/静止保持。

const EDGE_TOLERANCE := 0.333333                        # 边缘咬格容错:边缘进入新格超过此比例(1/3 格)才算落入,避免边界抖动。


# ── 外部 API ──────────────────────────────────────────────────────────

func bind_tile_map(p_tile_map: TileMapLayer) -> void:   # main.gd 加载关卡后调用，注入 TileMapLayer。
	reset()                                              # 切关卡时清空旧状态（双保险）。
	tile_map = p_tile_map
	_recompute_targets()                                 # 立刻算一次哪些格子亮。
	fog_dirty.emit()                                     # 通知 grid_map 首次绘制迷雾。

func reset() -> void:                                   # 清空所有状态，autoload 跨场景时由 main.gd._ready 调。
	occupied_cells.clear()
	plant_cells.clear()
	lit_cells.clear()
	fog_blobs.clear()
	active_cells.clear()
	active_valid = true
	anchor_cell = Vector2i(-9999, -9999)
	dragging_plant = null
	_last_card_center_x = NAN
	_last_card_center_y = NAN
	_drag_dir_left = true
	_drag_dir_up = true
	sun = INITIAL_SUN
	sun_changed.emit()

func update_highlight(card_center_global: Vector2) -> void: # 拖拽中卡片中心移动时调。X/Y 均按移动方向用对应边缘咬格,带 1/4 格容错。
	if not tile_map:                                     # 还没 bind,不能做坐标换算。
		return
	var psize: Vector2i = dragging_plant.size            # 从当前拖拽植物读尺寸。
	var ts: Vector2 = Vector2(tile_map.tile_set.tile_size)
	var half_w: float = psize.x * ts.x * 0.5             # 卡片视觉半宽(像素)。
	var half_h: float = psize.y * ts.y * 0.5             # 卡片视觉半高(像素)。
	var local_center := tile_map.to_local(card_center_global)
	# 判定水平方向:右移 → 右边缘咬格,左移/静止保持 → 左边缘咬格。
	if not is_nan(_last_card_center_x):
		if card_center_global.x > _last_card_center_x:
			_drag_dir_left = false
		elif card_center_global.x < _last_card_center_x:
			_drag_dir_left = true
	# 判定垂直方向:下移 → 下边缘咬格,上移/静止保持 → 上边缘咬格。
	if not is_nan(_last_card_center_y):
		if card_center_global.y > _last_card_center_y:
			_drag_dir_up = false
		elif card_center_global.y < _last_card_center_y:
			_drag_dir_up = true
	# X 方向锚点:左移用左边缘,右移用右边缘;各加 1/4 格容错(进入新格超过 1/4 才算落入)。
	var anchor_x: int
	if _drag_dir_left:
		var local_left := local_center.x - half_w
		anchor_x = int(floor((local_left + EDGE_TOLERANCE * ts.x) / ts.x))
	else:
		var local_right := local_center.x + half_w
		var right_cell := int(floor((local_right - EDGE_TOLERANCE * ts.x) / ts.x))
		anchor_x = right_cell - (psize.x - 1)
	# Y 方向锚点:上移用上边缘,下移用下边缘;各加 1/4 格容错。
	var anchor_y: int
	if _drag_dir_up:
		var local_top := local_center.y - half_h
		anchor_y = int(floor((local_top + EDGE_TOLERANCE * ts.y) / ts.y))
	else:
		var local_bottom := local_center.y + half_h
		var bottom_cell := int(floor((local_bottom - EDGE_TOLERANCE * ts.y) / ts.y))
		anchor_y = bottom_cell - (psize.y - 1)
	anchor_cell = Vector2i(anchor_x, anchor_y)
	_last_card_center_x = card_center_global.x
	_last_card_center_y = card_center_global.y
	_recompute_active()                                  # 重算预览覆盖的格子。
	highlight_dirty.emit()                               # 通知 grid_map 重绘高亮。

func clear_highlight() -> void:                         # 取消放置预览。
	active_cells.clear()
	anchor_cell = Vector2i(-9999, -9999)
	_last_card_center_x = NAN
	_last_card_center_y = NAN
	highlight_dirty.emit()

func register_plant(plant: Node) -> Array[Vector2i]: # 植物落地时由 plant_base 调。cells 由 manager 用当前 anchor + dragging_plant.size 算（必须在 clear_highlight 之前调）。
	var cells: Array[Vector2i] = []
	var psize: Vector2i = plant.size                     # 从植物自身读尺寸（2x2、3x3 都行）。
	for y in psize.y:                                    # 遍历形状高度。
		for x in psize.x:                                # 遍历形状宽度。
			cells.append(anchor_cell + Vector2i(x, y))   # 从当前预览锚点推出每格。
	plant_cells[plant] = cells                           # 记录植物占的格子。
	for c in cells:                                      # 反向映射：每格 -> 植物。
		occupied_cells[c] = plant
	_recompute_targets()                                # 植物增减后重算迷雾。
	fog_dirty.emit()
	return cells                                         # 返回算好的 cells，供 plant 摆视觉位用。

func unregister_plant(plant: Node) -> void:             # 植物被移除时调（死亡/被铲走）。
	if not plant_cells.has(plant):                       # 没注册过（僵尸/拖拽中没落地的植物），直接跳过。
		return
	var cells: Array = plant_cells.get(plant, [])
	for c in cells:                                      # 清掉反向映射。
		occupied_cells.erase(c)
	plant_cells.erase(plant)
	_recompute_targets()                                # 植物增减后重算迷雾。
	fog_dirty.emit()

func is_lit(cell: Vector2i) -> bool:                    # 判断某格子是否已点亮（外部查询用）。
	return lit_cells.has(cell)

func is_cell_placeable(cell: Vector2i) -> bool:         # 判断单格能否放置植物。
	if not tile_map:                                     # 没 bind 地图。
		return false
	if tile_map.get_cell_source_id(cell) == -1:          # TileMap 这位置没地块。
		return false
	if not is_lit(cell):                                 # 不在已点亮区内。
		return false
	if occupied_cells.has(cell):                         # 已被其他植物占用。
		return false
	return true

func get_active_cells() -> Array[Vector2i]:             # grid_map 画高亮用。
	return active_cells

func is_active_valid() -> bool:                         # grid_map 选高亮颜色用。
	return active_valid

func get_fog_blobs() -> Array[Vector4]:                 # grid_map 喂 shader 用。
	return fog_blobs

func get_tile_map() -> TileMapLayer:                    # plant_base 落地摆视觉中心用。
	return tile_map


# ── 灵气经济 API ──────────────────────────────────────────────────────

func add_sun(amount: int) -> void:                      # 加灵气（灵气球飞入 HUD 时调）。
	sun += amount
	sun_changed.emit()

func can_afford(cost: int) -> bool:                     # 判断能否种某植物。
	return sun >= cost

func spend_sun(cost: int) -> bool:                      # 扣灵气，不够返回 false（种植时调）。
	if sun < cost:
		return false
	sun -= cost
	sun_changed.emit()
	return true


# ── 内部：放置预览合法性 ──────────────────────────────────────────────

func _recompute_active() -> void:                       # 重算当前预览区域是否合法。
	active_cells.clear()
	active_valid = true
	if dragging_plant == null:                           # 没在拖，没法读 size。
		return
	var psize: Vector2i = dragging_plant.size            # 从当前拖拽植物读尺寸。
	for y in psize.y:                                    # 遍历放置物高度范围。
		for x in psize.x:                                # 遍历放置物宽度范围。
			var cell := anchor_cell + Vector2i(x, y)     # 当前被占的格子。
			active_cells.append(cell)
			if not is_cell_placeable(cell):              # 任一格非法，整个区域非法。
				active_valid = false


# ── 内部：迷雾点亮逻辑 ────────────────────────────────────────────────

func _recompute_targets() -> void:                      # 重算哪些格子被点亮 + 同步 fog_blobs。
	lit_cells.clear()
	fog_blobs.clear()
	if not tile_map:                                     # 没 bind 地图直接退出。
		return

	var used := tile_map.get_used_rect()                 # TileMap 实际使用范围，避免遍历无限地图。

	# 从已落地的植物算每个视野的中心，2x2 中心从 4 格求几何中心（不再用 global_position 反推）。
	for plant in plant_cells:
		if plant == dragging_plant:                     # 拖拽中的植物不提供视野。
			continue
		if not plant.get("provides_vision"):            # 只有向日葵等带视野的植物才点亮迷雾。
			continue
		var cells: Array = plant_cells[plant]
		if cells.is_empty():
			continue
		var min_c: Vector2i = cells[0]                   # 4 格的左上角。
		var max_c: Vector2i = cells[0]                   # 4 格的右下角。
		for c in cells:
			min_c.x = min(min_c.x, c.x)
			min_c.y = min(min_c.y, c.y)
			max_c.x = max(max_c.x, c.x)
			max_c.y = max(max_c.y, c.y)
		# 几何中心 = (min + max) / 2 + 0.5；对 2x2: (ax + ax+1)/2 + 0.5 = ax + 1。
		var center := Vector2(min_c.x + max_c.x, min_c.y + max_c.y) * 0.5 + Vector2(0.5, 0.5)
		var seed := _noise(Vector2i(int(center.x), int(center.y))) * 10.0 + (center.x - center.y) * 0.37
		fog_blobs.append(Vector4(center.x, center.y, FOG_REVEAL_SIZE, seed))

	# 标记每个格子是否点亮（业务层判定，供 is_cell_placeable 用）。
	for y in range(used.position.y, used.end.y):
		for x in range(used.position.x, used.end.x):
			var cell := Vector2i(x, y)
			if _is_cell_logic_lit(cell, used):
				lit_cells[cell] = true
	# 默认亮区强制再标一次（_is_cell_logic_lit 已含此判断，这里冗余但和原逻辑一致）。
	for y in range(used.position.y, used.position.y + INITIAL_LIT_ROWS):
		for x in range(used.position.x, used.position.x + INITIAL_LIT_COLS):
			lit_cells[Vector2i(x, y)] = true

func _is_cell_logic_lit(cell: Vector2i, used: Rect2i) -> bool: # 业务层判断格子是否点亮。
	if cell.x < used.position.x + INITIAL_LIT_COLS and cell.y < used.position.y + INITIAL_LIT_ROWS:     # 左上角 5x5 默认亮区。
		return true
	var p := Vector2(cell.x + 0.5, cell.y + 0.5)        # 用格子中心点参与 10x10 判断。
	for blob in fog_blobs:
		var half_size := blob.z * 0.5                    # 5 格半宽。
		if absf(p.x - blob.x) <= half_size and absf(p.y - blob.y) <= half_size:
			return true
	return false

func _is_grid_pos_lit(grid_pos: Vector2, used: Rect2i) -> bool: # 像素级判定（未来不规则边缘用，目前未调）。
	var initial_edge := float(used.position.x + INITIAL_LIT_COLS) + _edge_noise(grid_pos.y, INITIAL_EDGE_SEED) * NOISE_AMP
	if grid_pos.x < initial_edge:
		return true
	for blob in fog_blobs:
		var center := Vector2(blob.x, blob.y)
		var d := grid_pos - center
		var half_size := blob.z * 0.5
		var x_limit := half_size + _edge_noise(grid_pos.y, blob.w) * NOISE_AMP
		var y_limit := half_size + _edge_noise(grid_pos.x, blob.w + 8.13) * NOISE_AMP
		if absf(d.x) <= x_limit and absf(d.y) <= y_limit:
			return true
	return false


# ── 内部：噪声（给迷雾边缘抖动用，seed 在 _recompute_targets 里算） ───

func _noise(cell: Vector2i) -> float:                   # 整数格子的伪随机噪声，返回 -1~1。
	var h: int = (cell.x * 73856093) ^ (cell.y * 19349663)
	return fmod(abs(float(h)) * 0.001, 2.0) - 1.0

func _edge_noise(v: float, p_seed: float) -> float:     # 多频正弦叠加的边缘噪声，和 shader 里 edge_noise 对应。
	return (
		sin(v * 0.53 + p_seed)
		+ sin(v * 1.17 + p_seed * 1.71) * 0.5
		+ sin(v * 2.31 + p_seed * 0.37) * 0.25
	) / 1.75
