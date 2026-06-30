extends Node2D
# 种子卡片：点一下开始拖拽对应植物。圆角卡片底框 + 悬停高亮 + 阳光消耗。
const TILE_PX := 64                               # 每格像素，和任家庄.tscn 的 tile_size 一致。
const CARD_W := 3 * TILE_PX                       # 所有卡片统一宽度（按最大占格 3 取）。
const SUN_ICON := preload("res://assets/plants/阳光.png")
const COST_FONT_SIZE := 16
const DESC_H := 28.0                              # 卡片底部描述行高度（阳光消耗放这行）。

@export var plant_scene: PackedScene
@export var display_name: String = ""
@export var icon: Texture2D
@export var size: Vector2i = Vector2i(2, 2)
@export var star: int = 1
@export var level: int = 1
@onready var sprite: Sprite2D = $Sprite
const DISABLED_MODULATE := Color(0.4, 0.4, 0.4, 1.0)  # 灵气不够时的灰色。
@export var cost: int = 0                          # 种植消耗灵气，sidebar 从 PlantDef 传入。

var _style: StyleBoxFlat
var _hovered: bool = false
var _hover_t: float = 0.0                          # 悬停过渡 0~1。
var _sprite_base_x: float = 0.0                    # 贴图左对齐后的基础 x。
const GRAD_TOP := Color(0.22, 0.20, 0.34)          # 顶部色：深紫蓝。
const GRAD_BOTTOM := Color(0.06, 0.05, 0.12)       # 底部色：近黑。
const CORNER_R := 8.0

func _ready() -> void:
	if icon != null:
		sprite.texture = icon
		# 卡片宽度固定 CARD_W，高度按 size.y × 64px；图标等比缩放取较小边贴合格子，不变形。
		var target := Vector2(CARD_W, size.y * TILE_PX)
		var tex_size := Vector2(icon.get_size())
		var sx :float= target.x / max(tex_size.x, 1.0)
		var sy :float= target.y / max(tex_size.y, 1.0)
		sprite.scale = Vector2(min(sx, sy), min(sx, sy))
		# 贴图左对齐到卡片左边：position.x = -卡片半宽 + 贴图显示半宽。
		var drawn_w := tex_size.x * sprite.scale.x
		_sprite_base_x = -CARD_W * 0.5 + drawn_w * 0.5
		sprite.position.x = _sprite_base_x
	PlacementManager.sun_changed.connect(_update_availability)
	_update_availability()
	_init_style()

func _init_style() -> void:
	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0, 0, 0, 0)             # 背景走手绘渐变，stylebox 只负责边框 + 阴影。
	_style.corner_radius_top_left = int(CORNER_R)
	_style.corner_radius_top_right = int(CORNER_R)
	_style.corner_radius_bottom_left = int(CORNER_R)
	_style.corner_radius_bottom_right = int(CORNER_R)
	_style.shadow_color = Color(0, 0, 0, 0.55)
	_style.shadow_offset = Vector2(0, 3)
	_style.anti_aliasing = true
	_apply_style_hover()

func _apply_style_hover() -> void:
	# 悬停时金边变亮加粗、阴影变深。
	var t := _hover_t
	_style.border_color = Color(0.85, 0.72, 0.35).lerp(Color(1.0, 0.92, 0.55), t)
	var bw := int(round(lerp(2.0, 3.0, t)))
	_style.border_width_left = bw
	_style.border_width_right = bw
	_style.border_width_top = bw
	_style.border_width_bottom = bw
	_style.shadow_size = int(round(lerp(6.0, 10.0, t)))

func _process(delta: float) -> void:
	var want := _is_mouse_over_card()
	if want != _hovered:
		_hovered = want
	var target_t := 1.0 if _hovered else 0.0
	_hover_t = move_toward(_hover_t, target_t, delta * 8.0)
	_apply_style_hover()
	# 悬停时植物贴图微微抬升；基础位置往上偏 DESC_H/2 让出底部描述行。
	var base_y := -DESC_H * 0.5 - 4.0
	sprite.position.x = _sprite_base_x
	sprite.position.y = lerp(base_y, base_y - 4.0, _hover_t)
	queue_redraw()

func _card_half() -> Vector2:
	# 卡片宽度固定 CARD_W，高度 = 植物占格高度 + 底部描述行。
	return Vector2(CARD_W * 0.5, (size.y * TILE_PX + DESC_H) * 0.5)

func _is_mouse_over_card() -> bool:
	var half := _card_half()
	var mp := get_global_mouse_position()
	var p := global_position
	return abs(mp.x - p.x) <= half.x and abs(mp.y - p.y) <= half.y

func _update_availability() -> void:
	# 灵气够就正常显示，不够就置灰。
	if PlacementManager.can_afford(cost):
		modulate = Color.WHITE
	else:
		modulate = DISABLED_MODULATE
	queue_redraw()

func _on_card() -> bool:
	return _is_mouse_over_card()

