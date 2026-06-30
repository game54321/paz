extends Control
# 启动页面：新的开始 / 旧的回忆 / 关注作者。


@onready var author_panel: Panel = $AuthorPanel
@onready var continue_btn: TextureButton = $Buttons/ContinueButton
@onready var author_gif: TextureRect = $AuthorPanel/AuthorGif

const GIF_SHEET := preload("res://assets/author/author_sheet.png")
const FRAME_SIZE := Vector2i(287, 512)
const FRAME_COUNT := 40
const FPS := 12

var _frames: Array[AtlasTexture] = []
var _frame_idx := 0

func _ready() -> void:
	$Buttons/NewGameButton.pressed.connect(_on_new_game)
	continue_btn.pressed.connect(_on_continue)
	$Buttons/AuthorButton.pressed.connect(_on_author)
	$AuthorPanel/CloseBtn.pressed.connect(_close_author)
	author_panel.visible = false
	continue_btn.disabled = not PlayerData.has_save()
	continue_btn.modulate = Color(0.5, 0.5, 0.5, 1.0) if continue_btn.disabled else Color.WHITE
	_build_gif_frames()
	_play_zombie_jump()

# 把横向 sprite sheet 切成 40 帧 AtlasTexture。
func _build_gif_frames() -> void:
	for i in FRAME_COUNT:
		var at := AtlasTexture.new()
		at.atlas = GIF_SHEET
		at.region = Rect2(i * FRAME_SIZE.x, 0, FRAME_SIZE.x, FRAME_SIZE.y)
		_frames.append(at)
	author_gif.texture = _frames[0]

func _process(_delta: float) -> void:
	if not author_panel.visible or _frames.is_empty():
		return
	var idx := int(Time.get_ticks_msec() * FPS / 1000.0) % FRAME_COUNT
	if idx != _frame_idx:
		_frame_idx = idx
		author_gif.texture = _frames[idx]

# 僵尸跳：三个按钮依次从左侧一蹦一蹦跳到中间。
func _play_zombie_jump() -> void:
	await get_tree().process_frame  # 等 VBoxContainer 布局完成，拿到目标位置
	var buttons: Array[TextureButton] = [$Buttons/NewGameButton, $Buttons/ContinueButton, $Buttons/AuthorButton]
	for i in buttons.size():
		_hop_in(buttons[i], i * 1.0)

func _hop_in(btn: TextureButton, delay: float) -> void:
	var target := btn.position
	var start := Vector2(target.x - 400.0, target.y)
	btn.position = start
	btn.modulate.a = 0.0

	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_property(btn, "modulate:a", 1.0, 0.1)

	const HOPS := 4      # 总跳跃次数
	const HOP_DUR := 0.45 # 每跳用时
	const HOP_H := 26.0   # 每跳拱起高度
	for i in HOPS:
		var from := start.lerp(target, float(i) / HOPS)
		var to := start.lerp(target, float(i + 1) / HOPS)
		tw.tween_method(
			func(t: float) -> void:
				btn.position = from.lerp(to, t) + Vector2(0.0, -sin(t * PI) * HOP_H),
			0.0, 1.0, HOP_DUR
		).set_trans(Tween.TRANS_LINEAR)

func _on_new_game() -> void:
	if PlayerData.has_save():
		var dlg := ConfirmationDialog.new()
		dlg.title = "覆盖存档"
		dlg.dialog_text = "存在旧存档，开始新游戏将覆盖当前存档。是否继续？"
		dlg.ok_button_text = "覆盖"
		dlg.get_cancel_button().text = "取消"
		dlg.confirmed.connect(_start_new_game)
		dlg.canceled.connect(dlg.queue_free)
		add_child(dlg)
		dlg.popup_centered()
	else:
		_start_new_game()

func _start_new_game() -> void:
	PlayerData.new_game()
	get_tree().change_scene_to_file("res://main/main.tscn")

func _on_continue() -> void:
	if not PlayerData.continue_game():
		return
	get_tree().change_scene_to_file("res://main/main.tscn")

func _on_author() -> void:
	author_panel.visible = true

func _close_author() -> void:
	author_panel.visible = false
