extends "res://units/unit_base.gd"
# 植物基类（纯输入 + 拖拽）：继承 unit_base（血量/血条/受击），不持有 grid_map 引用。
# 所有放置逻辑走 PlacementManager 单例。
# 是否在拖由 PlacementManager.dragging_plant == self 判断，植物自身不存 dragging 状态。
# is_enemy 默认 false，unit_base._ready 会把节点加进 "plant" 组。

@export var provides_vision := false 
var drag_offset = Vector2.ZERO
var size = Vector2i(2,2)                          # 占几格，2x2。
var occupied_cells: Array[Vector2i] = []          # 落地后占的格子，由 _end_drag 写入并 register 给 manager。
# 呼吸感参数：周期性轻微缩放 + 左右摇晃，模拟植物大战僵尸里植物的呼吸。
const BREATHE_PERIOD := 2.5                       # 呼吸周期（秒）。
const BREATHE_SCALE_AMP := 0.04                   # 缩放幅度（4%）。
const SWAY_AMP := 0.02                            # 摇晃角度幅度（弧度，约 3°）。
const SWAY_PERIOD := 3.0                          # 摇晃周期（秒），比缩放稍慢，不同步更自然。
var _breathe_phase := 0.0                         # 相位偏移，_ready 时按位置随机化，避免所有植物同步呼吸。
var _time := 0.0                                  # 累计时间，喂给 sin 算呼吸和摇晃。
var _base_scale := Vector2.ONE 
var cost: int = 0    

# 射程高亮颜色。
const RANGE_FILL := Color(0.3, 0.6, 1.0, 0.12)    # 半透明蓝填充。
const RANGE_BORDER := Color(0.3, 0.6, 1.0, 0.8)   # 不透明蓝边框。

var attack_range: float = 0.0                     # 攻击射程（格子数），0 = 不攻击。_ready 从 PlantDef 读。
var attack_range_px: float = 0.0                  # 攻击射程（像素），_ready 时 attack_range × tile_size 算出。
var attack_speed_mult: float = 1.0                # 攻速倍率，_ready 从 PlantData 读，词条加成后 >1.0。
var base_attack_interval: float = 0.0             # 基础攻击间隔（秒），0 = 无周期攻击。_ready 从 PlantDef 读。
var _show_range: bool = false                    # 是否当前要画射程圆（拖拽中或鼠标悬停时为 true）。


func _ready() -> void:
	super._ready()
	var def: Resource = PlantTable.get_def_by_scene_path(scene_file_path)
	if def != null:
		cost = def.cost
		base_attack_interval = def.base_attack_interval
		# 射程/血量/攻速走 PlantData 派生属性（词条加成）；没有养成数据时回退到 PlantDef 静态值。
		var plant_data: Resource = PlayerData.get_plant(def.id)
		if plant_data != null:
			attack_range = plant_data.get_range()
			max_hp = plant_data.get_max_hp()
			hp = max_hp
			attack_speed_mult = plant_data.get_attack_speed()
		else:
			attack_range = def.attack_range
			max_hp = def.base_hp
			hp = max_hp
			attack_speed_mult = 1.0
	var tm := PlacementManager.get_tile_map()
	if tm != null and attack_range > 0.0:
		attack_range_px = attack_range * tm.tile_set.tile_size.x
	# 用全局位置哈希出 0~2π 的相位偏移，让每株植物呼吸节奏错开，不整齐划一。
	_breathe_phase = fmod(abs(float(hash(global_position)) * 0.001), TAU)
	_update_base_scale()
func _update_base_scale() -> void:
	if sprite == null or sprite.texture == null:
		return
	var tm := PlacementManager.get_tile_map()
	if tm == null:
		return
	var tile_size := Vector2(tm.tile_set.tile_size)
	var target :Vector2= Vector2(size) * tile_size
	var tex_size := Vector2(sprite.texture.get_size())
	# 非等比缩放,贴图填满占格(可能变形)。
	var sx :float= target.x / max(tex_size.x, 1.0)
	var sy :float= target.y / max(tex_size.y, 1.0)
	_base_scale = Vector2(sx, sy)
	sprite.scale = _base_scale
