extends BaseTile

# チェックポイントのタイプ（4方向対応）
enum CheckpointType { N, S, E, W }

# エクスポート変数で各タイルのタイプを設定可能に
@export var checkpoint_type: CheckpointType = CheckpointType.N

# 通過時に発行するシグナル
signal checkpoint_passed(player_id: int, checkpoint_type: String)

func _ready():
	tile_type = "checkpoint"
	super._ready()
	_colorize_sp_tile()

func _colorize_sp_tile() -> void:
	var sp_node := get_node_or_null("sp_tile4")
	if not sp_node:
		return
	# sp_tile1内のMeshInstance3Dを探す
	for child in sp_node.get_children():
		if child is MeshInstance3D:
			TileMeshColorizer.colorize_by_height(
				child,
				Color(1.0, 0.84, 0.0),  # 金色（盛り上がり部分）
				Color(0.05, 0.05, 0.05),   # 黒（平面部分）
				0.874
			)
			break

# チェックポイント通過を通知
func on_player_passed(player_id: int):
	var type_str = get_checkpoint_type_string()
	emit_signal("checkpoint_passed", player_id, type_str)

# enumを文字列に変換
func get_checkpoint_type_string() -> String:
	match checkpoint_type:
		CheckpointType.N:
			return "N"
		CheckpointType.S:
			return "S"
		CheckpointType.E:
			return "E"
		CheckpointType.W:
			return "W"
		_:
			return "N"
