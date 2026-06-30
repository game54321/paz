extends Control
# 小地图：屏幕角落自包含组件，按格子坐标缩放绘制整张地图。
# 画：已点亮区域 + 植物位置点 + 当前相机视口框。
# 所有数据从 PlacementManager 和场景树读取，不修改外部状态。


const MINIMAP_MAX := 180                        # 小地图最长边像素。

const COLOR_BG := Color(0.05, 0.07, 0.05, 0.85)
const COLOR_BORDER := Color(0.42, 0.52, 0.34, 0.95)
const COLOR_LIT := Color(0.36, 0.55, 0.30, 0.85)
const COLOR_PLANT := Color(0.95, 0.92, 0.55, 1.0)
const COLOR_ZOMBIE := Color(0.95, 0.18, 0.18, 1.0)
const COLOR_VIEWPORT := Color(1.0, 0.94, 0.72, 0.9)

var _tile_map: TileMapLayer
var _camera: Camera2D
var _used: Rect2i = Rect2i()
var _cell_size_px: Vector2 = Vector2.ZERO    # 单格世界像素大小。
var _scale: Vector2 = Vector2.ZERO           # 格子坐标 → 小地图坐标的缩放。
var _size: Vector2 = Vector2.ZERO            # 小地图实际尺寸（按地图长宽比）。

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	PlacementManager.fog_dirty.connect(queue_redraw)

func _process(_delta: float) -> void:
	if _tile_map == null:
		_tile_map = PlacementManager.get_tile_map()
		if _tile_map:
			_recompute_map_rect()
	if _camera == null:
		_camera = get_viewport().get_camera_2d()
	queue_redraw()

func _recompute_map_rect() -> void:
	_used = _tile_map.get_used_rect()
	if _used.size == Vector2i.ZERO:
		return
	_cell_size_px = Vector2(_tile_map.tile_set.tile_size)
	# 小地图尺寸按地图长宽比：最长边 = MINIMAP_MAX，另一边按比例缩放。
	var w: float = float(_used.size.x)
	var h: float = float(_used.size.y)
	if w >= h:
		_size = Vector2(MINIMAP_MAX, MINIMAP_MAX * h / w)
	else:
		_size = Vector2(MINIMAP_MAX * w / h, MINIMAP_MAX)
	custom_minimum_size = _size
	# 格子坐标 → 小地图坐标：x、y 独立缩放，地图填满整个小地图。
	_scale = _size / Vector2(_used.size)

func _cell_to_minimap(cell: Vector2i) -> Vector2:
	# 格子坐标 → 小地图坐标（格子左上角）。
	return (Vector2(cell - _used.position)) * _scale

func _world_to_minimap(world: Vector2) -> Vector2:
	# 世界坐标 → 小地图坐标。先转格子坐标（浮点），再缩放。
	var local := _tile_map.to_local(world)
	var cell_f := local / _cell_size_px
	return (cell_f - Vector2(_used.position)) * _scale

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, _size), COLOR_BG, true)
	draw_rect(Rect2(Vector2.ZERO, _size), COLOR_BORDER, false, 2.0)
	if _tile_map == null or _used.size == Vector2i.ZERO:
		return

	# 已点亮区域。
	for cell in PlacementManager.lit_cells:
		var p: Vector2 = _cell_to_minimap(cell)
		draw_rect(Rect2(p, _scale), COLOR_LIT, true)

	# 植物：占格几何中心画点。
	for plant in PlacementManager.plant_cells:
		var cells: Array = PlacementManager.plant_cells[plant]
		if cells.is_empty():
			continue
		var sum := Vector2.ZERO
		for c in cells:
			sum += Vector2(c)
		var center_cell: Vector2 = sum / float(cells.size())
		var p: Vector2 = (center_cell - Vector2(_used.position)) * _scale
		draw_circle(p, 3.0, COLOR_PLANT)

	# 僵尸：世界坐标转小地图坐标画红点，迷雾下不显示。
	for z in get_tree().get_nodes_in_group("zombie"):
		if not z is Node2D:
			continue
		var cell: Vector2i = _tile_map.local_to_map(_tile_map.to_local(z.global_position))
		if not PlacementManager.is_lit(cell):
			continue
		var p: Vector2 = _world_to_minimap(z.global_position)
		draw_circle(p, 3.0, COLOR_ZOMBIE)

	# 相机视口框：4 条边按真实位置画，各自 clip 到小地图内，保持矩形比例不变形。
	if _camera:
		var vp := get_viewport_rect().size
		var cam: Vector2 = _camera.global_position
		var tl: Vector2 = _world_to_minimap(cam - vp * 0.5)
		var br: Vector2 = tl + vp / _cell_size_px * _scale
		_draw_h_line(tl.x, br.x, tl.y)
		_draw_h_line(tl.x, br.x, br.y)
		_draw_v_line(tl.y, br.y, tl.x)
		_draw_v_line(tl.y, br.y, br.x)

func _draw_h_line(x1: float, x2: float, y: float) -> void:
	# 水平边：y 不在小地图内则不画，x 截断到小地图内。
	if y < 0.0 or y > _size.y:
		return
	var a: float = clampf(x1, 0.0, _size.x)
	var b: float = clampf(x2, 0.0, _size.x)
	if a == b:
		return
	draw_line(Vector2(a, y), Vector2(b, y), COLOR_VIEWPORT, 1.5)

func _draw_v_line(y1: float, y2: float, x: float) -> void:
	# 垂直边：x 不在小地图内则不画，y 截断到小地图内。
	if x < 0.0 or x > _size.x:
		return
	var a: float = clampf(y1, 0.0, _size.y)
	var b: float = clampf(y2, 0.0, _size.y)
	if a == b:
		return
	draw_line(Vector2(x, a), Vector2(x, b), COLOR_VIEWPORT, 1.5)
