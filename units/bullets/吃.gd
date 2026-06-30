extends "bullet_base.gd"
# 僵尸的"吃"子弹：飞向最近的植物造成伤害。

func _ready() -> void:
	texture = preload("res://assets/zombies/咬.png")
	super._ready()
	# 拉伸到 48x48。
	for c in get_children():
		if c is Sprite2D:
			var tex: Texture2D = c.texture
			if tex != null and tex.get_width() > 0:
				c.scale = Vector2(48.0 / tex.get_width(), 48.0 / tex.get_height())
			break

func _target_group() -> String:
	return "plant"                                    # 僵尸打植物。
