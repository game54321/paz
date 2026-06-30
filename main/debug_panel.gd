extends CanvasLayer
# Debug 面板（autoload 单例）：全局可调出，按 Ctrl 切换显示。
# 测试用：添加全部词条、加阳光。

@onready var backdrop: ColorRect = $Backdrop
@onready var frame: Control = $Frame
@onready var add_entries_btn: Button = $Frame/VBox/AddEntriesBtn
@onready var add_sun_btn: Button = $Frame/VBox/AddSunBtn
@onready var dump_zombies_btn: Button = $Frame/VBox/DumpZombiesBtn
@onready var close_btn: Button = $Frame/CloseBtn
@onready var zombie_dump_panel: Control = $ZombieDumpPanel

func _ready() -> void:
	backdrop.visible = false
	frame.visible = false
	add_entries_btn.pressed.connect(_on_add_entries)
	add_sun_btn.pressed.connect(_on_add_sun)
	dump_zombies_btn.pressed.connect(_on_dump_zombies)
	close_btn.pressed.connect(close)
	zombie_dump_panel.close()

func _unhandled_input(event: InputEvent) -> void:
	# Ctrl 键唤出/关闭。
	if event is InputEventKey and event.keycode == KEY_CTRL and event.pressed and not event.echo:
		if frame.visible:
			close()
		else:
			open()

func open() -> void:
	backdrop.visible = true
	frame.visible = true

func close() -> void:
	backdrop.visible = false
	frame.visible = false

func _on_add_entries() -> void:
	# 给所有词条各加 3 个，方便测试合成。
	for def in EntryTable.get_all():
		PlayerData.grant_entry(def.id, 3)

func _on_add_sun() -> void:
	# 加阳光（PlacementManager autoload，战斗中生效）。
	PlacementManager.add_sun(99999)

func _on_dump_zombies() -> void:
	# 列出当前场景所有僵尸的实际属性，用于核对难度倍率是否生效。
	zombie_dump_panel.show_dump(get_tree().get_nodes_in_group("zombie"))
