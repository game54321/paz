extends Control
# 左侧植物列表：扇形展开布局（方案A改进版）。
# 卡片绕左外侧圆心排开，每张卡片旋转一定角度。
# 选中/悬停的卡片向外推出并放大，全程平滑插值；新卡片从左侧飞入。
# 命中判定只用图标矩形，避免点击卡片空白区也触发切换。


const CARD_W := 210.0
const CARD_H := 76.0
const BASE_SCALE := 1.0
const SPREAD := deg_to_rad(24.0)            # 总角度跨度
const CARD_SPACING := 92.0                  # 垂直间距（>卡高 76 即不相交）
const OFFSET_X := -30.0                     # 整体左移，让卡片左侧溢出容器
const PUSH_SELECTED := 24.0                 # 选中卡外推
const PUSH_HOVER := 10.0                    # 悬停卡外推
const SCALE_SELECTED := 1.12
const SCALE_HOVER := 1.05
const ANIM_SPEED := 10.0
const FLY_IN_OFFSET := Vector2(-520.0, 0.0)

var _cards: Array[Control] = []
var _selected_idx: int = -1
var _hovered_idx: int = -1

# 每张卡片当前/目标 transform（position 指卡片视觉中心）。
var _cur_pos: Array[Vector2] = []
var _cur_rot: Array[float] = []
var _cur_scale: Array[float] = []
var _tgt_pos: Array[Vector2] = []
var _tgt_rot: Array[float] = []
var _tgt_scale: Array[float] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func add_card(card: Control) -> void:
	_cards.append(card)
	_cur_pos.append(Vector2.ZERO)
	_cur_rot.append(0.0)
	_cur_scale.append(BASE_SCALE * 0.2)
	_tgt_pos.append(Vector2.ZERO)
	_tgt_rot.append(0.0)
	_tgt_scale.append(BASE_SCALE)
	add_child(card)
	card.pivot_offset = Vector2(CARD_W * 0.5, CARD_H * 0.5)
	var idx: int = _cards.size() - 1
	_recompute_targets()
	_cur_pos[idx] = _tgt_pos[idx] + FLY_IN_OFFSET

func clear_cards() -> void:
	for c: Control in _cards:
		if is_instance_valid(c):
			c.queue_free()
	_cards.clear()
	_cur_pos.clear()
	_cur_rot.clear()
	_cur_scale.clear()
	_tgt_pos.clear()
	_tgt_rot.clear()
	_tgt_scale.clear()
	_selected_idx = -1
	_hovered_idx = -1

func set_selected(idx: int) -> void:
	_selected_idx = idx
	_recompute_targets()

func get_card_count() -> int:
	return _cards.size()

func get_card(idx: int) -> Control:
	if idx < 0 or idx >= _cards.size():
		return null
	return _cards[idx]

func _card_angle(i: int) -> float:
	var n := _cards.size()
	if n <= 1:
		return 0.0
	var step := SPREAD / (n - 1)
	return -SPREAD * 0.5 + step * i

func _recompute_targets() -> void:
	var n := _cards.size()
	var total_h := (n - 1) * CARD_SPACING
	var start_y := size.y * 0.5 - total_h * 0.5
	for i: int in n:
		var a := _card_angle(i)
		# 垂直堆叠 + 整体左移；角度越大向左偏移越多（扇形效果）。
		var p := Vector2(OFFSET_X + size.x * 0.5 - CARD_W * BASE_SCALE * 0.5,
				start_y + i * CARD_SPACING)
		# 按角度向左偏移一点，形成扇形弧度。
		p.x -= absf(a) * 60.0
		var s := BASE_SCALE
		if i == _selected_idx:
			p.x += PUSH_SELECTED
			s = BASE_SCALE * SCALE_SELECTED
		elif i == _hovered_idx:
			p.x += PUSH_HOVER
			s = BASE_SCALE * SCALE_HOVER
		_tgt_pos[i] = p
		_tgt_rot[i] = a
		_tgt_scale[i] = s

func _process(delta: float) -> void:
	var n := _cards.size()
	if n == 0:
		return
	var hovered := _pick(get_local_mouse_position())
	if hovered != _hovered_idx:
		_hovered_idx = hovered
		_recompute_targets()
	var t := minf(delta * ANIM_SPEED, 1.0)
	for i: int in n:
		_cur_pos[i] = _cur_pos[i].lerp(_tgt_pos[i], t)
		_cur_rot[i] = lerpf(_cur_rot[i], _tgt_rot[i], t)
		_cur_scale[i] = lerpf(_cur_scale[i], _tgt_scale[i], t)
		var c := _cards[i]
		# 带 pivot_offset 的 Control：视觉中心在父空间 = position + pivot_offset，
		# 旋转/缩放都绕 pivot，所以中心位置不受 rot/scale 影响。
		# 想让中心落在 _cur_pos[i]，就 position = center - pivot_offset。
		c.position = _cur_pos[i] - c.pivot_offset
		c.rotation = _cur_rot[i]
		c.scale = Vector2(_cur_scale[i], _cur_scale[i])

func _pick(p: Vector2) -> int:
	# p 是 fan list 局部坐标。手动反算到卡片本地坐标（左上角原点）：
	# 1. p 减中心 = 父空间中从中心到点的向量
	# 2. 反向旋转 = 转到卡片朝向
	# 3. 除以缩放 = 转到卡片本地尺度（原点在 pivot）
	# 4. 加 pivot = 把原点从 pivot 移到左上角
	var n := _cards.size()
	var i: int = n - 1
	while i >= 0:
		var c: PlantCard = _cards[i] as PlantCard
		if c == null:
			i -= 1
			continue
		var to_center: Vector2 = p - _cur_pos[i]
		var local_centered: Vector2 = to_center.rotated(-_cur_rot[i]) / _cur_scale[i]
		var local_topleft: Vector2 = local_centered + c.pivot_offset
		# 整张卡片矩形都可点击。
		var card_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(CARD_W, CARD_H))
		if card_rect.has_point(local_topleft):
			return i
		i -= 1
	return -1

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var idx := _pick(event.position)
		if idx >= 0:
			var c := _cards[idx]
			if c.has_method("request_press"):
				c.call("request_press")
