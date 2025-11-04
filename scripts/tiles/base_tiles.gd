extends Node3D
class_name BaseTile

# CreatureManagerへの静的参照（全タイル共通）
static var creature_manager: CreatureManager = null

# エクスポート変数（Inspectorで設定可能）
@export var tile_type: String = ""  # "fire", "water", "wind", "earth", "neutral"
@export var owner_id: int = -1  # -1=未所有, 0=プレイヤー1, 1=プレイヤー2
@export var level: int = 1  # 土地レベル（1-5）
@export var tile_index: int = 0  # ボード上の位置番号
@export var warp_destination: int = -1  # ワープ先タイル番号（-1=ワープなし）

# 接続情報（追加）
var connections: Dictionary = {
	"next": -1,      # 通常の次タイル
	"left": -1,      # 左分岐
	"right": -1,     # 右分岐
	"warp": -1       # ワープ先
}

# 内部変数
# creature_data プロパティ（CreatureManager経由 - 完全依存）
var creature_data: Dictionary:
	get:
		if creature_manager:
			return creature_manager.get_data_ref(tile_index)
		else:
			push_error("[BaseTile] CreatureManager が初期化されていません！")
			return {}
	set(value):
		if creature_manager:
			creature_manager.set_data(tile_index, value)
		else:
			push_error("[BaseTile] CreatureManager が初期化されていません！")
var base_color: Color = Color.WHITE  # タイルの基本色
var is_occupied: bool = false  # プレイヤーが乗っているか
var down_state: bool = false  # ダウン状態（Phase 1-A追加）

# クリーチャーカード3D表示
var creature_card_3d: Node3D = null  # 3Dカード表示ノード
const CREATURE_CARD_3D_SCRIPT = preload("res://scripts/creatures/creature_card_3d_quad.gd")

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
	# 特殊マスには配置不可
	if tile_type in ["checkpoint", "warp", "neutral", "start", "card"]:
		return false
	
	return owner_id != -1 and creature_data.is_empty()

# クリーチャーを配置
func place_creature(data: Dictionary):
	print("[BaseTile] place_creature called with data: ", data.get("name", "NO_NAME"), " id=", data.get("id", -1))
	creature_data = data.duplicate()  # 元データを変更しないようにコピー
	
	# 効果システム用フィールドの初期化
	if not creature_data.has("base_up_hp"):
		creature_data["base_up_hp"] = 0
	if not creature_data.has("base_up_ap"):
		creature_data["base_up_ap"] = 0
	if not creature_data.has("permanent_effects"):
		creature_data["permanent_effects"] = []
	if not creature_data.has("temporary_effects"):
		creature_data["temporary_effects"] = []
	if not creature_data.has("map_lap_count"):
		creature_data["map_lap_count"] = 0
	
	# 土地ボーナスはバトル時に動的計算するため、ここでは保存しない
	
	# 3Dカード表示を作成
	_create_creature_card_3d()
	
	update_visual()

# 3Dクリーチャーカードを作成
func _create_creature_card_3d():
	# 既存のカードがあれば削除
	if creature_card_3d:
		print("[BaseTile] Removing existing 3D card")
		creature_card_3d.queue_free()
		creature_card_3d = null
	
	# データが空なら作成しない
	if creature_data.is_empty():
		print("[BaseTile] creature_data is empty, not creating 3D card")
		return
	
	print("[BaseTile] Creating 3D card for: ", creature_data.get("name", "NO_NAME"))
	
	# 新しい3Dカードを作成
	creature_card_3d = Node3D.new()
	creature_card_3d.set_script(CREATURE_CARD_3D_SCRIPT)
	add_child(creature_card_3d)
	
	# クリーチャーデータを設定
	if creature_card_3d.has_method("set_creature_data"):
		creature_card_3d.set_creature_data(creature_data)

# クリーチャーを削除
func remove_creature():
	print("[BaseTile] remove_creature called")
	creature_data = {}
	
	# 3Dカード表示を削除
	if creature_card_3d:
		creature_card_3d.queue_free()
		creature_card_3d = null
	
	update_visual()

# クリーチャーデータを更新（バトル中の変更を反映）
func update_creature_data(new_data: Dictionary):
	if new_data.is_empty():
		return
	
	# データを更新
	creature_data = new_data.duplicate()
	
	# 3Dカード表示を更新
	if creature_card_3d and creature_card_3d.has_method("update_creature_data"):
		creature_card_3d.update_creature_data(creature_data)

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
	# 特殊マスは色を変更しない（シーンで設定した色を保持）
	if tile_type in ["checkpoint", "warp", "neutral", "start", "card"]:
		return
	
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

# 土地ボーナスはバトル時に動的計算（このメソッドは削除）

# ============================================
# Phase 1-A: ダウン状態システム
# ============================================

## ダウン状態を設定
func set_down_state(should_be_down: bool):
	down_state = should_be_down
	update_visual()

## ダウン状態を解除
func clear_down_state():
	set_down_state(false)

## ダウン状態かチェック
func is_down() -> bool:
	return down_state

## 領地コマンド使用可能か
func can_use_land_command() -> bool:
	# 所有地でクリーチャーがいる場合のみ使用可能
	# ダウン状態でも使用可能（不屈スキル対応）
	return owner_id != -1 and not creature_data.is_empty()
