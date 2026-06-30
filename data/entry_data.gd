extends Resource
# 词条玩家实例数据：只存持有状态（entry_id + count + equipped_to）。
# 静态配置（显示名/介绍）在 EntryTable 的 EntryDef 里，按 entry_id 查询。
# 第 1 版不做交互，count/equipped_to 留 API 备用。


@export var entry_id: String                  # 指向 EntryTable 中的 EntryDef。
@export var count: int = 1                    # 持有数量。
@export var level: int = 1                    # 词条等级，3 个相同词条合成进阶 +1。
@export var equipped_to: String = ""          # 绑定的植物 def_id，"" 表示在仓库。

func get_def() -> Resource:
	# 从 EntryTable 查对应 EntryDef。
	return EntryTable.get_def(entry_id)
