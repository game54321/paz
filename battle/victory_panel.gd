extends CanvasLayer
# 胜利面板：打爆所有墓碑 + 清光僵尸时弹出。重试/返回按钮交 main.gd 连接处理。
# 通关时 main.gd 传入掉落列表，面板自动发放到 PlayerData 并展示。


signal return_pressed

@onready var panel: Control = $VictoryPanel
@onready var return_btn: Button = $VictoryPanel/ReturnBtn
@onready var drops_container: VBoxContainer = $VictoryPanel/DropsContainer

func _ready() -> void:
	return_btn.pressed.connect(func(): return_pressed.emit())

func is_shown() -> bool:
	return panel.visible

func show_panel(drops: Array = []) -> void:
	# 发放掉落并展示。drops: [{entry_id, count}]。
	for child in drops_container.get_children():
		child.queue_free()
	for e in drops:
		var eid: String = e.get("entry_id", "")
		var cnt: int = int(e.get("count", 1))
		if eid == "":
			continue
		PlayerData.grant_entry(eid, cnt)
		var def: Resource = EntryTable.get_def(eid)
		var name: String = def.display_name if def != null else eid
		var lbl := Label.new()
		lbl.text = "获得：%s ×%d" % [name, cnt]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		drops_container.add_child(lbl)
	panel.visible = true
