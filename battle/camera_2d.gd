extends Camera2D
# 战斗相机：左键拖动平移，限制在地图范围内，左侧留出 sidebar 宽度避免挡住地图。


var panning := false
# 相机可移动的世界坐标范围（min_x, min_y, max_x, max_y）。null 表示未设置，不限制。
var _bounds: Rect2 = Rect2()
var _has_bounds: bool = false
# sidebar 占屏幕宽度的比例（和 sidebar.tscn 的 anchor_right 一致）。
const SIDEBAR_RATIO := 0.2

func _ready() -> void:
	# 延迟一帧设置边界，确保 PlacementManager 和 tile_map 都已 bind。
	call_deferred("_setup_bounds")

func _setup_bounds() -> void:
	var tm := PlacementManager.get_tile_map()
	if tm == null:
		return
	var used := tm.get_used_rect()
	if used.size == Vector2i.ZERO:
		return
	var tile_size := Vector2(tm.tile_set.tile_size)
	# 地图四个角的世界坐标。
	var top_left := tm.to_global(tm.map_to_local(used.position) - tile_size * 0.5)
	var bottom_right := tm.to_global(tm.map_to_local(used.end - Vector2i.ONE) + tile_size * 0.5)
	var viewport_size := get_viewport_rect().size
	# sidebar 占屏幕左侧 SIDEBAR_RATIO 宽度，地图内容不能进入 sidebar 区域。
	# 相机中心 cx 时，世界点 wx 在屏幕上的 x = wx - cx + half_viewport.x。
	# 约束 1：地图左边 top_left.x 在屏幕上 ≥ sidebar_width（不被 sidebar 挡）。
	#   top_left.x - cx + half_viewport.x ≥ sidebar_width
	#   => cx ≤ top_left.x + half_viewport.x - sidebar_width
	# 约束 2：地图右边 bottom_right.x 在屏幕上 ≤ viewport_size.x（不出右边缘）。
	#   bottom_right.x - cx + half_viewport.x ≤ viewport_size.x
	#   => cx ≥ bottom_right.x - half_viewport.x
	# 约束 3/4：上下不出 viewport。
	var half_viewport := viewport_size * 0.5
	var sidebar_width := viewport_size.x * SIDEBAR_RATIO
	var min_x := bottom_right.x - half_viewport.x          # 相机中心最左（地图右边不出屏幕右边缘）。
	var max_x := top_left.x + half_viewport.x - sidebar_width  # 相机中心最右（地图左边不被 sidebar 挡）。
	var min_y := bottom_right.y - half_viewport.y
	var max_y := top_left.y + half_viewport.y
	_bounds = Rect2(
		Vector2(min(min_x, max_x), min(min_y, max_y)),
		Vector2(abs(max_x - min_x), abs(max_y - min_y))
	)
	_has_bounds = true
	# 设置完边界立刻夹一次，防开局就在边界外。
	_clamp_position()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		panning = event.pressed
	elif event is InputEventMouseMotion and panning:
		global_position -= event.relative
		_clamp_position()

func _clamp_position() -> void:
	if not _has_bounds:
		return
	var pos := global_position
	# bounds.position 是 min，end 是 max。
	pos.x = clamp(pos.x, _bounds.position.x, _bounds.end.x)
	pos.y = clamp(pos.y, _bounds.position.y, _bounds.end.y)
	global_position = pos
