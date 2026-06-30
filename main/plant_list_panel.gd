extends Control
const TILE_PX := 48.0    
@onready var close_btn: BaseButton = $Control/CloseBtn
@onready var list: Control = %PlantList
@onready var warehouse: Control = $Control/Warehouse
@onready var entry_bag: Control =$Control/PlantDetail/EntryBag
@onready var plant_icon: TextureRect = $Control/PlantDetail/SpriteContainer/TextureRect
@onready var hp_label: Label = $Control/PlantDetail/PlantData/HP
@onready var attack_label: Label = $Control/PlantDetail/PlantData/Attack
@onready var attack_range_label: Label = $Control/PlantDetail/PlantData/AttackRange
@onready var attack_speed_label: Label = $Control/PlantDetail/PlantData/AttackSpeed
const EntryCardClass := preload("res://main/entry_card.gd")
const PlantCardScene := preload("res://main/plant_card.tscn")
const EntryDetailPanelScene := preload("res://main/entry_detail_panel.tscn")
var _data: Resource
var _selected_card: PlantCard = null
var _entry_detail: Control
var _detail_is_from_bag: bool = false

# 拖拽状态
var _drag_entry_id: String = ""
var _drag_entry_level: int = 1
var _drag_source_bag: Control = null
var _drag_preview: Control = null
var _drag_preview_size: Vector2 = Vector2.ZERO
var _drag_offset: Vector2 = Vector2.ZERO  # 拖拽开始时鼠标相对卡片左上角的全局偏移

func _ready() -> void:
	warehouse.entry_double_clicked.connect(_on_warehouse_double_clicked)
	entry_bag.entry_double_clicked.connect(_on_bag_double_clicked)
	warehouse.entry_single_clicked.connect(_on_warehouse_single_clicked)
	entry_bag.entry_single_clicked.connect(_on_bag_single_clicked)
	warehouse.entry_drag_started.connect(_on_card_drag_started)
	entry_bag.entry_drag_started.connect(_on_card_drag_started)
	close_btn.pressed.connect(close)
	PlayerData.entries_changed.connect(_refresh_warehouse)
	_entry_detail = EntryDetailPanelScene.instantiate()
	add_child(_entry_detail)
	_entry_detail.action_clicked.connect(_on_entry_detail_action)
	_entry_detail.compose_clicked.connect(_on_entry_detail_compose)
	
func open():
	visible = true
	_refresh()
	
func _refresh() -> void:
	_selected_card = null
	list.clear_cards()
	var first_data: Resource = null
	for def in PlantTable.get_all():
		var data: Resource = PlayerData.get_plant(def.id)
		var card: PlantCard = PlantCardScene.instantiate()
		card.setup(def, data)
		card.pressed.connect(_on_card_pressed)
		list.add_card(card)
		if data != null and data.unlocked and first_data == null:
			first_data = data
	if first_data != null:
		_select_card(first_data)
		_show_plant(first_data)

func _on_card_pressed(data: Resource) -> void:
	_select_card(data)
	_show_plant(data)

func _select_card(data: Resource) -> void:
	if _selected_card != null and is_instance_valid(_selected_card):
		_selected_card.set_selected(false)
	_selected_card = null
	for i: int in list.get_card_count():
		var card: PlantCard = list.get_card(i) as PlantCard
		if card.get_meta("plant_id", "") == data.plant_id:
			_selected_card = card
			card.set_selected(true)
			list.set_selected(i)
			break

func close():
	visible = false
	_refresh_warehouse()

func _refresh_bag() -> void:
	print("_refresh_bag()")
	# 按选中植物的 bag_entries 在中栏背包指定位置渲染词条卡片。
	entry_bag.clear_entries()
	if _data == null:
		return
	for e in _data.get_bag_entries():
		var def: Resource = EntryTable.get_def(e["entry_id"])
		if def == null:
			continue
		var entry_name: String = def.display_name
		var size: Vector2i = Vector2i(entry_name.length(), 1)
		var lvl: int = int(e.get("level", 1))
		var card: Control = _make_entry_card(e["entry_id"], entry_name, size, 1, lvl)
		entry_bag.place_entry_at(card, size, e["pos"])


