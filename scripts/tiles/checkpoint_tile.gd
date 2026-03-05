extends BaseTile

# チェックポイントのタイプ（1〜4）
enum CheckpointType { CP1, CP2, CP3, CP4 }

# エクスポート変数で各タイルのタイプを設定可能に
@export var checkpoint_type: CheckpointType = CheckpointType.CP1

# 通過時に発行するシグナル
signal checkpoint_passed(player_id: int, checkpoint_type: String)

# SPタイルモデルのパステンプレート
const SP_TILE_PATH_TEMPLATE = "res://models/sp_tile%d.glb"

func _ready():
	tile_type = "checkpoint"
	super._ready()
	_load_sp_tile_model()

## checkpoint_typeに応じたSPタイルモデルを動的にロード
func _load_sp_tile_model() -> void:
	var tile_number = checkpoint_type + 1  # enum値0〜3 → 1〜4
	var path = SP_TILE_PATH_TEMPLATE % tile_number
	var scene = load(path)
	if not scene:
		push_warning("SPタイルモデルが見つかりません: %s" % path)
		return
	var sp_node = scene.instantiate()
	sp_node.name = "sp_tile%d" % tile_number
	sp_node.transform = Transform3D(Basis(), Vector3(0, 0.0507739, 0))
	add_child(sp_node)
	_colorize_sp_tile(sp_node)

func _colorize_sp_tile(sp_node: Node) -> void:
	if not sp_node:
		return
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
	return str(checkpoint_type + 1)  # enum値0〜3 → "1"〜"4"
