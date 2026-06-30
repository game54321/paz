extends Node2D
# 网格视觉层：只画两样东西——迷雾（shader 覆盖层）和放置高亮（_draw）。
# 所有业务逻辑（哪些格子亮、哪些格子可放、植物在哪）都由 PlacementManager 单例持有，
# 本节点通过 fog_dirty / highlight_dirty 信号监听变化，从 manager 读数据后重绘。
# 不再持有 cell_target / active_cells / 植物列表等业务状态。


var tile_map: TileMapLayer                              # 当前关卡的 TileMapLayer，用于坐标换算。

# 放置高亮颜色。
const ACTIVE_OK := Color(0.3, 1.0, 0.4, 0.45)           # 合法时高亮填充：半透明绿。
const ACTIVE_BAD := Color(1.0, 0.3, 0.3, 0.45)          # 非法时高亮填充：半透明红。
const BORDER_OK := Color(0.3, 1.0, 0.4, 1.0)            # 合法时高亮边框：不透明绿。
const BORDER_BAD := Color(1.0, 0.3, 0.3, 1.0)           # 非法时高亮边框：不透明红。

# 迷雾视觉常量（逻辑常量 FOG_REVEAL_SIZE / INITIAL_LIT_COLS 等在 PlacementManager）。
const FOG_EDGE_SOFTNESS := 2.0                          # shader 中迷雾边缘柔化像素宽度。
const FOG_SHADER := """
shader_type canvas_item;

uniform int blob_count = 0;
uniform vec2 rect_size = vec2(1.0, 1.0);
uniform float initial_lit_width = 0.0;
uniform float initial_lit_height = 0.0;
uniform float noise_amp = 0.0;
uniform float edge_softness = 8.0;
uniform sampler2D blob_texture : filter_nearest;

float edge_noise(float v, float seed) {
	return (
		sin(v * 0.53 + seed)
		+ sin(v * 1.17 + seed * 1.71) * 0.5
		+ sin(v * 2.31 + seed * 0.37) * 0.25
	) / 1.75;
}

float blob_distance(vec2 p, vec4 blob) {
	vec2 d = p - blob.xy;
	float half_size = blob.z * 0.5;
	float nx = edge_noise(p.y, blob.w) * noise_amp;
	float ny = edge_noise(p.x, blob.w + 8.13) * noise_amp;
	vec2 q = abs(d) - vec2(half_size + nx, half_size + ny);
	return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0)));
}

void add_blob(vec2 p, vec4 blob, inout float dist) {
	dist = min(dist, blob_distance(p, blob));
}

void fragment() {
	vec2 p = UV * rect_size;
	// 左上角 5x5 默认亮区：x 在左 initial_lit_width 列【且】 y 在上 initial_lit_height 行。
	// SDF 交集用 max（两个半平面都要满足），各自带边缘噪声。
	float edge_x = initial_lit_width + edge_noise(p.y, __INITIAL_EDGE_SEED__) * noise_amp;
	float edge_y = initial_lit_height + edge_noise(p.x, __INITIAL_EDGE_SEED__ + 3.7) * noise_amp;
	float dist = max(p.x - edge_x, p.y - edge_y);
	for (int i = 0; i < blob_count; i++) {
		vec4 blob = texture(blob_texture, vec2((float(i) + 0.5) / float(blob_count), 0.5));
		add_blob(p, blob, dist);
	}
	float alpha = smoothstep(0.0, edge_softness, dist);
	COLOR = vec4(0.0, 0.0, 0.0, alpha);
}
"""

# 迷雾覆盖层资源（shader + 1D 纹理传视野数据）。
var fog_blob_image: Image
var fog_blob_texture: ImageTexture
var fog_overlay: ColorRect
var fog_material: ShaderMaterial


func bind_tile_map(p_tile_map: TileMapLayer) -> void:   # main.gd 加载关卡后调用。
	tile_map = p_tile_map
	_ensure_fog_overlay()                                # 创建 ColorRect + shader 材质。
	# 连接 PlacementManager 信号，业务状态变化时本节点重绘。
	# 用 CallDeferred 一类的延迟不必，autoload 比场景节点先初始化。
	if not PlacementManager.fog_dirty.is_connected(_on_fog_dirty):
		PlacementManager.fog_dirty.connect(_on_fog_dirty)
	if not PlacementManager.highlight_dirty.is_connected(_on_highlight_dirty):
		PlacementManager.highlight_dirty.connect(_on_highlight_dirty)
	_update_fog_overlay(tile_map.get_used_rect())       # 首次绘制迷雾。
	queue_redraw()

func _ready() -> void:
	add_to_group("grid_map")                            # 保留 group，main.gd 用 $GridOverlay 直接拿，group 备用。
	z_index = ZIndex.PLACEMENT_HIGHLIGHT             # 放置高亮显示在地图和迷雾之上。

