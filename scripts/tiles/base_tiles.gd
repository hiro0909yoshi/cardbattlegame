extends Node3D
class_name BaseTile

# エクスポート変数（Inspectorで設定可能）
@export var tile_type: String = ""  # "fire", "water", "wind", "earth", "neutral"
@export var owner_id: int = -1  # -1=未所有, 0=プレイヤー1, 1=プレイヤー2
@export var level: int = 1  # 土地レベル（1-5）
@export var tile_index: int = 0  # ボード上の位置番号

# 接続情報（追加）
var connections: Dictionary = {
	"next": -1,      # 通常の次タイル
	"left": -1,      # 左分岐
	"right": -1,     # 右分岐
	"warp": -1       # ワープ先
}

# 内部変数
var creature_data: Dictionary = {}  # 配置されているクリーチャー情報
var base_color: Color = Color.WHITE  # タイルの基本色
var is_occupied: bool = false  # プレイヤーが乗っているか

# シグナル
signal player_landed(player_body)  # プレイヤーが止まった
signal player_passed(player_body)  # プレイヤーが通過した

func _ready():
	# Area3Dの信号を接続（子ノードにArea3Dがあることを前提）
	if has_node("Area3D"):
		$Area3D.body_entered.connect(_on_area_entered)
		$Area3D.body_exited.connect(_on_area_exited)
	
	# 初期ビジュアル更新
	update_visual()

# プレイヤーがタイルに入った
func _on_area_entered(body):
	if body.is_in_group("players"):
		is_occupied = true
		emit_signal("player_landed", body)
		print(tile_type + "タイルに到着: プレイヤー" + str(body.get("player_id", 0) + 1))

# プレイヤーがタイルから出た
func _on_area_exited(body):
	if body.is_in_group("players"):
		is_occupied = false
		emit_signal("player_passed", body)

# タイル情報を取得
func get_tile_info() -> Dictionary:
	return {
		"index": tile_index,
		"type": tile_type,
		"owner": owner_id,
		"level": level,
		"creature": creature_data,
		"occupied": is_occupied
	}

# クリーチャー配置可能かチェック
func can_place_creature() -> bool:
	return owner_id != -1 and creature_data.is_empty()

# クリーチャーを配置
func place_creature(data: Dictionary):
	creature_data = data
	update_visual()

# クリーチャーを削除
func remove_creature():
	creature_data = {}
	update_visual()

# 所有者を設定
func set_tile_owner(new_owner_id: int):
	owner_id = new_owner_id
	update_visual()

# レベルを設定
func set_level(new_level: int):
	level = clamp(new_level, 1, 5)
	update_visual()

# レベルアップ
func level_up() -> bool:
	if level < 5:
		set_level(level + 1)
		return true
	return false

# ビジュアル更新
func update_visual():
	# MeshInstance3Dの色を更新
	if has_node("MeshInstance3D"):
		var mesh = $MeshInstance3D
		
		# マテリアルを取得または作成
		if not mesh.material_override:
			mesh.material_override = StandardMaterial3D.new()
		
		var mat = mesh.material_override as StandardMaterial3D
		
		# 所有者に応じた色設定
		if owner_id == -1:
			# 未所有
			mat.albedo_color = base_color
		elif owner_id == 0:
			# プレイヤー1（黄色系）
			mat.albedo_color = base_color.lerp(Color.YELLOW, 0.3)
		elif owner_id == 1:
			# プレイヤー2（青系）
			mat.albedo_color = base_color.lerp(Color.BLUE, 0.3)
		
		# レベルに応じた明度調整
		mat.albedo_color = mat.albedo_color.lerp(Color.WHITE, (level - 1) * 0.1)

# 属性連鎖数を取得（子クラスでオーバーライド可能）
func get_chain_count(_board_system) -> int:
	if tile_type == "neutral":
		return 0  # 無属性は連鎖しない
	
	# ボードシステムから同属性の所有地数を取得
	# 実際の実装は board_system 側で行う
	return 1

# 通行料計算（基本実装）
func calculate_toll() -> int:
	if owner_id == -1:
		return 0
	
	var base_toll = 100
	var level_multiplier = level
	var chain_bonus = 1.0  # 子クラスで連鎖ボーナス実装
	
	return int(base_toll * level_multiplier * chain_bonus)
