class_name PlantCard
extends Control
# 植物列表卡片：统一图鉴条目，只显示植物文字贴图和选中状态。


signal pressed(data: Resource)

const TILE_PX := 48.0
const CARD_SIZE := Vector2(210, 76)
const ICON_BOX_SIZE := Vector2(184, 58)
const SELECTED_SCALE := 1.06

const BG := Color(0.96, 0.90, 0.74, 1.0)               # 米黄卡面
const BG_SELECTED := Color(1.0, 0.95, 0.80, 1.0)
const BG_LOCKED := Color(0.78, 0.72, 0.58, 0.86)
const EDGE := Color(0.55, 0.40, 0.22, 0.55)
const EDGE_SELECTED := Color(0.35, 0.25, 0.12, 0.90)
const TEXT_LOCKED := Color(0.55, 0.55, 0.55, 1.0)
const ICON_NORMAL := Color(0.94, 0.94, 0.92, 1.0)
const ICON_SELECTED := Color(0.02, 0.02, 0.02, 1.0)
const ICON_LOCKED := Color(0.34, 0.34, 0.34, 1.0)

var _def: Resource = null
var _data: Resource = null
var _locked: bool = false
var _selected: bool = false
var _base_scale: float = 1.0
var _cur_scale: float = 1.0
# 贴图在卡片本地坐标中的矩形（含 SELECTED_SCALE 缩放），供父容器做命中判定。
var icon_rect_local: Rect2 = Rect2(Vector2.ZERO, CARD_SIZE)

@onready var _icon_rect: TextureRect = $Icon

func _ready() -> void:
	_apply_icon()

func setup(def: Resource, data: Resource) -> void:
	_def = def
	_data = data
	_locked = data == null or not data.unlocked
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta("plant_id", def.id)
	_apply_icon()
	queue_redraw()

func _apply_icon() -> void:
	if _icon_rect == null:
		_icon_rect = get_node_or_null("Icon")
	if _icon_rect == null or _def == null:
		return
	_icon_rect.texture = _def.icon
	# 等比缩放贴图到整张卡槽中央。
	var target: Vector2 = ICON_BOX_SIZE - Vector2(14, 10)
	var tex_size: Vector2 = Vector2(_def.icon.get_size())
	if tex_size.x <= 0 or tex_size.y <= 0:
		return
	var s: float = min(target.x / tex_size.x, target.y / tex_size.y)
	var drawn: Vector2 = tex_size * s
	_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_icon_rect.size = drawn
	_icon_rect.position = (CARD_SIZE - drawn) * 0.5
	_icon_rect.pivot_offset = _icon_rect.size * 0.5
	icon_rect_local = Rect2(_icon_rect.position, drawn)
	_update_icon_modulate()

func set_selected(v: bool) -> void:
	_selected = v
	if _icon_rect != null:
		var s: float = SELECTED_SCALE if _selected else 1.0
		_icon_rect.scale = Vector2(s, s)
		_update_icon_modulate()
	queue_redraw()

# 由父容器（PlantFanList）拦截点击后回调，绕过旋转 Control 的命中判定问题。
func request_press() -> void:
	if not _locked:
		pressed.emit(_data)

func _update_icon_modulate() -> void:
	if _icon_rect == null:
		return
	if _locked:
		_icon_rect.modulate = ICON_LOCKED
	elif _selected:
		_icon_rect.modulate = ICON_SELECTED
	else:
		_icon_rect.modulate = ICON_NORMAL

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _locked:
			pressed.emit(_data)

func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, CARD_SIZE)
	var bg: Color = BG_LOCKED if _locked else (BG_SELECTED if _selected else BG)
	var edge: Color = EDGE_SELECTED if _selected else EDGE
	var font: Font = get_theme_default_font()
	var font_size: int = maxi(get_theme_default_font_size(), 16)

	_draw_box(rect.grow(-4), bg, edge, 7, 2)
	var slot_bg: Color = Color(0.96, 0.88, 0.66, 0.72) if not _selected else Color(1, 1, 1, 0.90)
	var slot_border: Color = Color(0.55, 0.40, 0.22, 0.22) if not _selected else Color(0, 0, 0, 0.18)
	_draw_box(Rect2(10, 9, CARD_SIZE.x - 20, CARD_SIZE.y - 18), slot_bg, slot_border, 6, 1)
	draw_rect(Rect2(14, 13, CARD_SIZE.x - 28, 8), Color(1, 1, 1, 0.08) if not _selected else Color(0, 0, 0, 0.06), true)
	if _selected:
		draw_rect(Rect2(8, 13, 4, CARD_SIZE.y - 26), Color(0.55, 0.40, 0.20, 0.86), true)
	if _def == null:
		return
	if _locked:
		draw_rect(rect.grow(-8), Color(0.55, 0.45, 0.30, 0.34), true)
		draw_string(font, Vector2(78, 43), "未解锁", HORIZONTAL_ALIGNMENT_LEFT, CARD_SIZE.x - 96, font_size, Color(0, 0, 0, 0.28))
		draw_string(font, Vector2(77, 42), "未解锁", HORIZONTAL_ALIGNMENT_LEFT, CARD_SIZE.x - 96, font_size, TEXT_LOCKED)

func _draw_box(rect: Rect2, bg: Color, border: Color, radius: int, border_width: int) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_corner_radius_all(radius)
	box.set_border_width_all(border_width)
	draw_style_box(box, rect)
