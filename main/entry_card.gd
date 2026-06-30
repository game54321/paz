extends Control
# 词条卡片 UI：纯展示版（不可拖拽）。
# 用 assets/entry/{entry_name}.png 作为整张卡面图绘制（按比例居中填入 inner_rect）。
# 单击触发词条详情面板（延迟判定，等待可能的双击）；双击触发装备/卸下，由 plant_panel 处理。


signal single_clicked(entry_id: String, level: int)
signal double_clicked(entry_id: String, level: int)
signal drag_started(card: Control)

@export var entry_id: String = ""
@export var entry_name: String = ""
@export var entry_size: Vector2i = Vector2i(1, 1)       # 占格数（字数×1）
@export var entry_count: int = 1                        # 持有数量，>1 时右下角显示
@export var entry_level: int = 1                        # 词条等级，>1 时左上角显示 Lv.N

const CELL_SIZE := 60
const EDGE_COLOR := Color(1, 1, 1, 0.88)
const SHADOW_COLOR := Color(0, 0, 0, 0.38)
const FILL_COLOR := Color(0.96, 0.90, 0.74, 1.0)        # 米黄卡面，配黄色背景
const DOUBLE_CLICK_TIME := 0.35                         # 双击间隔上限（秒），也用作单击延迟判定。
const DRAG_THRESHOLD := 5.0                            # 拖拽触发阈值（像素）。
const ENTRY_IMAGE_DIR := "res://assets/entry/"
# 等级 → 颜色 + 光晕强度。1阶白、2阶绿、3阶蓝、4阶紫、5阶金。
const LEVEL_COLORS := [
	Color.WHITE,
	Color(0.95, 0.95, 0.95, 1.0),   # 1阶 白
	Color(0.45, 0.95, 0.5, 1.0),    # 2阶 绿
	Color(0.45, 0.65, 1.0, 1.0),    # 3阶 蓝
	Color(0.75, 0.45, 1.0, 1.0),    # 4阶 紫
	Color(1.0, 0.78, 0.3, 1.0),     # 5阶 金
]
const STAR_STR := "★"

var _last_click_time: float = -1.0
var _pressed: bool = false
var _press_pos: Vector2 = Vector2.ZERO
var _pending_single: bool = false                       # 第一次点击后等待双击确认，true 期间倒计时。
var _single_timer: float = 0.0                          # 单击延迟剩余时间。
var _texture: Texture2D = null                          # 按 entry_name 加载的卡面图，可能为空。

func _ready() -> void:
	custom_minimum_size = Vector2(entry_size.x * CELL_SIZE, entry_size.y * CELL_SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if entry_name != "":
		var path: String = ENTRY_IMAGE_DIR + entry_name + ".png"
		if ResourceLoader.exists(path):
			_texture = load(path) as Texture2D

func _process(delta: float) -> void:
	# 单击延迟判定：第一次点击后等 DOUBLE_CLICK_TIME，期间没有第二次点击就触发单击。
	if not _pending_single:
		return
	_single_timer -= delta
	if _single_timer <= 0.0:
		_pending_single = false
		single_clicked.emit(entry_id, entry_level)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressed = true
			_press_pos = event.position
			var now: float = Time.get_ticks_msec() / 1000.0
			if _last_click_time >= 0.0 and now - _last_click_time <= DOUBLE_CLICK_TIME:
				# 第二次点击：取消待触发的单击，触发双击。
				_pending_single = false
				double_clicked.emit(entry_id, entry_level)
				_last_click_time = -1.0
				_pressed = false
			else:
				# 第一次点击：暂存，延迟触发单击，等待可能的第二次点击。
				_last_click_time = now
				_pending_single = true
				_single_timer = DOUBLE_CLICK_TIME
		else:
			_pressed = false
	elif event is InputEventMouseMotion and _pressed:
		if event.position.distance_to(_press_pos) >= DRAG_THRESHOLD:
			_pressed = false
			_last_click_time = -1.0
			_pending_single = false
			drag_started.emit(self)

func _draw() -> void:
	var total_rect: Rect2 = Rect2(0, 0, entry_size.x * CELL_SIZE, CELL_SIZE)
	var inner_rect: Rect2 = total_rect.grow(-4)

	# 等阶光晕：卡内向边缘收缩的彩色矩形叠加，越靠边越亮，模拟内发光。
	var lvl_col: Color = LEVEL_COLORS[entry_level] if entry_level < LEVEL_COLORS.size() else Color.WHITE
	for i in 12:
		var shrink_amt: float = (i + 1) * 1.5
		var a: float = 0.22 * (1.0 - float(i) / 12.0)
		draw_rect(total_rect.grow(-shrink_amt), Color(lvl_col.r, lvl_col.g, lvl_col.b, a), true)

	# 卡面图按比例居中填进 inner_rect。
	if _texture != null:
		var img_size: Vector2 = _texture.get_size()
		if img_size.x > 0.0 and img_size.y > 0.0:
			var s: float = minf(inner_rect.size.x / img_size.x, inner_rect.size.y / img_size.y)
			var dst_size: Vector2 = img_size * s
			var dst_rect: Rect2 = Rect2(
				inner_rect.position + (inner_rect.size - dst_size) * 0.5,
				dst_size
			)
			draw_texture_rect(_texture, dst_rect, false)

	var font: Font = get_theme_default_font()

	# 右上角画等级星数：1阶★、2阶★★...，颜色按阶渐变，黑色描边。
	var star_count: int = entry_level
	var star_size: int = 16
	var one_star_size: Vector2 = font.get_string_size(STAR_STR, HORIZONTAL_ALIGNMENT_LEFT, -1, star_size)
	var total_w: float = one_star_size.x * star_count
	var star_y: float = font.get_ascent(star_size)
	# 描边（八方向）。
	for i in star_count:
		var sx: float = entry_size.x * CELL_SIZE - total_w + i * one_star_size.x
		var pos: Vector2 = Vector2(sx, star_y)
		for ox in [-2, -1, 1, 2]:
			for oy in [-2, -1, 1, 2]:
				draw_string(font, pos + Vector2(ox, oy), STAR_STR, HORIZONTAL_ALIGNMENT_LEFT, -1, star_size, Color(0, 0, 0, 0.95))
	# 主色。
	for i in star_count:
		var sx: float = entry_size.x * CELL_SIZE - total_w + i * one_star_size.x
		draw_string(font, Vector2(sx, star_y), STAR_STR, HORIZONTAL_ALIGNMENT_LEFT, -1, star_size, lvl_col)

	# 右下角画持有数量（>1 时）：黑色文字 + 白色八方向描边，任何背景上都清晰。
	if entry_count > 1:
		var cnt_str: String = "×%d" % entry_count
		var cnt_size: int = 16
		var txt_size: Vector2 = font.get_string_size(cnt_str, HORIZONTAL_ALIGNMENT_RIGHT, -1, cnt_size)
		var cnt_pos: Vector2 = Vector2(entry_size.x * CELL_SIZE - txt_size.x - 4, CELL_SIZE - 4)
		# 白色描边（八方向 + 2px）。
		for ox in [-2, -1, 1, 2]:
			for oy in [-2, -1, 1, 2]:
				draw_string(font, cnt_pos + Vector2(ox, oy), cnt_str, HORIZONTAL_ALIGNMENT_RIGHT, -1, cnt_size, Color(1, 1, 1, 0.95))
		# 黑色主色。
		draw_string(font, cnt_pos, cnt_str, HORIZONTAL_ALIGNMENT_RIGHT, -1, cnt_size, Color(0, 0, 0, 1.0))
