extends BaseTile

func _ready():
	tile_type = "blank"
	base_color = Color(0.5, 0.5, 0.5)  # 灰色
	super._ready()

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
