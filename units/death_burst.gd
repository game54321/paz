extends Node2D
# 单位死亡粒子爆发：喷一团彩色小颗粒，自动销毁。
# 用法：DeathBurst.spawn(global_position, color)

const SCENE := preload("res://units/death_burst.tscn")
@export var color := Color.WHITE
@export var count := 40
@export var lifetime := 0.7
@export var spread := 280.0

static func spawn(at: Vector2, col: Color) -> void:
	var n: Node2D = SCENE.instantiate()
	n.color = col
	if Engine.is_editor_hint():
		return
	# 父级用 current_scene，保证跨场景生效。
	var root: Node = Engine.get_main_loop().current_scene
	if root == null:
		return
	root.add_child(n)
	n.global_position = at

func _ready() -> void:
	z_index = ZIndex.BULLET
	var p := CPUParticles2D.new()
	p.amount = count
	p.lifetime = lifetime
	p.one_shot = true
	p.emitting = true
	p.explosiveness = 0.9
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = spread * 0.5
	p.initial_velocity_max = spread
	p.gravity = Vector2(0, 900)
	p.scale_amount_min = 4.0
	p.scale_amount_max = 8.0
	p.color = color
	add_child(p)
	# 发完即销毁。
	get_tree().create_timer(lifetime + 0.1).timeout.connect(queue_free)
