extends BaseTile

func _ready():
	tile_type = "blank"
	base_color = Color(0.5, 0.5, 0.5)  # 灰色
	super._ready()
	# GLBモデル内のMeshInstance3Dに灰色を直接適用
	_apply_blank_color()

func _apply_blank_color():
	var model_node = get_node_or_null("natural2")
	if not model_node:
		return
	var mesh_instance = _find_mesh_instance_recursive(model_node)
	if mesh_instance:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = base_color
		mesh_instance.material_override = mat

# 無属性タイルは連鎖しない
func get_chain_count(_board_system) -> int:
	return 0

# 通行料計算（連鎖ボーナスなし）
func calculate_toll() -> int:
	if owner_id == -1:
		return 0

	var base_toll = 100
	var level_multiplier = level
	return int(base_toll * level_multiplier)
