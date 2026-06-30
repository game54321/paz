extends Control
# Debug 僵尸属性查看面板：show_dump 传入僵尸节点数组，列表展示血量/攻击/速度。
# 「实时刷新」按钮：开启后每 0.5 秒自动重新拉取僵尸列表。

@onready var list: VBoxContainer = $Frame/Scroll/List
@onready var close_btn: Button = $Frame/CloseBtn
@onready var refresh_btn: Button = $Frame/RefreshBtn

var _auto_refresh: bool = false
var _timer: float = 0.0
const REFRESH_INTERVAL := 0.5

func _ready() -> void:
	visible = false
	close_btn.pressed.connect(close)
	refresh_btn.pressed.connect(_on_refresh_pressed)

func _process(delta: float) -> void:
	if not _auto_refresh or not visible:
		return
	_timer += delta
	if _timer >= REFRESH_INTERVAL:
		_timer = 0.0
		_refresh()

func _on_refresh_pressed() -> void:
	_auto_refresh = not _auto_refresh
	refresh_btn.text = "停止刷新" if _auto_refresh else "实时刷新"
	if _auto_refresh:
		_refresh()

func _refresh() -> void:
	_show_dump(get_tree().get_nodes_in_group("zombie"))

func close() -> void:
	_auto_refresh = false
	refresh_btn.text = "实时刷新"
	visible = false

func show_dump(zombies: Array) -> void:
	_show_dump(zombies)
	visible = true

func _show_dump(zombies: Array) -> void:
	for c in list.get_children():
		c.queue_free()
	if zombies.is_empty():
		var lbl := Label.new()
		lbl.text = "当前无僵尸"
		list.add_child(lbl)
	else:
		for z in zombies:
			if not is_instance_valid(z):
				continue
			var name: String = z.name
			var hp: float = float(z.hp) if "hp" in z else 0.0
			var max_hp: float = float(z.max_hp) if "max_hp" in z else 0.0
			var dmg: float = float(z.attack_damage) if "attack_damage" in z else 0.0
			var speed: float = float(z.speed) if "speed" in z else 0.0
			var lbl := Label.new()
			lbl.text = "%s\n  血量 %.0f / %.0f\n  攻击 %.0f\n  速度 %.0f" % [name, hp, max_hp, dmg, speed]
			list.add_child(lbl)
