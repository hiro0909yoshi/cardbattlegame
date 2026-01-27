extends Node3D
class_name BaseTile

# 定数参照
const GameConstants = preload("res://scripts/game_constants.gd")

# 静的参照（全タイル共通）
static var creature_manager: CreatureManager = null
static var tile_info_display: TileInfoDisplay = null  # 通行料ラベル更新用

# エクスポート変数（Inspectorで設定可能）
@export var tile_type: String = ""  # "fire", "water", "wind", "earth", "neutral"
@export var _owner_id: int = -1  # 内部変数（直接アクセスしないこと）
@export var _level: int = 1  # 内部変数（直接アクセスしないこと）
@export var tile_index: int = 0  # ボード上の位置番号

# 接続情報（分岐/行き止まりタイルのみ設定）
# 形式: Array[int] - 接続先タイル番号のリスト
# 空の場合は従来計算（tile + direction）を使用
@export var connections: Array[int] = []

# 内部変数
# creature_data プロパティ（CreatureManager経由 - 完全依存）
# setterで3Dカード表示も自動同期
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
		# 3Dカードの同期
		_sync_creature_card_3d(value)

# owner_id プロパティ（setterで通行料ラベル・枠発光も自動同期）
var owner_id: int:
	get:
		return _owner_id
	set(value):
		_owner_id = value
		_sync_tile_info_display()
		_update_frame_glow()

# level プロパティ（setterで通行料ラベルも自動同期）
var level: int:
	get:
		return _level
	set(value):
		_level = clamp(value, 1, 5)
		_sync_tile_info_display()

var base_color: Color = Color.WHITE  # タイルの基本色
var is_occupied: bool = false  # プレイヤーが乗っているか
var down_state: bool = false  # ダウン状態（Phase 1-A追加）
var frame_material: StandardMaterial3D = null  # プレイヤー色マテリアル
var frame_original_material: Material = null  # 元のマテリアル保存用
var frame_mesh_instance: MeshInstance3D = null  # 枠のMeshInstance3D参照
var _blink_active: bool = false  # 点滅中フラグ
var _blink_time: float = 0.0  # 点滅用タイマー

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
	
	# 点滅処理は初期状態でオフ
	set_process(false)
	
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
	# 配置可能タイルでなければ不可（特殊タイルは配置不可）
	if not TileHelper.is_placeable_type(tile_type):
		return false
	
	# クリーチャーがいなければ配置可能
	return creature_data.is_empty()

# クリーチャーを配置
func place_creature(data: Dictionary):
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
	
	# current_hp の初期化（新方式：状態値）
	if not creature_data.has("current_hp"):
		var max_hp = creature_data.get("hp", 0) + creature_data.get("base_up_hp", 0)
		creature_data["current_hp"] = max_hp
	
	# 土地ボーナスはバトル時に動的計算するため、ここでは保存しない
	# 3Dカード表示はsetterで自動作成されるため、ここでは呼ばない
	
	update_visual()

# クリーチャー表示の同期（setterから呼ばれる）
# 3Dカードと通行料ラベルを両方更新
func _sync_creature_card_3d(data: Dictionary):
	# 3Dカードの同期
	if data.is_empty():
		# データが空 → 3Dカード削除
		if creature_card_3d:
			creature_card_3d.queue_free()
			creature_card_3d = null
	else:
		# データあり
		if creature_card_3d:
			# 既存のカードがある → 更新のみ（再作成しない）
			if creature_card_3d.has_method("set_creature_data"):
				creature_card_3d.set_creature_data(data)
		else:
			# カードがない → 新規作成
			_create_creature_card_3d()
	
	# 通行料ラベルの同期
	_sync_tile_info_display()

# 3Dクリーチャーカードを作成
func _create_creature_card_3d():
	# 既存のカードがあれば削除
	if creature_card_3d:
		creature_card_3d.queue_free()
		creature_card_3d = null
	
	# データが空なら作成しない
	if creature_data.is_empty():
		return
	
	
	# 新しい3Dカードを作成
	creature_card_3d = Node3D.new()
	creature_card_3d.set_script(CREATURE_CARD_3D_SCRIPT)
	add_child(creature_card_3d)
	
	# クリーチャーデータを設定
	if creature_card_3d.has_method("set_creature_data"):
		creature_card_3d.set_creature_data(creature_data)

