extends Node2D
# 灵气球：阿葵产出，1 秒后自动飞向 HUD 入账。
# 第 1 版不做手动点击拾取，简化流程。


const IDLE_DURATION := 1.0          # 原地停留时间（秒），之后起飞。
const FLY_SPEED := 5.0              # 飞行速度（lerp 系数，越大越快）。
const ARRIVE_THRESHOLD := 12.0      # 距 HUD 多近算到达。
const FLOAT_AMP := 3.0              # 原地浮动幅度（像素）。
const FLOAT_FREQ := 3.0             # 原地浮动频率。

@export var value: int = 25         # 拾取后加多少灵气。

var _age: float = 0.0
var _state: int = 0                 # 0=IDLE, 1=FLYING
var _base_y: float = 0.0
var _fly_target: Vector2 = Vector2.ZERO
var _initialized := false

func _ready() -> void:
	pass

func setup(spawn_global: Vector2, val: int) -> void:
	# 必须在 add_child 之后、_process 之前调用：设好全局位置再捕获 _base_y。
	# _ready 在 add_child 时触发，那时 global_position 还是 (0,0)，不能在那里捕获。
	global_position = spawn_global
	_base_y = position.y
	value = val
	_initialized = true

func _process(delta: float) -> void:
	if not _initialized:                               # setup 还没调，跳过避免用错误的 _base_y。
		return
	match _state:
		0: _idle(delta)
		1: _fly(delta)

func _idle(delta: float) -> void:
	_age += delta
	# 原地上下浮动。
	position.y = _base_y + sin(_age * FLOAT_FREQ) * FLOAT_AMP
	if _age >= IDLE_DURATION:
		_state = 1
		_fly_target = _get_hud_world_position()

func _fly(delta: float) -> void:
	# 朝 HUD 飞，带缩小。
	position = position.lerp(_fly_target, delta * FLY_SPEED)
	scale = scale.lerp(Vector2(0.3, 0.3), delta * FLY_SPEED)
	if position.distance_to(_fly_target) < ARRIVE_THRESHOLD:
		PlacementManager.add_sun(value)
		queue_free()

func _get_hud_world_position() -> Vector2:
	# HUD 是 Control 在 CanvasLayer 上，灵气球是 Node2D 在世界坐标。
	# 用 canvas transform 把 HUD 的屏幕中心位置转成世界坐标。
	var hud := get_tree().get_first_node_in_group("sun_hud")
	if hud == null:
		# HUD 还没准备好，兜底飞向屏幕顶部中央。
		return get_viewport_rect().size * Vector2(0.5, 0.1)
	# get_global_rect 返回 Control 在屏幕上的实际矩形（已含 CanvasLayer 变换）。
	var screen_pos: Vector2 = hud.get_global_rect().get_center()
	# canvas_transform 把世界坐标映射到屏幕坐标，逆变换把屏幕坐标转回世界。
	return get_canvas_transform().affine_inverse() * screen_pos