func _show_plant(data: Resource) -> void:
	_data = data
	var def: Resource = data.get_def()
	if def == null:
		return
	plant_icon.texture = def.icon
	_fit_icon_to_container()
	_refresh_stats()
	_refresh_bag()

func _fit_icon_to_container() -> void:
	# 按图片原始宽高比和容器可用空间设尺寸，保持比例不变形。
	var tex: Texture2D = plant_icon.texture
	if tex == null:
		return
	var container: Control = plant_icon.get_parent()
	var avail: Vector2 = container.size
	if avail.x <= 0 or avail.y <= 0:
		call_deferred("_fit_icon_to_container")
		return
	var img_size: Vector2 = tex.get_size()
	if img_size.x <= 0 or img_size.y <= 0:
		return
	var max_size := Vector2(avail.x - 16, min(avail.y - 8, 120.0))
	var scale: float = min(max_size.x / img_size.x, max_size.y / img_size.y)
	var target: Vector2 = img_size * scale
	plant_icon.custom_minimum_size = target
	plant_icon.offset_left = -target.x * 0.5
	plant_icon.offset_top = -target.y * 0.5
	plant_icon.offset_right = target.x * 0.5
	plant_icon.offset_bottom = target.y * 0.5

func _refresh_stats() -> void:
	# 刷新中栏属性数字（词条装备/卸下后必须重算）。
	if _data == null:
		return
	var def: Resource = _data.get_def()
	if def == null:
		return
	hp_label.text = "血量:%d" % int(_data.get_max_hp())
	attack_label.text = "攻击:%d" % int(_data.get_damage())
	attack_range_label.text = "射程:%d" % int(_data.get_range())
	# 攻速：base_attack_interval <= 0 的植物（阿葵/阿坚/窝哥）显示 --；其余按 实际间隔 = 基础/倍率 显示秒数。
	if def.base_attack_interval <= 0.0:
		attack_speed_label.text = "攻速:--"
	else:
		var interval: float = def.base_attack_interval / max(_data.get_attack_speed(), 0.01)
		attack_speed_label.text = "攻速:%.1f秒" % interval
	
func _refresh_warehouse() -> void:
	# 从 PlayerData 取仓库词条，按记忆位置放置；无记忆或冲突则自动找位并记录。
	warehouse.clear_entries()
	for data in PlayerData.get_warehouse_entries():
		var def: Resource = data.get_def()
		if def == null:
			continue
		var entry_name: String = def.display_name
		var size: Vector2i = Vector2i(entry_name.length(), 1)
		var card: Control = _make_entry_card(data.entry_id, entry_name, size, data.count, data.level)
		var pos: Vector2i = PlayerData.get_warehouse_pos(data.entry_id, data.level)
		if pos.x < 0 or not warehouse.can_place_at(pos, size):
			pos = warehouse.find_free_pos(size)
			if pos.x < 0:
				card.queue_free()
				continue
			PlayerData.set_warehouse_pos(data.entry_id, data.level, pos)
		warehouse.place_entry_at(card, size, pos)

func _make_entry_card(entry_id: String, entry_name: String, size: Vector2i, count: int = 1, level: int = 1) -> Control:
	var card: Control = EntryCardClass.new()
	card.entry_id = entry_id
	card.entry_name = entry_name
	card.entry_size = size
	card.entry_count = count
	card.entry_level = level
	return card

func _on_warehouse_double_clicked(entry_id: String, level: int) -> void:
	# 双击仓库词条：装到选中植物背包，找空位放置。
	if _data == null:
		return
	var def: Resource = EntryTable.get_def(entry_id)
	if def == null:
		return
	var size: Vector2i = Vector2i(def.display_name.length(), 1)
	var pos: Vector2i = entry_bag.find_free_pos(size)
	if pos.x < 0:
		return
	PlayerData.equip_entry(entry_id, level, _data.plant_id, pos)
	_show_plant(_data)
	_refresh_warehouse()

