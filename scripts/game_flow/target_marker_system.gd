# TargetMarkerSystem - マーカー・カメラ・ハイライト管理
#
# ターゲット選択時の視覚的フィードバックを担当
# - 選択マーカーの作成・表示・回転・ボビング
# - カメラフォーカス
# - タイルハイライト
#
# 使用例:
#   TargetMarkerSystem.show_selection_marker(handler, tile_index)
#   TargetMarkerSystem.focus_camera_on_tile(handler, tile_index)
extends RefCounted
class_name TargetMarkerSystem

# マーカーアニメーション定数
const MARKER_BOB_SPEED: float = 2.5        # ボビング速度
const MARKER_BOB_AMPLITUDE: float = 0.6    # ボビング振幅
const MARKER_BOB_BASE_Y: float = 1.2       # ボビング基準Y位置
const MARKER_ROTATE_SPEED: float = 4.5     # Y軸周回速度(rad/s)
const MARKER_ORBIT_RADIUS: float = 1.8     # 周回半径（タイルを包むサイズ）
const MARKER_ORB_COUNT: int = 2            # 光の玉の数
const MARKER_ORB_RADIUS: float = 0.12      # 光の玉の半径
const MARKER_ORB_HEIGHT: float = 0.24      # 光の玉の高さ

# ゴーストトレイル定数（各光の玉の後ろに配置する残像）
const TRAIL_GHOST_COUNT: int = 30           # 1つの玉あたりのゴースト数
const TRAIL_ANGLE_STEP: float = 0.04       # ゴースト間の角度間隔(rad ≈ 7度)

# ============================================
# 選択マーカー管理
# ============================================

## ハンドラーの実際の所有者を取得（SpellPhaseHandlerの場合はspell_target_selection_handlerを返す）
static func _get_actual_handler(handler):
	if handler and "spell_target_selection_handler" in handler and handler.spell_target_selection_handler:
		return handler.spell_target_selection_handler
	return handler

## 選択マーカーを作成
##
## handler: 選択マーカーを保持するオブジェクト（DominioCommandHandler、SpellPhaseHandlerなど）
##          handler.selection_marker プロパティが必要
static func create_selection_marker(handler):
	var actual_handler = _get_actual_handler(handler)
	if not actual_handler:
		return

	if actual_handler.selection_marker:
		return  # 既に存在する場合は何もしない

	actual_handler.selection_marker = create_marker_mesh()


## 選択マーカーを表示
##
## handler: 選択マーカーを保持するオブジェクト
##          handler.selection_marker と handler.board_system が必要
## tile_index: マーカーを表示する土地のインデックス
static func show_selection_marker(handler, tile_index: int):
	var actual_handler = _get_actual_handler(handler)
	if not actual_handler:
		return

	# board_system は handler から取得（actual_handler ではなく）
	var board_sys = handler.board_system if "board_system" in handler else null
	if not board_sys or not board_sys.tile_nodes.has(tile_index):
		return

	var tile = board_sys.tile_nodes[tile_index]

	# マーカーが未作成なら作成
	if not actual_handler.selection_marker:
		create_selection_marker(handler)

	# マーカーを土地の子として追加
	if actual_handler.selection_marker.get_parent():
		actual_handler.selection_marker.get_parent().remove_child(actual_handler.selection_marker)

	tile.add_child(actual_handler.selection_marker)

	# 位置・傾きを初期化
	_init_marker_transform(actual_handler.selection_marker)


## 選択マーカーを非表示
##
## handler: 選択マーカーを保持するオブジェクト
static func hide_selection_marker(handler):
	var actual_handler = _get_actual_handler(handler)
	if not actual_handler:
		return

	if actual_handler.selection_marker and actual_handler.selection_marker.get_parent():
		actual_handler.selection_marker.get_parent().remove_child(actual_handler.selection_marker)


## 選択マーカーをアニメーション（_process内で呼ぶ）
## ボビング（上下浮き沈み）+ 傾き回転
##
## handler: 選択マーカーを保持するオブジェクト
## delta: フレーム間の経過時間
static func rotate_selection_marker(handler, delta: float):
	var actual_handler = _get_actual_handler(handler)
	if not actual_handler:
		return

	if actual_handler.selection_marker and actual_handler.selection_marker.has_meta("rotating"):
		_animate_marker(actual_handler.selection_marker, delta)


