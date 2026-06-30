extends Node
# 玩家数据（autoload 单例，内存层）：持有玩家拥有的植物实例数据 PlantData 和词条仓库 EntryData。
# 存档走 JSON 落 user://save.json：new_game 开档、continue_game 续档、save 写盘。
# 局外（世界地图）和局内（战斗）都通过 PlayerData.plants 读取。
# 静态配置（基础攻击/突破所需/图标）在 PlantTable，本类只存 plant_id + 养成进度。
# 词条配置（显示名/介绍）在 EntryTable，本类只存 entry_id + count + equipped_to。


const PlantDataClass := preload("res://data/plant_data.gd")
const EntryDataClass := preload("res://data/entry_data.gd")
const SAVE_PATH := "user://save.json"

# 玩家拥有的植物数据。key = plant_id（如 "plant001"），value = PlantData。
var plants: Dictionary = {}
# 玩家拥有的词条数据。key = entry_id（如 "entry001"），value = EntryData。
var entries: Dictionary = {}
# 仓库内词条位置记忆：entry_id -> Vector2i（格子坐标）。(-1,-1) 表示未指定。
var warehouse_positions: Dictionary = {}
# 已通关关卡数（按 MOCK_LEVELS 顺序，0 = 还没通关任何关）。
var cleared_level_count: int = 0
# 每关通关次数：key = level_index（0-based），value = 通关次数。
# 用于动态难度：每通关一次，该关僵尸属性 +20%（指数提升）。
var level_clear_counts: Dictionary = {}
# 动态难度：每通关一次该关，僵尸属性 ×此倍率（指数提升）。改这里一个地方即可。
const ZOMBIE_SCALE_PER_CLEAR := 1.2

# 词条库存变化时发出，监听方据此刷新 UI。
signal entries_changed

func _ready() -> void:
	pass

# ── 存档 API ──────────────────────────────────────────────────────────

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func new_game() -> void:
	plants.clear()
	entries.clear()
	warehouse_positions.clear()
	cleared_level_count = 0
	level_clear_counts.clear()
	_init_default_plants()
	_init_default_entries()
	save()

func continue_game() -> bool:
	if not has_save():
		return false
	return _load()

