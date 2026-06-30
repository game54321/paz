extends "plant_base.gd"
@export var bullet_scene: PackedScene
var _timer := 0.0

func _ready() -> void:
	size = Vector2i(3, 1)
	super._ready()

func _process(delta: float) -> void:
	super._process(delta)                            # unit_base._process 调 queue_redraw 刷血条。
	if PlacementManager.dragging_plant == self:    # 拖拽中不发射。
		return
	_timer += delta
	# 实际攻击间隔 = 基础间隔 / 攻速倍率（词条加成后倍率 >1.0，间隔变短）。
	if _timer >= base_attack_interval / max(attack_speed_mult, 0.01):
		_timer = 0.0
		if _has_target_in_range():
			_fire()

func _has_target_in_range() -> bool:
	# 射程内无僵尸不开火，避免对着空气射击。
	if attack_range_px <= 0.0:
		return false
	for t in get_tree().get_nodes_in_group("zombie"):
		if is_instance_valid(t) and global_position.distance_to(t.global_position) <= attack_range_px:
			return true
	return false

func _fire() -> void:
	var bullet := preload("res://units/bullets/豆.gd").new()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = global_position + Vector2(20, 0)
