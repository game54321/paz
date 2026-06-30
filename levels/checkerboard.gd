extends TileMapLayer
# 棋盘格瓦片：运行时把已有瓦片按 (x+y)%2 切换成两种 atlas 坐标,实现国际象棋交替效果。
# 挂到任意关卡 TileMapLayer 上即可,无需每个关卡写代码。

const TILE_LIGHT := Vector2i(1, 1)  # 浅色瓦片 atlas 坐标。
const TILE_DARK := Vector2i(10, 1)   # 深色瓦片 atlas 坐标。

func _ready() -> void:
	_make_checkerboard()

func _make_checkerboard() -> void:
	var used := get_used_rect()
	for y in range(used.position.y, used.end.y):
		for x in range(used.position.x, used.end.x):
			var c := Vector2i(x, y)
			var src := get_cell_source_id(c)
			if src == -1:
				continue
			var is_light := (c.x + c.y) % 2 == 0
			set_cell(c, src, TILE_LIGHT if is_light else TILE_DARK)