func save() -> void:
	var data := {
		"plants": _serialize_plants(),
		"entries": _serialize_entries(),
		"warehouse_positions": _serialize_warehouse(),
		"cleared_level_count": cleared_level_count,
		"level_clear_counts": level_clear_counts,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("PlayerData: 写存档失败 %s" % SAVE_PATH)
		return
	f.store_string(JSON.stringify(data))
	f.close()

func _load() -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	plants.clear()
	entries.clear()
	warehouse_positions.clear()
	cleared_level_count = int(parsed.get("cleared_level_count", 0))
	level_clear_counts.clear()
	var lcc = parsed.get("level_clear_counts", {})
	if typeof(lcc) == TYPE_DICTIONARY:
		for k in lcc:
			level_clear_counts[int(k)] = int(lcc[k])
	_deserialize_plants(parsed.get("plants", {}))
	_deserialize_entries(parsed.get("entries", {}))
	_deserialize_warehouse(parsed.get("warehouse_positions", {}))
	return true

func _serialize_plants() -> Dictionary:
	var out: Dictionary = {}
	for plant_id in plants:
		var p: Resource = plants[plant_id]
		var bag: Array = []
		for e in p.bag_entries:
			bag.append({"entry_id": e["entry_id"], "level": e["level"], "pos": [e["pos"].x, e["pos"].y]})
		out[plant_id] = {
			"plant_id": p.plant_id,
			"star": p.star,
			"level": p.level,
			"exp": p.exp,
			"unlocked": p.unlocked,
			"bag_entries": bag,
		}
	return out

func _serialize_entries() -> Dictionary:
	var out: Dictionary = {}
	for k in entries:
		var e: Resource = entries[k]
		out[k] = {
			"entry_id": e.entry_id,
			"count": e.count,
			"level": e.level,
			"equipped_to": e.equipped_to,
		}
	return out

func _serialize_warehouse() -> Dictionary:
	var out: Dictionary = {}
	for k in warehouse_positions:
		var pos: Vector2i = warehouse_positions[k]
		out[k] = [pos.x, pos.y]
	return out

func _deserialize_plants(d: Dictionary) -> void:
	for plant_id in d:
		var v = d[plant_id]
		var data := PlantDataClass.new()
		data.plant_id = v.get("plant_id", plant_id)
		data.star = int(v.get("star", 1))
		data.level = int(v.get("level", 1))
		data.exp = int(v.get("exp", 0))
		data.unlocked = bool(v.get("unlocked", false))
		data.bag_entries.clear()
		for e in v.get("bag_entries", []):
			var pos_arr = e.get("pos", [-1, -1])
			data.bag_entries.append({
				"entry_id": e.get("entry_id", ""),
				"level": int(e.get("level", 1)),
				"pos": Vector2i(int(pos_arr[0]), int(pos_arr[1])),
			})
		plants[plant_id] = data

func _deserialize_entries(d: Dictionary) -> void:
	for k in d:
		var v = d[k]
		var data := EntryDataClass.new()
		data.entry_id = v.get("entry_id", "")
		data.count = int(v.get("count", 1))
		data.level = int(v.get("level", 1))
		data.equipped_to = v.get("equipped_to", "")
		entries[_key(data.entry_id, data.level)] = data

func _deserialize_warehouse(d: Dictionary) -> void:
	for k in d:
		var pos_arr = d[k]
		warehouse_positions[k] = Vector2i(int(pos_arr[0]), int(pos_arr[1]))

# 组合 key：同 entry_id 不同 level 分开存放。
func _key(entry_id: String, level: int) -> String:
	return "%s#%d" % [entry_id, level]

func _init_default_plants() -> void:
	# 首次启动给初始植物。后续可改成从存档加载。
	if not plants.is_empty():
		return
	_unlock("plant001")   # 阿葵
	_unlock("plant002")   # 豆道长
	_unlock("plant003")   # 阿坚
	_unlock("plant004")   # 窝哥

func _unlock(plant_id: String) -> void:
	if plants.has(plant_id):
		return
	# 校验 PlantTable 里确实有这个 id，避免写错配置。
	if PlantTable.get_def(plant_id) == null:
		push_error("PlayerData: plant_id %s 在 PlantTable 中不存在" % plant_id)
		return
	var data := PlantDataClass.new()
	data.plant_id = plant_id
	data.unlocked = true
	plants[plant_id] = data

func _init_default_entries() -> void:
	# 开局无词条，全部靠 debug 面板或通关掉落获得。
	pass

func _grant_entry(entry_id: String, count: int = 1, level: int = 1) -> void:
	# 校验 EntryTable 里确实有这个 id，避免写错配置。
	if EntryTable.get_def(entry_id) == null:
		push_error("PlayerData: entry_id %s 在 EntryTable 中不存在" % entry_id)
		return
	var k := _key(entry_id, level)
	if entries.has(k):
		entries[k].count += count
		return
	var data := EntryDataClass.new()
	data.entry_id = entry_id
	data.count = count
	data.level = level
	data.equipped_to = ""        # 默认在仓库。
	entries[k] = data

# ── 植物 API ──────────────────────────────────────────────────────────

func unlock(plant_id: String) -> void:
	# 解锁新植物（通关奖励等）。
	_unlock(plant_id)
	save()

func has_plant(plant_id: String) -> bool:
	return plants.has(plant_id) and plants[plant_id].unlocked

func get_plant(plant_id: String) -> Resource:
	# 返回 PlantData，没有则 null。
	return plants.get(plant_id)

func get_unlocked_plants() -> Array:
	# 返回所有已解锁的 PlantData，sidebar 用这个生成卡片。
	var arr: Array = []
	for plant_id in plants:
		var data: Resource = plants[plant_id]
		if data.unlocked:
			arr.append(data)
	return arr

# ── 词条 API ──────────────────────────────────────────────────────────

func grant_entry(entry_id: String, count: int = 1, level: int = 1) -> void:
	# 获得词条（掉落/奖励等）。已有时叠加 count。level 指定落入哪一级。
	_grant_entry(entry_id, count, level)
	entries_changed.emit()
	save()

# 词条等价点数：1级=1, 2级=3, N级=3^(N-1)。3 个同级 = 1 个高一级 的推广。
func _entry_value(level: int) -> int:
	var v := 1
	for i in range(level - 1):
		v *= 3
	return v

func compose_entry(entry_id: String, level: int, anchor_plant_id: String = "", anchor_pos: Vector2i = Vector2i(-1, -1)) -> bool:
	# 合成进阶：以 1 个 L 级词条为主，消耗其他同 id 词条（任意等级）补充点数，升到 L+1。
	# 主词条值 _entry_value(L)，L+1 值 3*_entry_value(L)，需补充 2*_entry_value(L) 点材料。
	# anchor_plant_id != "" 时主词条在植物背包，产出放回原位；否则主词条在仓库，产出进仓库。
	# 消耗策略：优先消耗低等级材料（保留高等级更有价值），不找零。
	var needed := 2 * _entry_value(level)
	# 收集材料（排除主词条），按等级升序排列。source="" 表示仓库，否则为 plant_id。
	var materials: Array = []
	for wk in entries:
		var e: Resource = entries[wk]
		if e.entry_id != entry_id or e.count <= 0:
			continue
		# 主词条在仓库时，本等级排除 1 个作为主。
		var start := 1 if (anchor_plant_id == "" and e.level == level) else 0
		for i in range(start, e.count):
			materials.append({"source": "", "level": e.level})
	for pid in plants:
		var plant: Resource = plants[pid]
		for e in plant.bag_entries:
			if e["entry_id"] != entry_id:
				continue
			var lvl: int = int(e.get("level", 1))
			if anchor_plant_id == pid and lvl == level:
				continue  # 主词条
			materials.append({"source": pid, "level": lvl})
	materials.sort_custom(func(a, b): return a.level < b.level)
	# 贪心消耗直到凑够 needed 点。
	var consumed: Array = []
	var points := 0
	for m in materials:
		if points >= needed:
			break
		points += _entry_value(m.level)
		consumed.append(m)
	if points < needed:
		return false
	# 执行消耗：主词条 + 材料。
	if anchor_plant_id == "":
		_consume_warehouse(entry_id, level, 1)
	else:
		plants[anchor_plant_id].unequip_entry(entry_id, level)
	var wh_consumed: Dictionary = {}  # level -> count
	for m in consumed:
		if m.source == "":
			wh_consumed[m.level] = wh_consumed.get(m.level, 0) + 1
		else:
			plants[m.source].unequip_entry(entry_id, m.level)
	for lvl in wh_consumed:
		_consume_warehouse(entry_id, lvl, wh_consumed[lvl])
	# 产出 L+1：主在背包则放回原位，否则进仓库。
	if anchor_plant_id != "" and anchor_pos.x >= 0:
		var plant: Resource = plants.get(anchor_plant_id)
		if plant != null:
			plant.equip_entry(entry_id, level + 1, anchor_pos)
		else:
			_grant_entry(entry_id, 1, level + 1)
	else:
		_grant_entry(entry_id, 1, level + 1)
	save()
	return true

func _consume_warehouse(entry_id: String, level: int, count: int) -> void:
	# 从仓库扣指定数量词条，count 归零则移除记录。
	var k := _key(entry_id, level)
	if not entries.has(k):
		return
	entries[k].count -= count
	if entries[k].count <= 0:
		entries.erase(k)
		warehouse_positions.erase(k)

func can_compose(entry_id: String, level: int) -> bool:
	# 能否合成升级：总点数（含主词条）>= 3 * _entry_value(level) = 3^level。
	return _get_total_entry_points(entry_id) >= 3 * _entry_value(level)

func _get_total_entry_points(entry_id: String) -> int:
	# 该 id 所有词条（仓库 + 装备中，所有等级）的等价点数总和。
	var total := 0
	for wk in entries:
		var e: Resource = entries[wk]
		if e.entry_id == entry_id:
			total += e.count * _entry_value(e.level)
	for pid in plants:
		var plant: Resource = plants[pid]
		for e in plant.bag_entries:
			if e["entry_id"] == entry_id:
				total += _entry_value(int(e.get("level", 1)))
	return total

func has_entry(entry_id: String) -> bool:
	# 是否持有任意等级的该词条。
	for k in entries:
		if entries[k].entry_id == entry_id:
			return true
	return false

func get_entry(entry_id: String, level: int) -> Resource:
	# 返回指定等级的 EntryData，没有则 null。
	return entries.get(_key(entry_id, level))

func get_warehouse_entries() -> Array:
	# 返回仓库中的所有 EntryData（按个装备后不再用 equipped_to 标记，仓库即 entries）。
	var arr: Array = []
	for k in entries:
		var data: Resource = entries[k]
		if data.count > 0:
			arr.append(data)
	return arr

func get_warehouse_pos(entry_id: String, level: int) -> Vector2i:
	# 查询词条在仓库的格位置，未记录返回 (-1,-1)。
	return warehouse_positions.get(_key(entry_id, level), Vector2i(-1, -1))

func set_warehouse_pos(entry_id: String, level: int, pos: Vector2i) -> void:
	# 记录词条在仓库的格位置。
	warehouse_positions[_key(entry_id, level)] = pos
	save()

func equip_entry(entry_id: String, level: int, plant_id: String, pos: Vector2i) -> void:
	# 装备 1 个词条到植物：从仓库扣 1 个，加到植物 bag_entries。
	# 同植物同词条（同 id+level）由 PlantData.equip_entry 去重，不重复装。
	var k := _key(entry_id, level)
	if not entries.has(k):
		return
	var entry: Resource = entries[k]
	if entry.count <= 0:
		return
	var plant: Resource = plants.get(plant_id)
	if plant == null:
		return
	# 先校验植物侧没装过同种词条（同 id，不论等级），避免扣了 count 却没装上。
	for e in plant.bag_entries:
		if e["entry_id"] == entry_id:
			Toast.popup("同样的词条只能装备1个")
			return
	plant.equip_entry(entry_id, level, pos)
	entry.count -= 1
	if entry.count <= 0:
		entries.erase(k)
		warehouse_positions.erase(k)
	save()

func unequip_entry(entry_id: String, level: int, plant_id: String) -> void:
	# 卸下词条：从植物 bag_entries 移除，回仓库 +1（若无则重建 count=1）。
	var plant: Resource = plants.get(plant_id)
	if plant == null:
		return
	# 校验植物确实装了这条，避免凭空加 count。
	var has_it := false
	for e in plant.bag_entries:
		if e["entry_id"] == entry_id and int(e.get("level", 1)) == level:
			has_it = true
			break
	if not has_it:
		return
	plant.unequip_entry(entry_id, level)
	var k := _key(entry_id, level)
	if entries.has(k):
		entries[k].count += 1
	else:
		var data := EntryDataClass.new()
		data.entry_id = entry_id
		data.count = 1
		data.level = level
		entries[k] = data
	save()

func get_bag_entries(plant_id: String) -> Array:
	# 返回该植物装备的词条位置列表 [{entry_id, level, pos}]，委托 PlantData。
	var plant: Resource = plants.get(plant_id)
	if plant == null:
		return []
	return plant.get_bag_entries()

# ── 关卡进度 API ──────────────────────────────────────────────────────

func mark_level_cleared(index: int) -> void:
	# 通关第 index 关（0-based）。只前进不后退，取较大值。
	if index + 1 > cleared_level_count:
		cleared_level_count = index + 1
	# 记录该关通关次数（用于动态难度：每通关一次僵尸 +20%）。
	level_clear_counts[index] = level_clear_counts.get(index, 0) + 1
	save()

func get_level_clear_count(index: int) -> int:
	# 返回该关已通关次数（0 = 从未通关，1 = 通关过一次）。
	return level_clear_counts.get(index, 0)

func get_level_zombie_scale(index: int) -> float:
	# 返回该关当前僵尸属性倍率：ZOMBIE_SCALE_PER_CLEAR ^ 通关次数。0 次 = 1.0x。
	return pow(ZOMBIE_SCALE_PER_CLEAR, get_level_clear_count(index))

func is_level_unlocked(index: int) -> bool:
	# 第 index 关是否已解锁：第 0 关默认解锁，其余需前一关通关。
	return index <= cleared_level_count
