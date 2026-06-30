extends Resource
# 植物配置表的一条记录（静态数据）：所有玩家共享，只读。
# 区别于 PlantData（玩家实例状态：star/level/exp），本类存放植物固有的基础属性。
# 后续可改成 .tres 文件，编辑器可视化配置；第 1 版由 PlantTable._ready 硬编码注册。


@export var id: String                        # 唯一标识，如 "plant001"。PlantData 用这个引用配置。
@export var display_name: String              # 显示名，如 "阿葵"。
@export var scene_path: String                # 场景路径，如 "res://units/plants/阿葵.tscn"。
@export var icon: Texture2D                   # 卡片图标。
@export var size: Vector2i = Vector2i(2, 2)   # 占地大小（格子数），卡片缩放和放置逻辑都读这个。
@export var base_hp: float = 100.0            # 基础血量（1星1级时），PlantData 按星级等级放大。
@export var base_damage: float = 20.0         # 基础攻击力（1星1级时）。
@export var attack_range: float = 0.0         # 攻击射程（格子数），0 = 不攻击（如阿葵）。运行时乘 tile_size 换算像素。
@export var base_attack_interval: float = 0.0 # 基础攻击间隔（秒），0 = 无周期攻击（如阿葵产灵气、阿坚纯肉盾）。运行时除以攻速倍率得实际间隔。
@export var cost: int = 50                    # 种植消耗（灵气）。
@export var provides_vision: bool = false     # 是否点亮迷雾。
# 突破所需碎片：数组下标 i = 从 (i+1) 星升到 (i+2) 星的消耗。
# 如 [10, 30, 80, 200] 表示 1→2 星需 10 碎片，2→3 需 30，3→4 需 80，4→5 需 200。
@export var breakthrough_costs: Array[int] = []
