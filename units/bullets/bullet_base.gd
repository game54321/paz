extends Node2D

@export var speed := 300.0
@export var damage := 20.0
@export var direction := Vector2(1, 0)   # 单位向量，朝向
@export var lifetime := 5.0              # 自动销毁时间
@export var hit_radius := 30.0           # 击中判定半径
@export var pierce := 0                  # 穿透次数，0=命中即销毁
@export var texture: Texture2D
var _age := 0.0
var _hits: Array = []    

func _ready() -> void:
	z_index = ZIndex.BULLET
	if texture:
		var s := Sprite2D.new()
		s.texture = texture
		add_child(s)
func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	_update_direction()                  # ← 每帧更新方向
	global_position += direction * speed * delta
	_check_hit()



func _update_direction() -> void:
	var nearest := INF
	var best: Node2D = null
	for t in get_tree().get_nodes_in_group(_target_group()):
		if not is_instance_valid(t) or t in _hits:
			continue
		var d = global_position.distance_to(t.global_position)
		if d < nearest:
			nearest = d	
			best = t

	if best:
		direction = (best.global_position - global_position).normalized()

  # 子类重写：返回目标 group 名（"zombie" / "plant" / ...）
func _target_group() -> String:
	return "zombie"

func _on_hit(target: Node) -> void:
	if target.has_method("take_damage"):
		target.take_damage(damage)
	
func _check_hit() -> void:
	for t in get_tree().get_nodes_in_group(_target_group()):
		if not is_instance_valid(t) or t in _hits:
			continue
		if global_position.distance_to(t.global_position) <= hit_radius:
			_on_hit(t)
			_hits.append(t)
			if pierce <= 0:
				queue_free()
				return
			pierce -= 1