func _on_bag_double_clicked(entry_id: String, level: int) -> void:
	# 双击背包词条：卸下回仓库。
	if _data == null:
		return
	PlayerData.unequip_entry(entry_id, level, _data.plant_id)
	_show_plant(_data)
	_refresh_warehouse()

func _on_warehouse_single_clicked(entry_id: String, level: int) -> void:
	_open_entry_detail(entry_id, level, false)

func _on_bag_single_clicked(entry_id: String, level: int) -> void:
	_open_entry_detail(entry_id, level, true)

func _open_entry_detail(entry_id: String, level: int, is_from_bag: bool) -> void:
	_detail_is_from_bag = is_from_bag
	# 合成按钮启用条件：聚合所有等级词条点数判断。
	var can: bool = PlayerData.can_compose(entry_id, level)
	_entry_detail.setup(entry_id, is_from_bag, can, level)

func _on_entry_detail_compose(entry_id: String, level: int) -> void:
	# 合成：消耗 3 个升一级。从背包发起时，结果留在原植物原位置（升级在位）。
	if _detail_is_from_bag and _data != null:
		var pos: Vector2i = _data.get_entry_pos(entry_id, level)
		if not PlayerData.compose_entry(entry_id, level, _data.plant_id, pos):
			return
	else:
		if not PlayerData.compose_entry(entry_id, level):
			return
	_show_plant(_data)
	_refresh_warehouse()

func _on_entry_detail_action(entry_id: String, level: int) -> void:
	# 详情面板按钮：根据词条来源决定装备或卸下。
	if _data == null:
		return
	if _detail_is_from_bag:
		PlayerData.unequip_entry(entry_id, level, _data.plant_id)
	else:
		var def: Resource = EntryTable.get_def(entry_id)
		if def == null:
			return
		var size: Vector2i = Vector2i(def.display_name.length(), 1)
		var pos: Vector2i = entry_bag.find_free_pos(size)
		if pos.x < 0:
			return
		PlayerData.equip_entry(entry_id, level, _data.plant_id, pos)
	_show_plant(_data)
	_refresh_warehouse()

# ── 拖拽 ──────────────────────────────────────────────────────────────

func _on_card_drag_started(card: Control) -> void:
	if _drag_entry_id != "":
		return
	_drag_entry_id = card.entry_id
	_drag_entry_level = card.entry_level
	_drag_source_bag = card.get_parent()
	_drag_preview = _make_entry_card(card.entry_id, card.entry_name, card.entry_size, 1, card.entry_level)
	_drag_preview.modulate.a = 0.85
	# 直接按格数算尺寸，不依赖 _ready（add_child 后 _ready 才跑，size 还没设）。
	_drag_preview_size = Vector2(card.entry_size.x * 60, card.entry_size.y * 60)
	_drag_preview.custom_minimum_size = _drag_preview_size
	_drag_preview.size = _drag_preview_size
	add_child(_drag_preview)
	_drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 记录鼠标与卡片的相对偏移，拖拽过程中保持不变，避免吸附到鼠标中心显得突兀。
	_drag_offset = get_global_mouse_position() - card.global_position
	_update_preview_pos(get_global_mouse_position())
	card.visible = false

func _process(_delta: float) -> void:
	if _drag_entry_id == "":
		return
	# 每帧主动跟踪鼠标全局位置，更新预览和落点高亮（比 mouse_motion 事件更跟手）。
	var gp: Vector2 = get_global_mouse_position()
	_update_preview_pos(gp)
	_update_hover_preview(gp)

func _input(event: InputEvent) -> void:
	if _drag_entry_id == "":
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_drag()

func _global_to_bag_local(bag: Control, global_pos: Vector2) -> Vector2:
	# 全局坐标 → bag 局部坐标（用 canvas 变换矩阵的逆，处理所有父级偏移/缩放）。
	return bag.get_global_transform_with_canvas().affine_inverse() * global_pos

func _update_preview_pos(global_pos: Vector2) -> void:
	if _drag_preview == null:
		return
	# 预览保持拖拽开始时鼠标与卡片的相对位置，不吸附到中心。
	_drag_preview.global_position = global_pos - _drag_offset

