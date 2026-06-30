extends Control
# 词条详情面板：单击词条卡片时弹出，显示词条名/描述/修饰器列表，带装备或卸下按钮。
# 装备/卸下的实际业务由 plant_list_panel 监听 action_clicked 信号处理（需要选中植物和 bag 上下文）。

signal action_clicked(entry_id: String, level: int)
signal compose_clicked(entry_id: String, level: int)

@onready var name_label: Label = $Frame/VBox/NameLabel
@onready var desc_label: Label = $Frame/VBox/DescLabel
@onready var mods_label: Label = $Frame/VBox/ModsLabel
@onready var level_label: Label = $Frame/VBox/LevelLabel
@onready var compose_btn: Button = $Frame/VBox/ComposeButton
@onready var action_btn: Button = $Frame/VBox/ActionButton
@onready var close_btn: Button = $Frame/CloseBtn

var _entry_id: String = ""
var _entry_level: int = 1

func _ready() -> void:
	visible = false
	action_btn.pressed.connect(_on_action_pressed)
	compose_btn.pressed.connect(_on_compose_pressed)
	close_btn.pressed.connect(close)

func setup(entry_id: String, is_from_bag: bool, can_compose: bool = false, level: int = 1) -> void:
	# is_from_bag = true：词条来自植物背包，按钮显示"卸下"；否则来自仓库，显示"装备"。
	# can_compose：当前能否合成升级（聚合所有等级词条点数判断），决定合成按钮启用。
	_entry_id = entry_id
	_entry_level = level
	var def: Resource = EntryTable.get_def(entry_id)
	if def == null:
		return
	name_label.text = def.display_name + _level_stars(level)
	desc_label.text = def.description
	mods_label.text = _format_modifiers(def.modifiers, level)
	level_label.text = ""
	compose_btn.disabled = not can_compose
	compose_btn.text = "合成"
	action_btn.text = "卸下" if is_from_bag else "装备"
	visible = true

func _level_stars(level: int) -> String:
	# 等级用星数表示：1阶★、2阶★★...
	var s := ""
	for _i in level:
		s += "★"
	return s

func _format_modifiers(modifiers: Array, level: int = 1) -> String:
	if modifiers.is_empty():
		return "无属性加成"
	var parts: PackedStringArray = []
	for m in modifiers:
		var stat: String = _stat_label(String(m.get("stat", "")))
		var value: float = float(m.get("value", 0.0)) * level
		var mode: String = String(m.get("mode", "add"))
		var sign: String = "+" if value >= 0 else ""
		if mode == "pct":
			parts.append("%s%s%.0f%%" % [stat, sign, value * 100.0])
		else:
			parts.append("%s%s%.0f" % [stat, sign, value])
	return "\n".join(parts)

func _stat_label(stat: String) -> String:
	match stat:
		"hp": return "血量"
		"damage": return "攻击"
		"range": return "射程"
		"attack_speed": return "攻速"
		_: return stat

func _on_action_pressed() -> void:
	action_clicked.emit(_entry_id, _entry_level)
	close()

func _on_compose_pressed() -> void:
	compose_clicked.emit(_entry_id, _entry_level)
	close()

func close() -> void:
	visible = false
