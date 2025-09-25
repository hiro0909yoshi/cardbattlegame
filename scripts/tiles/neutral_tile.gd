extends BaseTile

func _ready():
	tile_type = "neutral"
	base_color = Color(0.7, 0.7, 0.7)  # グレー系
	super._ready()

# 無属性タイルは連鎖しない
func get_chain_count(board_system) -> int:
	return 0  # 常に0を返す

# 通行料計算（連鎖ボーナスなし）
func calculate_toll() -> int:
	if owner_id == -1:
		return 0
	
	var base_toll = 100
	var level_multiplier = level
	# 無属性は連鎖ボーナスなし
	return int(base_toll * level_multiplier)