func _update_hover_preview(global_pos: Vector2) -> void:
	var def: Resource = EntryTable.get_def(_drag_entry_id)
	if def == null:
		return
	var size: Vector2i = Vector2i(def.display_name.length(), 1)
	var bag: Control = _find_bag_at(global_pos)
	entry_bag.clear_hover_preview()
	warehouse.clear_hover_preview()
	if bag == null:
		return
	# 落点 = 预览左上角像素 round 到最近格中心（预览居中于鼠标，视觉与判定一致）。
	var local: Vector2 = _global_to_bag_local(bag, global_pos)
	var top_left_local: Vector2 = local - Vector2(size.x * 60, size.y * 60) * 0.5
	var cell: Vector2i = bag.pos_to_cell_rounded(top_left_local)
	cell = bag.clamp_cell_to_fit(cell, size)
	var ignore: String = _drag_key() if bag == _drag_source_bag else ""
	var valid: bool = bag.can_place_at(cell, size, ignore)
	bag.set_hover_preview(cell, size, valid)

func _finish_drag() -> void:
	var entry_id := _drag_entry_id
	var entry_level := _drag_entry_level
	var source := _drag_source_bag
	var gp: Vector2 = get_global_mouse_position()
	entry_bag.clear_hover_preview()
	warehouse.clear_hover_preview()
	if _drag_preview != null:
		_drag_preview.queue_free()
		_drag_preview = null
	_drag_entry_id = ""
	_drag_entry_level = 1
	_drag_source_bag = null

	var target_bag: Control = _find_bag_at(gp)
	if target_bag == null:
		_refresh_after_drag(source)
		return
	var def: Resource = EntryTable.get_def(entry_id)
	if def == null:
		_refresh_after_drag(source)
		return
	var size: Vector2i = Vector2i(def.display_name.length(), 1)
	# 落点 = 预览左上角像素 round 到最近格中心（与 _update_hover_preview 一致）。
	var local: Vector2 = _global_to_bag_local(target_bag, gp)
	var top_left_local: Vector2 = local - Vector2(size.x * 60, size.y * 60) * 0.5
	var cell: Vector2i = target_bag.pos_to_cell_rounded(top_left_local)
	cell = target_bag.clamp_cell_to_fit(cell, size)
	var ignore: String = _key(entry_id, entry_level) if source == target_bag else ""
	if not target_bag.can_place_at(cell, size, ignore):
		_refresh_after_drag(source)
		_refresh_after_drag(target_bag)
		return

	if source == target_bag and source == entry_bag:
		# 背包内移动：直接改 bag_entries 里的 pos（按 entry_id+level 定位）。
		for e in _data.bag_entries:
			if e["entry_id"] == entry_id and int(e.get("level", 1)) == entry_level:
				e["pos"] = cell
				break
		_refresh_bag()
	elif source == warehouse and target_bag == entry_bag:
		if _data == null:
			_refresh_after_drag(source)
			return
		PlayerData.equip_entry(entry_id, entry_level, _data.plant_id, cell)
		_refresh_stats()
		_refresh_bag()
		_refresh_warehouse()
	elif source == entry_bag and target_bag == warehouse:
		PlayerData.unequip_entry(entry_id, entry_level, _data.plant_id)
		PlayerData.set_warehouse_pos(entry_id, entry_level, cell)
		_refresh_stats()
		_refresh_bag()
		_refresh_warehouse()
	elif source == warehouse and target_bag == warehouse:
		# 仓库内移动：更新记忆位置。
		PlayerData.set_warehouse_pos(entry_id, entry_level, cell)
		_refresh_warehouse()

func _drag_key() -> String:
	return _key(_drag_entry_id, _drag_entry_level)

func _key(entry_id: String, level: int) -> String:
	return "%s#%d" % [entry_id, level]

func _refresh_after_drag(source: Control) -> void:
	if source == entry_bag:
		_refresh_bag()
	else:
		_refresh_warehouse()

func _find_bag_at(global_pos: Vector2) -> Control:
	for bag in [entry_bag, warehouse]:
		if bag.get_global_rect().has_point(global_pos):
			return bag
	return null
