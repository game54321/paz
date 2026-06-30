extends Resource
# 词条配置表的一条记录（静态数据）：所有玩家共享，只读。
# 区别于 EntryData（玩家实例状态：count/equipped_to），本类存放词条固有属性。
# 占格数 = display_name.length()，横向 1 行。
# 第 1 版由 EntryTable._ready 硬编码注册；后续可改成 .tres 文件，编辑器可视化配置。


@export var id: String                        # 唯一标识，如 "entry001"。EntryData 用这个引用配置。
@export var display_name: String              # 显示名，如 "大力"。字数决定占格。
@export var description: String               # 介绍文案。

# 修饰器列表：一条词条可同时改多个属性，PlantData 派生属性计算时遍历累加。
# 每个元素形如 {"stat": "damage", "value": 0.3, "mode": "pct"}。
# stat: "hp" / "damage" / "range" / "attack_speed"。
# mode: "add" = 加法（数值），"pct" = 百分比（1.0 = +100%）。
@export var modifiers: Array[Dictionary] = []
