extends Node
# 植物配置表（autoload 单例）：按 id 索引所有植物的静态配置 PlantDef。
# 第 1 版在 _ready 硬编码注册；后续可改成扫描 data/plants/*.tres 自动加载。
# PlayerData 只存 plant_id，需要基础属性时通过本表查询。


const PlantDefClass := preload("res://data/plant_def.gd")

# id -> PlantDef。id 格式 "plant001"、"plant002"...
var defs: Dictionary = {}

func _ready() -> void:
	_register_defaults()

func _register_defaults() -> void:
	# 第 1 版硬编码注册两个初始植物。后续改成加载 .tres 文件时，这里替换成目录扫描。
	_register("plant001", "阿葵", "res://units/plants/阿葵.tscn",
		preload("res://assets/plants/阿葵.png"),
		Vector2i(2, 1),                             # 阿葵占 2x1 格。
		50.0, 20.0, 0.0, 0.0, 50, true, [10, 30, 80, 200])    # attack_range=0 格，阿葵不攻击；base_attack_interval=0 不周期攻击。
	_register("plant002", "豆道长", "res://units/plants/豆道长.tscn",
		preload("res://assets/plants/豆道长.png"),
		Vector2i(3, 1),                             # 豆道长占 2x2 格。
		50.0, 20.0, 5.0, 1.5, 100, false, [10, 30, 80, 200])  # attack_range=5 格（5×64=320px）；base_attack_interval=1.5 秒。
	_register("plant003", "阿坚", "res://units/plants/阿坚.tscn",
		preload("res://assets/plants/阿坚.png"),
		Vector2i(2, 1),
		300.0, 0.0, 0.0, 0.0, 50, false, [10, 30, 80, 200])   # 高血量防御植物，不攻击。
	_register("plant004", "窝哥", "res://units/plants/窝哥.tscn",
		preload("res://assets/plants/窝哥.png"),
		Vector2i(2, 1),
		100.0, 300.0, 0.0, 0.0, 50, false, [10, 30, 80, 200])  # 一次性砸击植物，attack_range=0 不画射程圆。

func _register(id: String, display_name: String, scene_path: String, icon: Texture2D,
		size: Vector2i, base_hp: float, base_damage: float, attack_range: float,
		base_attack_interval: float, cost: int,
		provides_vision: bool, breakthrough_costs: Array[int]) -> void:
	var def := PlantDefClass.new()
	def.id = id
	def.display_name = display_name
	def.scene_path = scene_path
	def.icon = icon
	def.size = size
	def.base_hp = base_hp
	def.base_damage = base_damage
	def.attack_range = attack_range
	def.base_attack_interval = base_attack_interval
	def.cost = cost
	def.provides_vision = provides_vision
	def.breakthrough_costs = breakthrough_costs
	defs[id] = def

# ── 外部 API ──────────────────────────────────────────────────────────

func get_def(id: String) -> Resource:
	# 返回 PlantDef，没有则 null。
	return defs.get(id)

func get_def_by_scene_path(scene_path: String) -> Resource:
	# 通过场景路径反查 PlantDef（plant_base 用 scene_file_path 查自己的配置）。
	for id in defs:
		var def: Resource = defs[id]
		if def.scene_path == scene_path:
			return def
	return null

func get_all() -> Array:
	# 返回所有 PlantDef，遍历用。
	return defs.values()
