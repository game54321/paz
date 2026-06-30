extends Node
# 关卡掉落配置：挂到关卡场景根节点，配置本关通关掉落表。
# drops 每条形如 "大力:0.5"（词条显示名:权重），权重为浮点。
# 通关时 main.gd 调 get_drops()，按权重随机摇 rolls 次，累加 count。
# 掉落个数 = 当前难度 = 通关次数 + 1（难度1=1个，难度2=2个，难度3=3个）。


@export var drops: Array = []
@export var drop_rolls: int = 1   # 仅作兜底，实际按难度算。

func get_drops() -> Array:
	# 返回实际掉落 [{entry_id, count}]。rolls 次加权随机（可重复），累加同 entry_id 的 count。
	if drops.is_empty():
		return []
	# 解析 "显示名:权重"，显示名 → entry_id。
	var weights: Array[float] = []
	var entry_ids: Array[String] = []
	var total_weight: float = 0.0
	for s in drops:
		var str_s: String = String(s)
		var parts := str_s.split(":", true, 1)
		if parts.size() < 2:
			continue
		var display_name: String = parts[0].strip_edges()
		var w: float = parts[1].to_float()
		var eid: String = _find_entry_id_by_name(display_name)
		if eid == "" or w <= 0.0:
			continue
		weights.append(w)
		entry_ids.append(eid)
		total_weight += w
	if total_weight <= 0.0 or entry_ids.is_empty():
		return []
	# 掉落个数 = 难度 = 通关次数 + 1；未配置关卡索引时退回 drop_rolls。
	var rolls: int = drop_rolls
	var idx: int = SceneManager.pending_level_index
	if idx >= 0:
		rolls = PlayerData.get_level_clear_count(idx) + 1
	if rolls <= 0:
		return []
	var result: Dictionary = {}   # entry_id -> 累计 count
	for _i in rolls:
		var r: float = randf() * total_weight
		var acc: float = 0.0
		for j in entry_ids.size():
			acc += weights[j]
			if r < acc:
				result[entry_ids[j]] = int(result.get(entry_ids[j], 0)) + 1
				break
	var arr: Array = []
	for eid in result:
		arr.append({"entry_id": eid, "count": result[eid]})
	return arr

func _find_entry_id_by_name(display_name: String) -> String:
	# 显示名 → entry_id，查 EntryTable。找不到返回 ""。
	for def in EntryTable.get_all():
		if def.display_name == display_name:
			return def.id
	return ""
