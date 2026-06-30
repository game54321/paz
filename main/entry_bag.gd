extends Control
# 通用词条网格：背包和仓库共用同一组件。
# 绘制空白格子背景，提供占位计算和卡片放置接口。
# 卡片双击通过 entry_double_clicked 信号转发给外部。


signal entry_double_clicked(entry_id: String, level: int)
signal entry_single_clicked(entry_id: String, level: int)
signal entry_drag_started(card: Control)

const CELL_SIZE := 60
const GRID_LINE := Color(0.42, 0.30, 0.18, 0.55)   # 在黄色背景上的深棕色格线

# 网格尺寸（格子数）。背包 3x3，仓库可设大一些。
@export var grid_columns: int = 3
@export var grid_rows: int = 3

# 格子占用状态：Vector2i(格坐标) -> 组合 key（"entry_id#level"，"" 表示空）。
var _occupied: Dictionary = {}

# 拖拽落点高亮预览。
var _hover_cell: Vector2i = Vector2i(-1, -1)
var _hover_size: Vector2i = Vector2i(1, 1)
var _hover_valid: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(grid_columns * CELL_SIZE, grid_rows * CELL_SIZE)
	queue_redraw()

func _draw() -> void:
	# 画格线（不填底色，让背景图的黄色透出来）。
	var w: float = grid_columns * CELL_SIZE
	var h: float = grid_rows * CELL_SIZE
	for x in grid_columns + 1:
		var px: float = x * CELL_SIZE
		draw_line(Vector2(px, 0), Vector2(px, h), GRID_LINE, 2.0)
	for y in grid_rows + 1:
		var py: float = y * CELL_SIZE
		draw_line(Vector2(0, py), Vector2(w, py), GRID_LINE, 2.0)

	# 拖拽落点高亮（只在卡片完全落在网格内时画）。
	if _hover_cell.x >= 0 and _hover_cell.x + _hover_size.x <= grid_columns \
		and _hover_cell.y >= 0 and _hover_cell.y + _hover_size.y <= grid_rows:
		var r: Rect2 = Rect2(_hover_cell.x * CELL_SIZE, _hover_cell.y * CELL_SIZE,
			_hover_size.x * CELL_SIZE, _hover_size.y * CELL_SIZE)
		var col: Color = Color(1, 1, 1, 0.28) if _hover_valid else Color(0.65, 0.65, 0.65, 0.22)
		draw_rect(r, col, true)
		draw_rect(r.grow(-1), Color(1, 1, 1, 0.90), false, 2.0)

# ── 外部 API ──────────────────────────────────────────────────────────

func clear_entries() -> void:
	# 清空所有卡片和占用状态。
	for child in get_children():
		child.queue_free()
	_occupied.clear()

func place_entry(card: Control, size: Vector2i) -> bool:
	# 找空位放置卡片，成功返回 true。size.x = 字数。
	var pos: Vector2i = _find_free_pos(size)
	if pos.x < 0:
		return false
	_mark_occupied(pos, size, _card_key(card))
	add_child(card)
	card.position = Vector2(pos.x * CELL_SIZE, pos.y * CELL_SIZE)
	_connect_card_signals(card)
	return true

func place_entry_at(card: Control, size: Vector2i, pos: Vector2i) -> void:
	# 指定位置放置卡片（用于已记录的位置恢复）。
	_mark_occupied(pos, size, _card_key(card))
	add_child(card)
	card.position = Vector2(pos.x * CELL_SIZE, pos.y * CELL_SIZE)
	_connect_card_signals(card)

func _card_key(card: Control) -> String:
	# 卡片的组合 key：entry_id#level，区分同 id 不同等级。
	return "%s#%d" % [card.entry_id, card.entry_level]

func _connect_card_signals(card: Control) -> void:
	# 转发卡片信号到网格。
	if card.has_signal("double_clicked"):
		card.double_clicked.connect(entry_double_clicked.emit)
	if card.has_signal("single_clicked"):
		card.single_clicked.connect(entry_single_clicked.emit)
	if card.has_signal("drag_started"):
		card.drag_started.connect(entry_drag_started.emit)

func find_free_pos(size: Vector2i) -> Vector2i:
	# 外部查询空位（不放置），用于装备前预检。
	return _find_free_pos(size)

func can_place_at(cell: Vector2i, size: Vector2i, ignore_key: String = "") -> bool:
	# 外部查询：cell 处能否放下 size 的卡片，可忽略某个组合 key（同卡移动时用自身）。
	return _can_place(cell, size, ignore_key)

func local_pos_to_cell(local_pos: Vector2) -> Vector2i:
	# 局部坐标 → 格坐标（int 截断，按格左上角对齐）。
	return Vector2i(int(local_pos.x / CELL_SIZE), int(local_pos.y / CELL_SIZE))

func pos_to_cell_rounded(local_pos: Vector2) -> Vector2i:
	# 局部坐标 → 格坐标（round 到最近格中心），用于多格卡片落点判定。
	return Vector2i(roundi(local_pos.x / float(CELL_SIZE)), roundi(local_pos.y / float(CELL_SIZE)))

func clamp_cell_to_fit(cell: Vector2i, size: Vector2i) -> Vector2i:
	# 钳制左上角使卡片尽量留在网格内（避免高亮画出网格、边缘越界误判禁止）。
	var x: int = clampi(cell.x, 0, maxi(0, grid_columns - size.x))
	var y: int = clampi(cell.y, 0, maxi(0, grid_rows - size.y))
	return Vector2i(x, y)

func set_hover_preview(cell: Vector2i, size: Vector2i, valid: bool) -> void:
	if cell == _hover_cell and size == _hover_size and valid == _hover_valid:
		return
	_hover_cell = cell
	_hover_size = size
	_hover_valid = valid
	queue_redraw()

func clear_hover_preview() -> void:
	if _hover_cell.x >= 0:
		_hover_cell = Vector2i(-1, -1)
		queue_redraw()

func _find_free_pos(size: Vector2i) -> Vector2i:
	for y in grid_rows:
		for x in grid_columns:
			var pos: Vector2i = Vector2i(x, y)
			if _can_place(pos, size):
				return pos
	return Vector2i(-1, -1)

func _can_place(top_left: Vector2i, size: Vector2i, ignore_key: String = "") -> bool:
	for dy in size.y:
		for dx in size.x:
			var c: Vector2i = top_left + Vector2i(dx, dy)
			if c.x < 0 or c.x >= grid_columns or c.y < 0 or c.y >= grid_rows:
				return false
			var occ: String = _occupied.get(c, "")
			if occ != "" and occ != ignore_key:
				return false
	return true

func _mark_occupied(pos: Vector2i, size: Vector2i, key: String = "") -> void:
	for dy in size.y:
		for dx in size.x:
			_occupied[pos + Vector2i(dx, dy)] = key