## 複数マーカーを表示（確認フェーズ用）
##
## handler: confirmation_markers配列とboard_systemを持つオブジェクト
## tile_indices: マーカーを表示するタイルインデックスの配列
static func show_multiple_markers(handler, tile_indices: Array):
	var actual_handler = _get_actual_handler(handler)
	if not actual_handler:
		return

	# 既存のマーカーをクリア
	clear_confirmation_markers(handler)

	# board_system は handler から取得（actual_handler ではなく）
	var board_sys = handler.board_system if "board_system" in handler else null
	if not board_sys:
		return

	for tile_index in tile_indices:
		if not board_sys.tile_nodes.has(tile_index):
			continue

		var tile = board_sys.tile_nodes[tile_index]

		# マーカーを作成
		var marker = create_marker_mesh()
		tile.add_child(marker)
		_init_marker_transform(marker)

		actual_handler.confirmation_markers.append(marker)


## 確認フェーズ用マーカーをすべてクリア
##
## handler: confirmation_markers配列を持つオブジェクト
static func clear_confirmation_markers(handler):
	var actual_handler = _get_actual_handler(handler)
	if not actual_handler:
		return

	if not "confirmation_markers" in actual_handler:
		return

	for marker in actual_handler.confirmation_markers:
		if marker and is_instance_valid(marker):
			if marker.get_parent():
				marker.get_parent().remove_child(marker)
			marker.queue_free()

	actual_handler.confirmation_markers.clear()


## 確認フェーズ用マーカーを回転（_process内で呼ぶ）
##
## handler: confirmation_markers配列を持つオブジェクト
## delta: フレーム間の経過時間
static func rotate_confirmation_markers(handler, delta: float):
	var actual_handler = _get_actual_handler(handler)
	if not actual_handler:
		return

	if not "confirmation_markers" in actual_handler:
		return

	for marker in actual_handler.confirmation_markers:
		if marker and is_instance_valid(marker) and marker.has_meta("rotating"):
			_animate_marker(marker, delta)


## マーカーを作成（内部用）
## 光の玉が円状に周回するマーカー + ゴーストトレイル
## コンテナをY軸回転すると、玉もゴーストも一緒に回り、尾を引いて見える
static func create_marker_mesh() -> Node3D:
	var container = Node3D.new()

	# メインの球メッシュ（共有）
	var sphere = SphereMesh.new()
	sphere.radius = MARKER_ORB_RADIUS
	sphere.height = MARKER_ORB_HEIGHT

	# 光の玉を等間隔に配置
	for i in range(MARKER_ORB_COUNT):
		var base_angle: float = TAU * i / MARKER_ORB_COUNT

		# メインの光の玉
		var orb = MeshInstance3D.new()
		orb.mesh = sphere
		orb.material_override = _create_orb_material(1.0)
		orb.position = Vector3(
			cos(base_angle) * MARKER_ORBIT_RADIUS,
			0,
			sin(base_angle) * MARKER_ORBIT_RADIUS
		)
		container.add_child(orb)

		# ゴーストトレイル（回転方向の後ろに配置）
		for g in range(TRAIL_GHOST_COUNT):
			var ghost_angle: float = base_angle + TRAIL_ANGLE_STEP * (g + 1)
			var t: float = float(g + 1) / TRAIL_GHOST_COUNT  # 0→1（遠いほど1）
			var alpha: float = lerpf(0.5, 0.0, t)
			var scale_factor: float = lerpf(0.85, 0.15, t)

			var ghost = MeshInstance3D.new()
			ghost.mesh = sphere
			ghost.material_override = _create_orb_material(alpha, t)
			ghost.scale = Vector3.ONE * scale_factor
			ghost.position = Vector3(
				cos(ghost_angle) * MARKER_ORBIT_RADIUS,
				0,
				sin(ghost_angle) * MARKER_ORBIT_RADIUS
			)
			container.add_child(ghost)

	return container


