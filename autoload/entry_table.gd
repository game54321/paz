extends Node
# 词条配置表（autoload 单例）：按 id 索引所有词条的静态配置 EntryDef。
# 第 1 版在 _ready 硬编码注册；后续可改成扫描 data/entries/*.tres 自动加载。
# PlayerData 只存 entry_id，需要显示名/介绍时通过本表查询。


const EntryDefClass := preload("res://data/entry_def.gd")

# id -> EntryDef。id 格式 "entry001"、"entry002"...（参考植物 plant001 命名）。
var defs: Dictionary = {}

func _ready() -> void:
	_register_defaults()

func _register_defaults() -> void:
	# 初始词条，对标策划案。字数决定品质与占格。
	_register("entry001", "大力", "植物通过修炼，拥有了一身大力", [
		{"stat": "damage", "value": 10.0, "mode": "add"},     # +10 攻击力
	])
	_register("entry002", "强壮", "植物通过修炼，练就了一身铜皮铁骨", [
		{"stat": "hp", "value": 50.0, "mode": "add"},         # +50 血量
	])
	_register("entry003", "敏捷", "植物通过修炼，练就了一身神行之法", [
		{"stat": "attack_speed", "value": 0.1, "mode": "pct"},# +10% 攻速
	])

func _register(id: String, display_name: String, description: String, modifiers: Array[Dictionary] = []) -> void:
	var def := EntryDefClass.new()
	def.id = id
	def.display_name = display_name
	def.description = description
	def.modifiers = modifiers
	defs[id] = def

# ── 外部 API ──────────────────────────────────────────────────────────

func get_def(id: String) -> Resource:
	# 返回 EntryDef，没有则 null。
	return defs.get(id)

func get_all() -> Array:
	# 返回所有 EntryDef，遍历用。
	return defs.values()
