extends Node2D

const DeathBurst := preload("res://units/death_burst.gd")

@export var max_hp := 100.0
@export var damage := 20.0
@export var is_enemy := false
var hp := 100.0
var _dead := false

@onready var sprite: Sprite2D = $Sprite

const BAR_W := 60.0
const BAR_H := 6.0
@export var bar_offset := Vector2.ZERO  # 默认 Vector2.ZERO：_draw 里按 Sprite 自动算头顶位置；tscn 可覆盖。

func _ready() -> void:
	hp = max_hp
	add_to_group("zombie" if is_enemy else "plant")

func _process(_delta: float) -> void:

	queue_redraw()

func take_damage(amount: float) -> void:
	if _dead:
		return
	hp -= amount
	if hp <= 0:
		_dead = true
		_on_die()
		queue_free()


func _on_die()-> void:
	# 死亡粒子爆发：僵尸红、植物绿。
	var col: Color = Color(0.9, 0.2, 0.2) if is_enemy else Color(0.35, 0.85, 0.35)
	DeathBurst.spawn(global_position, col)

func _get_bar_offset() -> Vector2:
	# 显式设置了就用显式值；否则按 Sprite 纹理高度自动算脚底位置。
	if bar_offset != Vector2.ZERO:
		return bar_offset
	if sprite and sprite.texture:
		# Sprite2D 默认 centered，纹理中心在 sprite.position，脚底 = position.y + 显示高度/2。
		# 显示高度要乘 scale.y（abs 防翻转负值），否则缩放过的 sprite 会算偏。
		return sprite.position + Vector2(0, sprite.texture.get_height() * 0.5 * abs(sprite.scale.y))
	return Vector2(0, 40)  # 兜底：没 Sprite 就放原点下方 40。

func _draw() -> void:
	var ratio :float= clamp(hp / max_hp, 0.0, 1.0)
	if ratio >= 1.0:
		return
	var off := _get_bar_offset()
	var bg := Rect2(off - Vector2(BAR_W * 0.5, 0), Vector2(BAR_W, BAR_H))
	var fg := Rect2(off - Vector2(BAR_W * 0.5, 0), Vector2(BAR_W * ratio, BAR_H))
	draw_rect(bg, Color.BLACK, true)
	draw_rect(fg, Color.RED if is_enemy else Color.GREEN, true)
	draw_rect(bg, Color.WHITE, false, 1.0)
