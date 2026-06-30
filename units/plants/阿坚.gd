extends "plant_base.gd"
# 坚果：高血量防御植物，不攻击。植物大战僵尸里的坚果墙，挡在前线扛伤害。
# 高血量由 PlantDef.base_hp 配置（plant_table.gd 里设 1500），自身逻辑极简。

func _ready() -> void:
	size = Vector2i(2, 1)
	super._ready()