## 光の玉用マテリアルを作成
## alpha: 透明度（1.0=不透明、0.0=透明）
## fade: 色フェード（0.0=黄色、1.0=白）
static func _create_orb_material(alpha: float, fade: float = 0.0) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	var albedo = Color(1.0, 1.0, 0.3, alpha).lerp(Color(1.0, 1.0, 1.0, alpha), fade)
	mat.albedo_color = albedo
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.9, 0.2).lerp(Color(1.0, 1.0, 1.0), fade)
	mat.emission_energy_multiplier = lerpf(1.0, 4.0, alpha)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


## マーカーの初期トランスフォームを設定
static func _init_marker_transform(marker: Node3D) -> void:
	marker.position = Vector3(0, MARKER_BOB_BASE_Y, 0)
	marker.rotation = Vector3.ZERO
	marker.set_meta("rotating", true)
	marker.set_meta("anim_time", 0.0)


## マーカーの毎フレームアニメーション
## コンテナをY軸回転（光の玉が周回）+ ボビング（上下浮き沈み）
static func _animate_marker(marker: Node3D, delta: float) -> void:
	# 経過時間を更新
	var t: float = marker.get_meta("anim_time", 0.0) + delta
	marker.set_meta("anim_time", t)

	# ボビング（上下浮き沈み）
	marker.position.y = MARKER_BOB_BASE_Y + sin(t * MARKER_BOB_SPEED) * MARKER_BOB_AMPLITUDE

	# コンテナをY軸回転（子の光の玉が円状に周回する）
	marker.rotation.y += delta * MARKER_ROTATE_SPEED


# ============================================
# カメラ制御
# ============================================

## カメラを土地にフォーカス
## 
## handler: board_system を持つオブジェクト
## tile_index: フォーカスする土地のインデックス
static func focus_camera_on_tile(handler, tile_index: int):
	if not handler.board_system or not handler.board_system.tile_nodes.has(tile_index):
		return
	
	var tile = handler.board_system.tile_nodes[tile_index]
	var camera = handler.board_system.camera
	
	if not camera:
		return
	
	# カメラを土地の上方に移動（通常ゲームと同じアングル）
	var tile_pos = tile.global_position
	var look_target = tile_pos + Vector3(0, 1.0, 0)
	camera.position = look_target + GameConstants.CAMERA_OFFSET

	# カメラを土地に向ける
	camera.look_at(look_target + Vector3(0, GameConstants.CAMERA_LOOK_OFFSET_Y, 0), Vector3.UP)


## カメラをプレイヤーにフォーカス
## 
## handler: board_system を持つオブジェクト
## player_id: フォーカスするプレイヤーのID
static func focus_camera_on_player(handler, player_id: int):
	if not handler.board_system:
		return
	
	# プレイヤーの位置（タイル）を取得
	var player_tile = handler.board_system.get_player_tile(player_id)
	
	if player_tile >= 0:
		# プレイヤーがいる土地にカメラをフォーカス
		focus_camera_on_tile(handler, player_tile)


# ============================================
# ハイライト制御
# ============================================

## 土地をハイライト
## 
## handler: board_system を持つオブジェクト
## tile_index: ハイライトする土地のインデックス
static func highlight_tile(handler, tile_index: int):
	if not handler.board_system or not handler.board_system.tile_nodes.has(tile_index):
		return
	
	var tile = handler.board_system.tile_nodes[tile_index]
	if tile.has_method("set_highlight"):
		tile.set_highlight(true)


## すべてのハイライトをクリア
## 
## handler: board_system を持つオブジェクト
static func clear_all_highlights(handler):
	if not handler.board_system:
		return
	
	for tile_idx in handler.board_system.tile_nodes.keys():
		var tile = handler.board_system.tile_nodes[tile_idx]
		if tile.has_method("set_highlight"):
			tile.set_highlight(false)


## 複数タイルをハイライト
## 
## handler: board_system を持つオブジェクト
## tile_indices: ハイライトするタイルインデックスの配列
static func highlight_multiple_tiles(handler, tile_indices: Array):
	if not handler.board_system:
		return
	
	for tile_index in tile_indices:
		if handler.board_system.tile_nodes.has(tile_index):
			var tile = handler.board_system.tile_nodes[tile_index]
			if tile.has_method("set_highlight"):
				tile.set_highlight(true)
