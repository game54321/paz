extends CanvasLayer
# 全局 Toast 提示：Toast.popup("文本") 即可居中弹一段文字，自动淡出。
# 同时只显示一条，新提示覆盖旧的。

var _label: Label
var _timer: float = 0.0
var _duration: float = 1.6

func _ready() -> void:
	layer = 100
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 28)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("shadow_offset_x", 2)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	_label.modulate.a = 0.0
	add_child(_label)
	process_mode = Node.PROCESS_MODE_ALWAYS

func popup(text: String) -> void:
	_label.text = text
	_label.modulate.a = 1.0
	_timer = _duration

func _process(delta: float) -> void:
	if _timer <= 0.0:
		return
	_timer -= delta
	if _timer <= 0.0:
		_label.modulate.a = 0.0
		return
	# 后 0.4 秒淡出。
	if _timer < 0.4:
		_label.modulate.a = _timer / 0.4
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_label.position = Vector2(vp.x * 0.5, vp.y * 0.3) - _label.size * 0.5
