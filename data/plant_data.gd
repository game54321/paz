extends Resource
# 植物玩家实例数据：只存养成状态（plant_id + star/level/exp/unlocked）。
# 静态配置（基础属性/突破所需/图标/场景路径）在 PlantTable 的 PlantDef 里，按 plant_id 查询。
# 区别：PlantDef 是全玩家共享的配置表，PlantData 是单个玩家的养成进度。


@export var plant_id: String           # 指向 PlantTable 中的 PlantDef，如 "plant001"。
@export var star: int = 1              # 星级 1~5。
@export var level: int = 1             # 等级 1~99。
@export var exp: int = 0               # 当前经验。
@export var unlocked: bool = false     # 是否已解锁。

# 该植物装备的词条：Array of {entry_id: String, level: int, pos: Vector2i}。
# 位置是背包网格坐标，持久化用。第 1 版不存盘，重启重置。
var bag_entries: Array = []

# ── 派生属性（按 base + 星级 + 等级算） ───────────────────────────────
# 留给后续养成系统用，第 1 版战斗时不会调这些。

func get_def() -> Resource:
	# 从 PlantTable 查对应 PlantDef。
	return PlantTable.get_def(plant_id)

func get_max_hp() -> float:
	var def := get_def()
	if def == null:
		return 100.0
	# 基础血量 × (1 + (等级-1)*0.1) × (1 + (星级-1)*0.5)。
	var base :float= def.base_hp * (1.0 + (level - 1) * 0.1) * (1.0 + (star - 1) * 0.5)
	return _apply_modifiers("hp", base)

func get_damage() -> float:
	var def := get_def()
	if def == null:
		return 20.0
	# 基础攻击 × (1 + (等级-1)*0.08) × (1 + (星级-1)*0.4)。
	var base :float= def.base_damage * (1.0 + (level - 1) * 0.08) * (1.0 + (star - 1) * 0.4)
	return _apply_modifiers("damage", base)

func get_range() -> float:
	# 射程：基础射程 + 词条加成。add 模式按格数加，pct 模式按比例。
	var def := get_def()
	if def == null:
		return 0.0
	return _apply_modifiers("range", def.attack_range)

func get_attack_speed() -> float:
	# 攻速倍率：base 1.0，add 模式按倍率加成（+0.5 add → 1.5x），pct 模式按百分比。
	# 实际攻击间隔 = base_attack_interval / 倍率。
	return _apply_modifiers("attack_speed", 1.0)

# 修饰器累加：先加所有 add，再乘 (1 + sum_pct)。Dota/LoL 式混合公式。
# stat 取 "hp" / "damage" / "range" / "attack_speed"，与 EntryDef.modifiers 里的字段对齐。
func _apply_modifiers(stat: String, base: float) -> float:
	var add := 0.0
	var pct := 0.0
	for e in bag_entries:
		var def := EntryTable.get_def(e["entry_id"])
		if def == null:
			continue
		# 词条等级直接从 bag_entries 取（合成时不同等级分条存放）。
		var lvl: int = int(e.get("level", 1))
		for m in def.modifiers:
			if m.get("stat", "") != stat:
				continue
			var v: float = float(m.get("value", 0.0)) * lvl
			if m.get("mode", "add") == "pct":
				pct += v
			else:
				add += v
	return (base + add) * (1.0 + pct)

func get_exp_to_next() -> int:
	# 升到下一级需要的经验，第 1 版不用。
	return level * 100

# ── 词条背包 ──────────────────────────────────────────────────────────

func get_bag_entries() -> Array:
	# 返回装备的词条列表 [{entry_id, level, pos}]。
	return bag_entries

func equip_entry(entry_id: String, level: int, pos: Vector2i) -> void:
	# 装备词条到指定位置。同种词条（同 id，不论等级）不重复装备。
	for e in bag_entries:
		if e["entry_id"] == entry_id:
			return
	bag_entries.append({"entry_id": entry_id, "level": level, "pos": pos})

func unequip_entry(entry_id: String, level: int) -> void:
	# 卸下词条。
	for i in bag_entries.size():
		if bag_entries[i]["entry_id"] == entry_id and int(bag_entries[i].get("level", 1)) == level:
			bag_entries.remove_at(i)
			return

func get_entry_pos(entry_id: String, level: int) -> Vector2i:
	# 查词条在背包中的位置，没有返回 (-1, -1)。
	for e in bag_entries:
		if e["entry_id"] == entry_id and int(e.get("level", 1)) == level:
			return e["pos"]
	return Vector2i(-1, -1)
