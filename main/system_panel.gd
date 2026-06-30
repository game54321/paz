extends CanvasLayer
# 系统设置面板：BGM 开关 + 音量滑条。状态走 BGM 单例持久化。


signal closed

@onready var bg: ColorRect = $BG
@onready var panel: Control = $SystemPanel
@onready var music_check: CheckBox = $SystemPanel/MusicCheck
@onready var volume_slider: HSlider = $SystemPanel/VolumeSlider
@onready var close_btn: Button = $SystemPanel/CloseBtn

func _ready() -> void:
	music_check.toggled.connect(BGM.set_enabled)
	volume_slider.value_changed.connect(BGM.set_volume)
	close_btn.pressed.connect(close)
	_refresh()

func open() -> void:
	_refresh()
	bg.visible = true
	panel.visible = true

func close() -> void:
	bg.visible = false
	panel.visible = false
	closed.emit()

func _refresh() -> void:
	music_check.set_pressed_no_signal(BGM.is_enabled())
	volume_slider.set_value_no_signal(BGM.get_volume())