func _process(delta: float) -> void:
	super._process(delta)                            # unit_base._process 调 queue_redraw 刷血条。
	_update_show_range()
	if PlacementManager.dragging_plant == self:      # 拖拽中不呼吸，避免抖动干扰放置预览。
		return
	_time += delta
	# 缩放：基础缩放 × 呼吸胀缩。
	var s := 1.0 + sin(_time / BREATHE_PERIOD * TAU + _breathe_phase) * BREATHE_SCALE_AMP
	# 摇晃：左右小角度摆动，模拟脑袋晃。用稍慢的周期 + 不同相位，和缩放错开。
	var r := sin(_time / SWAY_PERIOD * TAU + _breathe_phase * 1.3) * SWAY_AMP
	sprite.scale = _base_scale * s
	sprite.rotation = r

func _update_show_range() -> void:
	# 拖拽中或鼠标悬停在植物占格上时显示射程圆。
	if attack_range_px <= 0.0:
		_show_range = false
		return
	if PlacementManager.dragging_plant == self:
		_show_range = true
		return
	_show_range = _is_mouse_over()

func _is_mouse_over() -> bool:
	var tm := PlacementManager.get_tile_map()
	if tm == null:
		return false
	var tile_size := Vector2(tm.tile_set.tile_size)
	var half := Vector2(size) * tile_size * 0.5
	var mp := get_global_mouse_position()
	var p := global_position
	return abs(mp.x - p.x) <= half.x and abs(mp.y - p.y) <= half.y
func _draw() -> void:
	super._draw()                                   # 保留 unit_base 画的血条。
	# 射程高亮：圆形，中心是植物本地坐标原点（Vector2.ZERO），半径 attack_range_px 像素。
	if _show_range and attack_range_px > 0.0:
		draw_circle(Vector2.ZERO, attack_range_px, RANGE_FILL)
		draw_arc(Vector2.ZERO, attack_range_px, 0.0, TAU, 48, RANGE_BORDER, 2.0)

func _input(event: InputEvent) -> void:
	if PlacementManager.dragging_plant != self:    # 不是自己被拖，忽略输入。
		return
	if InputUtil.is_left_click_blur(event):
		_end_drag()
	elif InputUtil.is_motion(event):
		visible = true
		global_position = get_global_mouse_position() - drag_offset
		z_index = ZIndex.PLANT_DRAGGING
		PlacementManager.update_highlight(global_position)  # 以卡片中心评定落点,而非鼠标位置。

func start_drag() -> void:                        # seed_card 调用，开始拖拽。
	PlacementManager.dragging_plant = self        # 全局唯一拖拽状态，seed_card 用它判断是否允许再 spawn。

func _end_drag():
	PlacementManager.dragging_plant = null
	z_index = ZIndex.PLANT
	var valid: bool = PlacementManager.is_active_valid()
	if not valid:
		PlacementManager.clear_highlight()
		queue_free()
		return
	if not PlacementManager.spend_sun(cost):
		PlacementManager.clear_highlight()
		queue_free()
		return
	# register 必须在 clear_highlight 之前：manager 要用当前 anchor + size 算 cells。
	occupied_cells = PlacementManager.register_plant(self)  # 注册到 manager，触发迷雾重算，返回占的格子。
	PlacementManager.clear_highlight()
	# 视觉摆位：纯外观，不影响逻辑。用占格的中心点对齐。
	var tm: TileMapLayer = PlacementManager.get_tile_map()
	var center := Vector2.ZERO
	for c in occupied_cells:
		center += tm.to_global(tm.map_to_local(c))
	center /= occupied_cells.size()
	global_position = center


func _on_die():
	PlacementManager.unregister_plant(self)
