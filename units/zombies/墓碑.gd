extends "res://units/unit_base.gd"
# 墓碑刷怪点：定期刷普通僵尸，被打爆后刷 Boss + 小弟。
# 可复用：所有参数 @export，拖进关卡 tscn 设值即可。一个关卡可放多个墓碑。
# 继承 unit_base 获得血条 + 受击能力，植物子弹会自动打它（is_enemy = true）。


@export var zombie_scene: PackedScene            # 普通僵尸场景（如 阿僵.tscn）。
@export var spawn_interval: float = 10.0         # 刷怪间隔（秒）。
@export var spawn_count_per_wave: int = 3        # 每波刷几只。
@export var spawn_radius: float = 40.0           # 僵尸在墓碑周围多远 spawn（像素）。

@export var boss_scene: PackedScene              # 打爆后刷的 Boss 场景（如 尸王.tscn）。
@export var boss_minion_scene: PackedScene       # Boss 带的小弟场景。
@export var boss_minion_count: int = 3           # Boss 带几个小弟。
@export var boss_spawn_radius: float = 80.0      # Boss 和小弟 spawn 范围（像素）。

var _spawn_timer: float = 0.0
var _destroyed: bool = false

func _ready() -> void:
	is_enemy = true                                # 进 "zombie" 组，植物子弹会打它。
	super._ready()

func _process(delta: float) -> void:
	super._process(delta)
	if _destroyed:
		return                                     # 已被打爆，停止刷怪。
	_spawn_timer += delta
	if _spawn_timer >= spawn_interval:
		_spawn_timer = 0.0
		_spawn_wave()

func _spawn_wave() -> void:
	# 刷一波普通僵尸，在墓碑周围随机位置。
	for i in spawn_count_per_wave:
		_spawn_unit(zombie_scene, spawn_radius)

func _spawn_unit(scene: PackedScene, radius: float) -> void:
	if scene == null:
		return
	var unit = scene.instantiate()
	get_tree().current_scene.add_child(unit)
	var angle := randf() * TAU
	var dist := randf() * radius
	unit.global_position = global_position + Vector2(cos(angle), sin(angle)) * dist

func _on_die() -> void:
	# 墓碑被打爆：spawn Boss + 小弟。节点由 unit_base.take_damage 的 queue_free 销毁，自动退出 zombie 组。
	if _destroyed:
		return
	_destroyed = true
	_spawn_boss()

func _spawn_boss() -> void:
	# Boss 在墓碑正中心 spawn。
	if boss_scene != null:
		_spawn_unit(boss_scene, 0.0)
	# 小弟在周围随机位置 spawn。
	for i in boss_minion_count:
		if boss_minion_scene != null:
			_spawn_unit(boss_minion_scene, boss_spawn_radius)
