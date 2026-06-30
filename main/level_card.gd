extends Button

@export_file("*.tscn") var level_path: String
@export var level_index: int = -1
@export var location_name: String = ""
@export var chapter_text: String = "第一章"
@export var subtitle: String = "推荐等级 1"
@export var status_text: String = "可挑战"
@export var locked: bool = false

const CARD_SIZE := Vector2(220, 150)
const CARD_RADIUS := 10.0
const BASE_COLOR := Color(0.13, 0.12, 0.1, 0.96)
const PANEL_COLOR := Color(0.22, 0.18, 0.13, 0.76)
const EDGE_COLOR := Color(0.92, 0.73, 0.42, 0.9)
const LOCKED_COLOR := Color(0.22, 0.22, 0.22, 0.9)
const CLEAR_COLOR := Color(0, 0, 0, 0)


func _ready() -> void:
	pressed.connect(_on_pressed)
	clip_contents = true
	custom_minimum_size = CARD_SIZE
	_refresh()


@onready var _name_label: Label = $NameLabel
@onready var _clear_info_label: Label = $ClearInfoLabel
@onready var _drops_label: Label = $DropsLabel


func _on_pressed() -> void:
	if locked or level_path.is_empty():
		return
	SceneManager.enter_battle(level_path, level_index)

func _refresh() -> void:
	var display_title := location_name if not location_name.is_empty() else text
	_name_label.text = display_title
	text = ""
	modulate = LOCKED_COLOR if locked else Color.WHITE
	# 通关次数 + 当前敌人属性倍数：未通关显示难度 1，通关 N 次显示难度 N+1。
	if not locked and level_index >= 0:
		var n: int = PlayerData.get_level_clear_count(level_index)
		var mult: float = PlayerData.get_level_zombie_scale(level_index)
		_clear_info_label.text = "难度 %d\n敌人属性 %.2f 倍" % [n + 1, mult]
	else:
		_clear_info_label.text = ""
	# 掉落词条描述：从 level_path 读 drops 配置，解析显示名查 EntryDef.description。
	if not locked and not level_path.is_empty():
		_drops_label.text = _build_drops_text()
	else:
		_drops_label.text = ""

func _build_drops_text() -> String:
	var packed: PackedScene = load(level_path)
	if packed == null:
		return ""
	var inst: Node = packed.instantiate()
	var drops: Array = []
	if inst.get("drops") != null:
		drops = inst.get("drops")
	inst.free()
	if drops.is_empty():
		return ""
	var names: Array[String] = []
	for s in drops:
		var parts := String(s).split(":", true, 1)
		if parts.size() < 2:
			continue
		names.append(parts[0].strip_edges())
	if names.is_empty():
		return ""
	return "掉落：" + "、".join(names)