# 通行料ラベルの同期
func _sync_tile_info_display():
	if tile_info_display and tile_info_display.has_method("update_display"):
		var tile_info = _get_tile_info_for_display()
		tile_info_display.update_display(tile_index, tile_info)

# 通行料ラベル用のタイル情報を生成
func _get_tile_info_for_display() -> Dictionary:
	return {
		"owner": owner_id,
		"level": level,
		"type": tile_type,
		"has_creature": not creature_data.is_empty(),
		"creature": creature_data,
		"is_special": not TileHelper.is_placeable_type(tile_type)
	}

# クリーチャーを削除
func remove_creature():
	creature_data = {}  # setterで3Dカードも自動削除される
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
	# 属性タイルの場合のみタイル本体の色を変更
	if TileHelper.is_element_type(tile_type):
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
	
	# 枠発光は全タイルで更新（属性タイル以外も含む）
	_update_frame_glow()

# 枠発光更新（所有者に応じて発光、ダウン状態で点灯/アクティブで点滅）
func _update_frame_glow():
	# frameノードを検索
	var frame_node = get_node_or_null("frame")
	if not frame_node:
		return
	
	# frameの子からMeshInstance3Dを取得（初回のみ）
	if not frame_mesh_instance:
		for child in frame_node.get_children():
			if child is MeshInstance3D:
				frame_mesh_instance = child
				# 元のマテリアルを保存
				if frame_mesh_instance.mesh and frame_mesh_instance.mesh.get_surface_count() > 0:
					frame_original_material = frame_mesh_instance.mesh.surface_get_material(0)
				break
	
	if not frame_mesh_instance:
		return
	
	# プレイヤー色マテリアルを作成（初回のみ）
	if not frame_material:
		frame_material = StandardMaterial3D.new()
	
	if owner_id == -1:
		# 未所有: 元のマテリアルに戻す、点滅停止
		_stop_frame_blink()
		frame_mesh_instance.material_override = null
	else:
		# 所有者あり
		var player_color = GameConstants.PLAYER_COLORS[owner_id % GameConstants.PLAYER_COLORS.size()]
		frame_material.emission_enabled = true
		
		if down_state:
			# ダウン状態: プレイヤー色で常時点灯、点滅停止
			_stop_frame_blink()
			frame_material.albedo_color = player_color
			frame_material.emission = player_color.darkened(0.3)
			frame_material.emission_energy_multiplier = 1.0
			frame_mesh_instance.material_override = frame_material
		else:
			# アクティブ状態: 点滅開始
			if not _blink_active:
				_start_frame_blink()

# 枠点滅開始
func _start_frame_blink():
	_blink_active = true
	_blink_time = 0.0
	set_process(true)

# 枠点滅停止
func _stop_frame_blink():
	_blink_active = false
	_blink_time = 0.0
	set_process(false)

# 点滅処理（_processで実行）
func _process(delta):
	if not _blink_active or not frame_mesh_instance:
		return
	_blink_time += delta
	
	# sin波で0〜1を滑らかに変化（周期2.5秒）
	var t = (sin(_blink_time * TAU / 2.5) + 1.0) / 2.0  # 0〜1
	
	# 常にmaterial_overrideを使用
	frame_mesh_instance.material_override = frame_material
	
	# プレイヤー色と元の色（グレー）を補間
	var player_color = GameConstants.PLAYER_COLORS[owner_id % GameConstants.PLAYER_COLORS.size()]
	var original_color = Color(0.15, 0.15, 0.15)  # 元の枠の色（暗めグレー）
	
	frame_material.albedo_color = original_color.lerp(player_color, t)
	frame_material.emission = original_color.lerp(player_color.darkened(0.3), t)  # 発光色を少し暗めに
	frame_material.emission_energy_multiplier = 0.3 + t * 0.7  # 0.3〜1.0（控えめに）

# frameノード以下の全MeshInstance3Dを再帰的に収集
func _collect_mesh_instances(node: Node, result: Array[MeshInstance3D]):
	for child in node.get_children():
		if child is MeshInstance3D:
			result.append(child)
		_collect_mesh_instances(child, result)





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

## ドミニオコマンド使用可能か
func can_use_dominio_order() -> bool:
	# 所有地でクリーチャーがいる場合のみ使用可能
	# ダウン状態でも使用可能（不屈スキル対応）
	return owner_id != -1 and not creature_data.is_empty()
