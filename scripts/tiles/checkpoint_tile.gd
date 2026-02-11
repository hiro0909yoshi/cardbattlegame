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