func _input(event: InputEvent) -> void:
	if not InputUtil.is_left_click_press(event):
		return
	if PlacementManager.dragging_plant != null or not _on_card():  # 已有植物拖拽中，或没点中卡片，忽略。
		return
	_spawn_plant()

func _spawn_plant() -> void:
	var plant = plant_scene.instantiate()
	plant.visible = false
	get_tree().current_scene.add_child(plant)
	plant.start_drag()                                  # 无参，manager 自己跟踪拖拽状态。

func _draw() -> void:
	var half := _card_half()
	var rect := Rect2(-half, half * 2.0)
	# 1. 圆角阴影 + 金边（bg 透明，渐变在手绘前画）。
	draw_style_box(_style, rect)
	# 2. 圆角渐变背景：顶部深紫蓝 → 底部近黑，悬停时整体提亮。
	var top_c := GRAD_TOP.lerp(Color(0.40, 0.36, 0.55), _hover_t * 0.5)
	var bot_c := GRAD_BOTTOM.lerp(Color(0.12, 0.10, 0.22), _hover_t * 0.5)
	_draw_gradient_rounded(rect, CORNER_R, top_c, bot_c)
	# 3. 顶部内层高光（圆角描边），悬停时更亮。
	var hi_a := 0.30 + _hover_t * 0.40
	_draw_rounded_border(rect.grow(-1.5), CORNER_R - 1.5, Color(1.0, 0.95, 0.7, hi_a), 1.0)
	# 4. 描述行分隔线。
	var desc_top := (size.y * TILE_PX - DESC_H) * 0.5
	draw_line(Vector2(rect.position.x + 6, desc_top),
		Vector2(rect.end.x - 6, desc_top),
		Color(1.0, 0.85, 0.5, 0.35), 1.0)
	# 5. 描述行：阳光图标 + 消耗数字。
	if cost > 0:
		_draw_cost(rect)

func _draw_gradient_rounded(rect: Rect2, radius: float, top_c: Color, bot_c: Color) -> void:
	# 按行 lerp 渐变，遇圆角行收窄 x 范围，避免角落溢出。
	var y0 := rect.position.y
	var y1 := rect.end.y
	var h := rect.size.y
	var r := radius
	for y in range(int(y0), int(y1)):
		var t :float= (float(y) - y0) / max(h - 1.0, 1.0)
		var col := top_c.lerp(bot_c, t)
		var x0 := rect.position.x
		var x1 := rect.end.x
		if y < y0 + r:
			var dy := (y0 + r) - y
			var dx := r - sqrt(max(r * r - dy * dy, 0.0))
			x0 += dx
			x1 -= dx
		elif y > y1 - r:
			var dy := y - (y1 - r)
			var dx := r - sqrt(max(r * r - dy * dy, 0.0))
			x0 += dx
			x1 -= dx
		draw_line(Vector2(x0, y + 0.5), Vector2(x1, y + 0.5), col, 1.0)

func _draw_rounded_border(rect: Rect2, radius: float, color: Color, width: float) -> void:
	# 圆角描边：4 条直线 + 4 个角弧。
	var r := radius
	var p := rect.position
	var e := rect.end
	draw_line(Vector2(p.x + r, p.y), Vector2(e.x - r, p.y), color, width)
	draw_line(Vector2(p.x + r, e.y), Vector2(e.x - r, e.y), color, width)
	draw_line(Vector2(p.x, p.y + r), Vector2(p.x, e.y - r), color, width)
	draw_line(Vector2(e.x, p.y + r), Vector2(e.x, e.y - r), color, width)
	var col := color
	draw_arc(Vector2(p.x + r, p.y + r), r, PI, PI * 1.5, 8, col, width)
	draw_arc(Vector2(e.x - r, p.y + r), r, PI * 1.5, PI * 2.0, 8, col, width)
	draw_arc(Vector2(p.x + r, e.y - r), r, PI * 0.5, PI, 8, col, width)
	draw_arc(Vector2(e.x - r, e.y - r), r, 0.0, PI * 0.5, 8, col, width)

func _draw_cost(rect: Rect2) -> void:
	var icon_size := Vector2(SUN_ICON.get_size())
	var icon_scale: float = float(COST_FONT_SIZE) / max(icon_size.y, 1.0)
	var drawn_size := icon_size * icon_scale
	var text := str(cost)
	var font: Font = ThemeDB.get_default_theme().default_font
	# 描述行中心 y = size.y * TILE_PX / 2（卡片底部往上 DESC_H/2）。
	var desc_cy := size.y * TILE_PX * 0.5
	# 左对齐：图标 + 数字横排，垂直居中于描述行。
	var x := rect.position.x + 8
	var y := desc_cy - COST_FONT_SIZE * 0.5
	draw_texture_rect(SUN_ICON, Rect2(Vector2(x, y), drawn_size), false)
	draw_string(font, Vector2(x + drawn_size.x + 4, y + COST_FONT_SIZE), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, COST_FONT_SIZE, Color(1.0, 0.95, 0.4))
