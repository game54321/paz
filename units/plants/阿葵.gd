extends "plant_base.gd"
# 向日葵：自带发光效果，用 _draw 画一个和迷雾点亮区一致的 10x10 正方形渐变光晕。
# 纯 CanvasItem 绘制，不依赖 PointLight2D（gl_compatibility 下光照性能差），不依赖后处理。
# 光晕尺寸 = FOG_REVEAL_SIZE * tile_size，和 PlacementManager 的迷雾逻辑严格对齐。


const GLOW_COLOR := Color(1.0, 0.85, 0.4, 0.18)  # 暖黄半透明，alpha 控制光晕强度。

# 产灵气参数。
const SUN_DROP_INTERVAL := 12.0                    # 多久产一个灵气球（秒）。
const SUN_DROP_VALUE := 25                        # 灵气球价值。
const SUN_DROP_RADIUS := 60.0                     # 灵气球掉落在阿葵周围的半径（像素）。

var _sun_timer := 0.0

func _ready() -> void:
	size = Vector2i(2, 1) 
	super._ready()
	provides_vision = true                          # 向日葵点亮周围迷雾。
	z_index = ZIndex.PLANT_AURA                                     # 让光晕画在普通植物之上、grid_map 高亮之下。

func _process(delta: float) -> void:
	super._process(delta)                           # plant_base._process：呼吸摇晃 + 刷血条。
	if PlacementManager.dragging_plant == self:     # 拖拽中不产灵气。
		return
	_sun_timer += delta
	if _sun_timer >= SUN_DROP_INTERVAL:
		_sun_timer = 0.0
		_drop_sun()

func _drop_sun() -> void:
	var sun_scene := preload("res://units/sun/sun.tscn")
	var sun := sun_scene.instantiate()
	var sun_layer := get_tree().get_first_node_in_group("sun_layer")
	if sun_layer:
		sun_layer.add_child(sun)
	else:
		get_tree().current_scene.add_child(sun)
	# 在阿葵周围随机掉落。add_child 后调 setup 设位置（_ready 时位置还没设，不能在那里捕获 _base_y）。
	var angle := randf() * TAU
	var dist := randf() * SUN_DROP_RADIUS
	sun.setup(global_position + Vector2(cos(angle), sin(angle)) * dist, SUN_DROP_VALUE)

func _draw() -> void:
	super._draw()                                   # 保留 unit_base 画的血条。
	var tm := PlacementManager.get_tile_map()
	if tm == null:
		return
	var tile_size := Vector2(tm.tile_set.tile_size)
	# 10x10 正方形的半边长（像素），和 PlacementManager.FOG_REVEAL_SIZE 对齐。
	var half := PlacementManager.FOG_REVEAL_SIZE * 0.5 * tile_size.x
	# 用多层同心正方形模拟径向渐变，从中心向外淡出。
	var layers := 8
	if PlacementManager.dragging_plant != self:
		return
	for i in layers:
		var t := float(i) / float(layers - 1)        # 0 = 最内层，1 = 最外层。
		var a := (1.0 - t) * GLOW_COLOR.a            # 中心最亮，边缘淡出。
		var col := Color(GLOW_COLOR.r, GLOW_COLOR.g, GLOW_COLOR.b, a)
		var s := half * (0.3 + 0.7 * t)              # 从内圈 30% 渐变到外圈 100%。
		var r := Rect2(Vector2(-s, -s), Vector2(s * 2, s * 2))
		draw_rect(r, col, true)
