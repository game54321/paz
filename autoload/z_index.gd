extends Node
# Z 层级表（autoload 单例）：集中管理所有节点 z_index 的取值。
# 用具名常量代替散落各处的魔法数字，调整渲染层级时只改这里。


const FOG := 0                  # 迷雾覆盖层，画在最底。
const PLANT_AURA := 1           # 阿葵光晕，画在普通植物之上、放置高亮之下。
const PLANT := 8                # 普通植物。
const ZOMBIE := 9               # 僵尸。
const PLACEMENT_HIGHLIGHT := 10 # grid_map 放置高亮，画在地图和植物之上。
const PLANT_DRAGGING := 11      # 拖拽中的植物，画在放置高亮之上。
const BULLET := 13              # 子弹，画在最上层。
