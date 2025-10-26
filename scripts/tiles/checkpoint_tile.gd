extends BaseTile

# チェックポイントのタイプ
enum CheckpointType { N, S }

# エクスポート変数で各タイルのタイプを設定可能に
@export var checkpoint_type: CheckpointType = CheckpointType.N

# 通過時に発行するシグナル
signal checkpoint_passed(player_id: int, checkpoint_type: String)

func _ready():
	tile_type = "checkpoint"
	super._ready()

# チェックポイント通過を通知
func on_player_passed(player_id: int):
	var type_str = "N" if checkpoint_type == CheckpointType.N else "S"
	print("[CheckpointTile] プレイヤー", player_id + 1, "がチェックポイント(", type_str, ")を通過")
	emit_signal("checkpoint_passed", player_id, type_str)
