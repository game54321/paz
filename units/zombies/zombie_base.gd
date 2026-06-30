extends "res://units/unit_base.gd"
@export var speed := 30.0
@export var attack_range := 70.0
@export var attack_interval := 1.0                  # 多久发射一次"吃"子弹（秒）。
@export var attack_damage := 20.0                   # "吃"子弹伤害基准值，_ready 时按关卡通关次数放大。
var target: Node2D = null
var _attack_timer := 0.0

# 僵尸跳模式：周期性起跳，跳跃中水平推进 + 抛物线纵向偏移，落地后短暂停顿。
# 一跳总周期 = 蓄力 + 空中 + 落地停顿，三段比例由下面两个 ratio 决定。
@export var jump_cycle := 1.5                       # 一跳总周期（秒）。
@export var jump_charge_ratio := 0.15               # 蓄力占比：向内缩模拟压扁储能。
@export var jump_air_ratio := 0.55                  # 空中占比：抛物线 + 水平推进。
@export var jump_height := 40.0                     # 跳跃弧高（像素）。
@export var jump_charge_scale := 0.7                # 蓄力结束时 y 缩到此比例（压扁感）。
var _jump_timer := 0.0
var _sprite_rest_y: float = 0.0
var _sprite_rest_scale := Vector2.ONE

# 动态难度倍率在 PlayerData.ZOMBIE_SCALE_PER_CLEAR，按当前关通关次数算 1.2^n。
var _difficulty_mult: float = 1.0

func _ready() -> void:
	is_enemy = true                                   # 兜底：确保僵尸被归到 enemy，避免 tscn 漏设导致进 "plant" 组。
	# 按当前关卡通关次数算难度倍率（指数提升）。
	var idx: int = SceneManager.pending_level_index
	if idx >= 0:
		_difficulty_mult = PlayerData.get_level_zombie_scale(idx)
	# max_hp / attack_damage 由 tscn 配置，_ready 只乘难度倍率。
	max_hp *= _difficulty_mult
	speed *= _difficulty_mult
	attack_damage *= _difficulty_mult
	super._ready()                                    # unit_base 会按 is_enemy 把节点加进 "zombie" 组。
	if sprite:
		_sprite_rest_y = sprite.position.y
		_sprite_rest_scale = sprite.scale

func _process(delta: float) -> void:
	z_index = ZIndex.ZOMBIE
	super._process(delta)
	_find_target()
	if target:
		_attack(delta)
	# 没目标时也继续推进跳跃周期，让僵尸原地跳。
	_update_jump_visual(delta)

func _find_target() -> void:
	target = null
	var nearest := INF
	for p in get_tree().get_nodes_in_group("plant"):
		if not is_instance_valid(p):
			continue
		if p == PlacementManager.dragging_plant:
			continue
		var d = global_position.distance_to(p.global_position)
		if d < nearest:
			nearest = d
			target = p

func _attack(delta: float) -> void:
	var d = global_position.distance_to(target.global_position)
	if d > attack_range:
		# 离目标还远，只有空中段水平推进；蓄力和落地停顿都不移动。
		if _is_in_air():
			var dir = (target.global_position - global_position).normalized()
			global_position += dir * speed * delta
		return
	# 进入射程：_attack_timer 持续累加（不分落地/跳起），到点就咬一口。
	_attack_timer += delta
	if _attack_timer >= attack_interval:
		_attack_timer = 0.0
		_fire_bite()

func _is_charging() -> bool:
	var t := fmod(_jump_timer, jump_cycle)
	return t < jump_cycle * jump_charge_ratio

func _is_in_air() -> bool:
	var t := fmod(_jump_timer, jump_cycle)
	var charge := jump_cycle * jump_charge_ratio
	var air_end := charge + jump_cycle * jump_air_ratio
	return t >= charge and t < air_end

func _update_jump_visual(delta: float) -> void:
	_jump_timer += delta
	if sprite == null:
		return
	var t := fmod(_jump_timer, jump_cycle)
	var charge := jump_cycle * jump_charge_ratio
	var air_end := charge + jump_cycle * jump_air_ratio
	if t < charge:
		# 蓄力：y 方向均匀缩到 jump_charge_scale，模拟蹲下压扁储能。
		var k := t / charge
		sprite.scale = Vector2(_sprite_rest_scale.x, lerpf(_sprite_rest_scale.y, _sprite_rest_scale.y * jump_charge_scale, k))
		sprite.position.y = _sprite_rest_y
	elif t < air_end:
		# 空中：恢复 scale + 抛物线纵向偏移。t' = 当前时间相对空中段起点。
		sprite.scale = _sprite_rest_scale
		var tt := (t - charge) / (air_end - charge)
		sprite.position.y = _sprite_rest_y - 4.0 * jump_height * tt * (1.0 - tt)
	else:
		# 落地停顿：恢复 scale 和 y。
		sprite.scale = _sprite_rest_scale
		sprite.position.y = _sprite_rest_y

func _fire_bite() -> void:
	var bullet := preload("res://units/bullets/吃.gd").new()
	bullet.damage = attack_damage
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = global_position
	# 让子弹朝目标飞；bullet_base 自己会持续追踪最近植物，这里给个初方向即可。
	if is_instance_valid(target):
		bullet.direction = (target.global_position - global_position).normalized()