func has_tile_map() -> bool:                            # 给外部判断是否已 bind 地图。
	return is_instance_valid(tile_map)

func _on_fog_dirty() -> void:                           # 植物增删/拖拽状态变化，迷雾要重算。
	if not tile_map:
		return
	_update_fog_overlay(tile_map.get_used_rect())
	queue_redraw()

func _on_highlight_dirty() -> void:                    # 鼠标移动/size 变，放置预览要重绘。
	queue_redraw()


func _draw() -> void:                                   # 自定义绘制：只画放置高亮，迷雾由 fog_overlay 的 shader 画。
	if not tile_map:
		return
	var half := Vector2(tile_map.tile_set.tile_size) * 0.5
	var active := PlacementManager.get_active_cells()   # 从 manager 读预览格子。
	var valid := PlacementManager.is_active_valid()     # 从 manager 读合法性。
	var fill := ACTIVE_OK if valid else ACTIVE_BAD
	var border := BORDER_OK if valid else BORDER_BAD
	for c in active:
		var p := to_local(tile_map.to_global(tile_map.map_to_local(c)))
		var r := Rect2(p - half, half * 2.0)
		draw_rect(r, fill, true)
		draw_rect(r, border, false, 2.0)


func _ensure_fog_overlay() -> void:                     # 懒创建迷雾 ColorRect + shader 材质。
	if is_instance_valid(fog_overlay):
		return
	fog_material = ShaderMaterial.new()
	var shader := Shader.new()
	# INITIAL_EDGE_SEED 是逻辑常量，从 PlacementManager 取，避免重复定义。
	shader.code = FOG_SHADER.replace("__INITIAL_EDGE_SEED__", str(PlacementManager.INITIAL_EDGE_SEED))
	fog_material.shader = shader
	fog_overlay = ColorRect.new()
	fog_overlay.name = "FogOverlay"
	fog_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 不挡鼠标。
	fog_overlay.color = Color.WHITE                        # 颜色由 shader 决定，这里填白无意义。
	fog_overlay.material = fog_material
	fog_overlay.z_index = ZIndex.FOG                  # 迷雾在最底下，放置高亮画在它之上。
	add_child(fog_overlay)

func _update_fog_overlay(used: Rect2i) -> void:         # 根据地图范围和视野数据刷新迷雾覆盖层。
	_ensure_fog_overlay()
	if not tile_map:
		return
	var tile_size := Vector2(tile_map.tile_set.tile_size)
	var top_left := to_local(tile_map.to_global(tile_map.map_to_local(used.position) - tile_size * 0.5))
	var bottom_right_cell := used.end - Vector2i.ONE
	var bottom_right := to_local(tile_map.to_global(tile_map.map_to_local(bottom_right_cell) + tile_size * 0.5))
	var rect_size := bottom_right - top_left
	fog_overlay.position = top_left
	fog_overlay.size = rect_size
	fog_material.set_shader_parameter("rect_size", rect_size)
	fog_material.set_shader_parameter("initial_lit_width", float(PlacementManager.INITIAL_LIT_COLS) * tile_size.x)
	fog_material.set_shader_parameter("initial_lit_height", float(PlacementManager.INITIAL_LIT_ROWS) * tile_size.y)
	fog_material.set_shader_parameter("noise_amp", PlacementManager.NOISE_AMP * minf(tile_size.x, tile_size.y))
	fog_material.set_shader_parameter("edge_softness", FOG_EDGE_SOFTNESS)
	var blobs: Array[Vector4] = PlacementManager.get_fog_blobs()    # 从 manager 读视野数据。
	fog_material.set_shader_parameter("blob_count", blobs.size())
	_update_blob_texture(used, tile_size, blobs)

func _update_blob_texture(used: Rect2i, tile_size: Vector2, blobs: Array[Vector4]) -> void: # 把视野数据写进 1D 纹理喂 shader。
	var count :int= max(1, blobs.size())
	if fog_blob_image == null or fog_blob_image.get_width() != count:
		fog_blob_image = Image.create_empty(count, 1, false, Image.FORMAT_RGBAF)
		fog_blob_texture = ImageTexture.create_from_image(fog_blob_image)
	for i in range(count):
		var value := Color.TRANSPARENT
		if i < blobs.size():
			var blob: Vector4 = blobs[i]
			var cell_center := Vector2(blob.x, blob.y)
			var local_pos := Vector2(
				(cell_center.x - float(used.position.x)) * tile_size.x,
				(cell_center.y - float(used.position.y)) * tile_size.y
			)
			value = Color(
				local_pos.x,
				local_pos.y,
				blob.z * minf(tile_size.x, tile_size.y),
				blob.w
			)
		fog_blob_image.set_pixel(i, 0, value)
	fog_blob_texture.update(fog_blob_image)
	fog_material.set_shader_parameter("blob_texture", fog_blob_texture)
