extends "阿葵.gd"
# 基地向日葵：左上方的核心建筑，被打爆即游戏失败。继承阿葵的产阳光/光晕。
# 视觉上用旋转金环 + 更亮的脉动光晕区分普通阿葵。


signal base_destroyed

# 金环参数。
const RING_RADIUS := 70.0                       # 金环半径（像素），略大于光晕外圈，画在外侧。
const RING_COLOR := Color(1.0, 0.85, 0.3, 0.9)  # 金色描边。
const RING_THICKNESS := 3.0                     # 描边线宽。
const RING_ROTATE_SPEED := 0.6                  # 旋转速度（弧度/秒）。
# 脉动光晕覆盖阿葵原 GLOW_COLOR 的 alpha，比普通阿葵更亮。
const BASE_GLOW_ALPHA := 0.30                   # 0.18(普通阿葵) → 0.30，更醒目。
const PULSE_AMP := 0.08                         # 脉动幅度（叠加在 BASE_GLOW_ALPHA 上）。
const PULSE_PERIOD := 2.0                       # 脉动周期（秒）。

var _ring_angle := 0.0


func _process(delta: float) -> void:
	super._process(delta)
	_time += delta
	_ring_angle += delta * RING_ROTATE_SPEED

func _draw() -> void:
	super._draw()
	# 脉动光晕：在阿葵原本的静态光晕之上再叠一层会呼吸的高亮方块。
	var tm := PlacementManager.get_tile_map()
	if tm == null:
		return
	var tile_size := Vector2(tm.tile_set.tile_size)
	var half := PlacementManager.FOG_REVEAL_SIZE * 0.5 * tile_size.x
	var pulse := BASE_GLOW_ALPHA + sin(_time / PULSE_PERIOD * TAU) * PULSE_AMP
	var col := Color(GLOW_COLOR.r, GLOW_COLOR.g, GLOW_COLOR.b, pulse)
	var s := half * 0.5                          # 内层方块，叠在阿葵光晕中心强化亮度。
	#draw_rect(Rect2(Vector2(-s, -s), Vector2(s * 2, s * 2)), col, true)
	# 旋转金环：4 段弧拼成，每段之间留缺口，形成"法阵"感。
	var arc_count := 4
	var gap := 0.3                               # 每段弧后留 0.3 弧度的缺口。
	var seg := (TAU - gap * arc_count) / float(arc_count)
	for i in arc_count:
		var start := _ring_angle + i * (seg + gap)
		draw_arc(Vector2.ZERO, RING_RADIUS, start, start + seg, 16, RING_COLOR, RING_THICKNESS)

func _on_die() -> void:
	base_destroyed.emit()
	super._on_die()
