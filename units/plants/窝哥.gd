extends "plant_base.gd"
# 窝瓜：一次性攻击植物。检测到附近僵尸后先蓄力（向内缩模拟压扁），再跃起砸下，造成大量伤害后自毁。
# 对应植物大战僵尸里的窝瓜。

const SQUASH_RANGE := 2.0           # 检测僵尸的格子范围。
const SQUASH_DAMAGE := 300.0        # 砸击伤害，足以秒杀普通僵尸。
const CHARGE_DURATION := 0.4        # 蓄力时长（秒）：向内缩模拟压扁储能。
const CHARGE_SCALE := 0.7           # 蓄力结束时缩到原大小的比例。
const LEAP_DURATION := 0.3          # 跳跃动画时长（秒）。
const LEAP_ARC := 50.0              # 跳跃弧高（像素）。

var _charging := false
var _charge_t := 0.0
var _leaping := false
var _leap_t := 0.0
var _leap_start := Vector2.ZERO
var _leap_target_pos := Vector2.ZERO
var _leap_target: Node = null

func _ready() -> void:
	size = Vector2i(2, 1)
	super._ready()

func _process(delta: float) -> void:
	if _leaping:
		_update_leap(delta)
		return
	if _charging:
		_update_charge(delta)
		return
	super._process(delta)
	if PlacementManager.dragging_plant == self:
		return
	var zombie := _find_target_in_range()
	if zombie != null:
		_start_charge(zombie)

func _find_target_in_range() -> Node:
	var tm := PlacementManager.get_tile_map()
	if tm == null:
		return null
	var range_px := SQUASH_RANGE * tm.tile_set.tile_size.x
	var nearest: Node = null
	var nearest_dist := INF
	for z in get_tree().get_nodes_in_group("zombie"):
		if not is_instance_valid(z):
			continue
		var d := global_position.distance_to(z.global_position)
		if d <= range_px and d < nearest_dist:
			nearest_dist = d
			nearest = z
	return nearest

func _start_charge(zombie: Node) -> void:
	_charging = true
	_charge_t = 0.0
	_leap_target = zombie

func _update_charge(delta: float) -> void:
	_charge_t += delta / CHARGE_DURATION
	if _charge_t >= 1.0:
		_charging = false
		if not is_instance_valid(_leap_target):
			# 蓄力期间目标没了：取消起跳，回待机（呼吸会自动恢复 scale）。
			_leap_target = null
			return
		_start_leap()
		return
	# 蓄力：均匀向内缩，抹掉呼吸摇晃。
	var s := lerpf(1.0, CHARGE_SCALE, _charge_t)
	sprite.scale = _base_scale * s
	sprite.rotation = 0.0

func _start_leap() -> void:
	_leaping = true
	_leap_t = 0.0
	_leap_start = global_position
	_leap_target_pos = _leap_target.global_position
	sprite.scale = _base_scale                  # 起跳前恢复大小，带着蓄力的缩放跳会怪。
	z_index = ZIndex.BULLET

func _update_leap(delta: float) -> void:
	_leap_t += delta / LEAP_DURATION
	if _leap_t >= 1.0:
		if is_instance_valid(_leap_target):
			_leap_target.take_damage(SQUASH_DAMAGE)
		_on_die()
		queue_free()
		return
	if is_instance_valid(_leap_target):
		_leap_target_pos = _leap_target.global_position
	global_position = _leap_start.lerp(_leap_target_pos, _leap_t)
	sprite.position.y = -sin(_leap_t * PI) * LEAP_ARC
