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
static func show_selection_marker(handler, tile_index: int, target_type: String = "", target_player_id: int = -1):
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

	# ターゲットタイプとプレイヤーIDを記憶（カメラドラッグ復帰時に使用）
	actual_handler.selection_marker.set_meta("target_type", target_type)
	actual_handler.selection_marker.set_meta("target_player_id", target_player_id)

	# 選択タイル以外のカード・クリーチャーを半透明化（差分更新）
	_fade_with_diff(handler, tile_index, target_type, target_player_id)


## 選択マーカーを非表示
##
## handler: 選択マーカーを保持するオブジェクト
static func hide_selection_marker(handler):
	var actual_handler = _get_actual_handler(handler)
	if not actual_handler:
		return

	if actual_handler.selection_marker and actual_handler.selection_marker.get_parent():
		actual_handler.selection_marker.get_parent().remove_child(actual_handler.selection_marker)

	# 全カード・クリーチャーの透明度を復元
	restore_all_creature_transparency(handler)
	_clear_fade_cache()


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

		# カメラドラッグ中は半透明解除、戻ったら再適用
		_update_fade_for_camera(handler, actual_handler.selection_marker)


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
## marker_color: マーカーの色（"yellow"=選択用、"red"=効果適用用）
static func create_marker_mesh(marker_color: String = "yellow") -> Node3D:
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
		orb.material_override = _create_orb_material(1.0, 0.0, marker_color)
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
			ghost.material_override = _create_orb_material(alpha, t, marker_color)
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
## fade: 色フェード（0.0=基本色、1.0=白）
## marker_color: "yellow"（選択用）または "red"（効果適用用）
static func _create_orb_material(alpha: float, fade: float = 0.0, marker_color: String = "yellow") -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	var base_albedo: Color
	var base_emission: Color
	if marker_color == "red":
		base_albedo = Color(1.0, 0.2, 0.1, alpha)
		base_emission = Color(1.0, 0.15, 0.05)
	else:
		base_albedo = Color(1.0, 1.0, 0.3, alpha)
		base_emission = Color(1.0, 0.9, 0.2)
	var albedo = base_albedo.lerp(Color(1.0, 1.0, 1.0, alpha), fade)
	mat.albedo_color = albedo
	mat.emission_enabled = true
	mat.emission = base_emission.lerp(Color(1.0, 1.0, 1.0), fade)
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


## 赤マーカーのTweenアニメーション開始（Y軸回転 + ボビング）
static func _start_marker_tween(marker: Node3D, parent: Node) -> void:
	# 既存Tweenがあればkill（連続呼び出し対策）
	_kill_marker_tweens(marker)

	# Y軸回転（0.8秒で1回転）
	var rotate_tween: Tween = parent.create_tween()
	rotate_tween.tween_property(marker, "rotation:y", TAU, 0.8)
	marker.set_meta("_rotate_tween", rotate_tween)

	# ボビング（上下）
	var bob_tween: Tween = parent.create_tween()
	var bob_top: float = MARKER_BOB_BASE_Y + MARKER_BOB_AMPLITUDE
	var bob_bottom: float = MARKER_BOB_BASE_Y - MARKER_BOB_AMPLITUDE
	bob_tween.tween_property(marker, "position:y", bob_top, 0.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	bob_tween.tween_property(marker, "position:y", bob_bottom, 0.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	marker.set_meta("_bob_tween", bob_tween)


## マーカーに紐づくTweenをkill
static func _kill_marker_tweens(marker: Node3D) -> void:
	if marker.has_meta("_rotate_tween"):
		var tw: Tween = marker.get_meta("_rotate_tween")
		if tw and tw.is_valid():
			tw.kill()
		marker.remove_meta("_rotate_tween")
	if marker.has_meta("_bob_tween"):
		var tw: Tween = marker.get_meta("_bob_tween")
		if tw and tw.is_valid():
			tw.kill()
		marker.remove_meta("_bob_tween")


# ============================================
# 効果適用マーカー（赤マーカー、0.8秒で自動消滅）
# ============================================

## スペル効果適用時に赤マーカーを表示（0.8秒で自動消滅）
##
## handler: board_system を持つオブジェクト
## tile_index: マーカーを表示するタイルインデックス
## target_type: ターゲットタイプ（"creature", "player", "land" 等）
## target_player_id: プレイヤーターゲット時の対象プレイヤーID
static func show_effect_marker(handler, tile_index: int, target_type: String = "", target_player_id: int = -1, skip_fade: bool = false) -> Node3D:
	var board_sys = handler.board_system if "board_system" in handler else null
	if not board_sys or not board_sys.tile_nodes.has(tile_index):
		return null

	var tile = board_sys.tile_nodes[tile_index]

	# 赤マーカーを作成
	var marker: Node3D = create_marker_mesh("red")
	tile.add_child(marker)
	_init_marker_transform(marker)

	# Tweenでアニメーション（_processに依存しない自律駆動）
	_start_marker_tween(marker, tile)

	# 半透明化（全体スペルでは一括管理するためスキップ可能）
	if not skip_fade:
		fade_non_target_objects(handler, tile_index, target_type, target_player_id)

	return marker


## 赤マーカーを消去して半透明を復元
## skip_restore: trueなら半透明復元をスキップ（全体スペルで一括復元する場合）
static func hide_effect_marker(handler, marker: Node3D, skip_restore: bool = false) -> void:
	if marker and is_instance_valid(marker):
		_kill_marker_tweens(marker)
		if marker.get_parent():
			marker.get_parent().remove_child(marker)
		marker.queue_free()
	if not skip_restore:
		restore_all_creature_transparency(handler)


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
	var tile_pos = tile.global_position
	var look_target = tile_pos + Vector3(0, GameConstants.CAMERA_TILE_LOOK_HEIGHT, 0)
	camera.position = look_target + GameConstants.CAMERA_OFFSET
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


# ============================================
# 遮蔽物の半透明化（ターゲット選択時）
# ============================================

const OCCLUDER_ALPHA: float = 0.35  # 遮蔽物の半透明度

# 差分更新用キャッシュ（前回のフェード状態を記憶）
static var _last_fade_tile_index: int = -1
static var _last_fade_target_type: String = ""
static var _last_fade_player_id: int = -1

## 差分更新キャッシュをクリア
static func _clear_fade_cache() -> void:
	_last_fade_tile_index = -1
	_last_fade_target_type = ""
	_last_fade_player_id = -1


## 差分更新でフェード処理（前回と異なるタイルのみ更新）
static func _fade_with_diff(handler, target_tile_index: int, target_type: String = "", target_player_id: int = -1) -> void:
	# 前回と同じなら何もしない
	if target_tile_index == _last_fade_tile_index and target_type == _last_fade_target_type and target_player_id == _last_fade_player_id:
		return

	var board_sys = handler.board_system if "board_system" in handler else null
	if not board_sys:
		return

	var prev_tile: int = _last_fade_tile_index
	var prev_type: String = _last_fade_target_type
	var prev_pid: int = _last_fade_player_id

	# 初回（キャッシュなし）は全体走査
	if prev_tile < 0:
		fade_non_target_objects(handler, target_tile_index, target_type, target_player_id)
		_last_fade_tile_index = target_tile_index
		_last_fade_target_type = target_type
		_last_fade_player_id = target_player_id
		return

	# 差分更新: 前回の対象タイルを半透明に戻す
	if board_sys.tile_nodes.has(prev_tile):
		var old_tile = board_sys.tile_nodes[prev_tile]
		if "creature_card_3d" in old_tile and old_tile.creature_card_3d:
			if old_tile.creature_card_3d.has_method("set_transparency"):
				old_tile.creature_card_3d.set_transparency(OCCLUDER_ALPHA)

	# 差分更新: 新しい対象タイルを不透明にする
	if board_sys.tile_nodes.has(target_tile_index):
		var new_tile = board_sys.tile_nodes[target_tile_index]
		if "creature_card_3d" in new_tile and new_tile.creature_card_3d:
			if new_tile.creature_card_3d.has_method("set_transparency"):
				var card_alpha: float = OCCLUDER_ALPHA if target_type == "player" else 1.0
				new_tile.creature_card_3d.set_transparency(card_alpha)

	# プレイヤーキャラの差分更新
	if target_type == "player" or prev_type == "player":
		# プレイヤーターゲットの場合は対象が変わるので該当プレイヤーだけ更新
		if prev_type == "player" and prev_pid >= 0 and prev_pid < board_sys.player_nodes.size():
			var old_node = board_sys.player_nodes[prev_pid]
			if old_node:
				_set_node_transparency(old_node, OCCLUDER_ALPHA)
		if target_type == "player" and target_player_id >= 0 and target_player_id < board_sys.player_nodes.size():
			var new_node = board_sys.player_nodes[target_player_id]
			if new_node:
				_set_node_transparency(new_node, 1.0)
	else:
		# クリーチャーターゲット: タイル上のプレイヤーだけ更新
		# 前回の対象タイルにいたプレイヤーを半透明に
		for player_id in range(board_sys.player_nodes.size()):
			var player_tile: int = board_sys.get_player_tile(player_id)
			if player_tile == prev_tile or player_tile == target_tile_index:
				var player_node = board_sys.player_nodes[player_id]
				if not player_node:
					continue
				var is_new_target: bool = (player_tile == target_tile_index)
				var char_alpha: float = 1.0 if is_new_target and target_type != "creature" else OCCLUDER_ALPHA
				_set_node_transparency(player_node, char_alpha)

	_last_fade_tile_index = target_tile_index
	_last_fade_target_type = target_type
	_last_fade_player_id = target_player_id

## 選択タイル以外のオブジェクトを半透明にする
## target_type: "creature" → 選択タイルのカードは不透明、キャラは半透明
##              "player"   → 対象プレイヤーのキャラのみ不透明、他は全て半透明
##              その他     → 選択タイルは全て不透明
## target_player_id: プレイヤーターゲット時の対象プレイヤーID（-1で未指定）
static func fade_non_target_objects(handler, target_tile_index: int, target_type: String = "", target_player_id: int = -1) -> void:
	var board_sys = handler.board_system if "board_system" in handler else null
	if not board_sys:
		return

	# 全タイルのカードを処理
	for tile_idx in board_sys.tile_nodes.keys():
		var tile = board_sys.tile_nodes[tile_idx]
		var is_target_tile: bool = (tile_idx == target_tile_index)

		# カード透明度を決定
		var card_alpha: float = OCCLUDER_ALPHA
		if is_target_tile:
			# 対象タイル: creatureターゲット時はカード不透明、playerターゲット時はカード半透明
			card_alpha = OCCLUDER_ALPHA if target_type == "player" else 1.0

		if "creature_card_3d" in tile and tile.creature_card_3d:
			if tile.creature_card_3d.has_method("set_transparency"):
				tile.creature_card_3d.set_transparency(card_alpha)

	# 全プレイヤーの3Dキャラを処理
	for player_id in range(board_sys.player_nodes.size()):
		var player_node = board_sys.player_nodes[player_id]
		if not player_node:
			continue

		# キャラ透明度を決定
		var char_alpha: float = OCCLUDER_ALPHA
		if target_type == "player" and target_player_id >= 0:
			# プレイヤーターゲット: 対象プレイヤーIDで直接判定
			char_alpha = 1.0 if player_id == target_player_id else OCCLUDER_ALPHA
		else:
			var player_tile: int = board_sys.get_player_tile(player_id)
			var is_target_tile: bool = (player_tile == target_tile_index)
			if is_target_tile:
				char_alpha = OCCLUDER_ALPHA if target_type == "creature" else 1.0

		_set_node_transparency(player_node, char_alpha)


## 複数タイルの対象以外を半透明にする（全体スペル用）
##
## handler: board_system を持つオブジェクト
## target_tile_indices: 対象タイルインデックスの配列
static func fade_non_target_tiles(handler, target_tile_indices: Array) -> void:
	var board_sys = handler.board_system if "board_system" in handler else null
	if not board_sys:
		return

	# 全タイルのカードを処理
	for tile_idx in board_sys.tile_nodes.keys():
		var tile = board_sys.tile_nodes[tile_idx]
		var is_target: bool = target_tile_indices.has(tile_idx)
		var card_alpha: float = 1.0 if is_target else OCCLUDER_ALPHA

		if "creature_card_3d" in tile and tile.creature_card_3d:
			if tile.creature_card_3d.has_method("set_transparency"):
				tile.creature_card_3d.set_transparency(card_alpha)

	# 全プレイヤーの3Dキャラを半透明化（対象はクリーチャーなのでプレイヤーは常に半透明）
	for player_id in range(board_sys.player_nodes.size()):
		var player_node = board_sys.player_nodes[player_id]
		if not player_node:
			continue
		_set_node_transparency(player_node, OCCLUDER_ALPHA)


## 複数プレイヤー対象時に全クリーチャーカードを半透明にする（全プレイヤースペル用）
##
## handler: board_system を持つオブジェクト
## target_player_tile_indices: 対象プレイヤーがいるタイルインデックスの配列
static func fade_non_target_players(handler, target_player_tile_indices: Array) -> void:
	var board_sys = handler.board_system if "board_system" in handler else null
	if not board_sys:
		return

	# 全タイルのクリーチャーカードを半透明化（対象はプレイヤーなのでカードは常に半透明）
	for tile_idx in board_sys.tile_nodes.keys():
		var tile = board_sys.tile_nodes[tile_idx]
		if "creature_card_3d" in tile and tile.creature_card_3d:
			if tile.creature_card_3d.has_method("set_transparency"):
				tile.creature_card_3d.set_transparency(OCCLUDER_ALPHA)

	# 全プレイヤーの3Dキャラを処理（対象プレイヤーは不透明、それ以外は半透明）
	for player_id in range(board_sys.player_nodes.size()):
		var player_node = board_sys.player_nodes[player_id]
		if not player_node:
			continue
		var player_tile: int = board_sys.get_player_tile(player_id)
		var is_target: bool = target_player_tile_indices.has(player_tile)
		var char_alpha: float = 1.0 if is_target else OCCLUDER_ALPHA
		_set_node_transparency(player_node, char_alpha)


## すべてのカード・キャラの透明度を復元
static func restore_all_creature_transparency(handler) -> void:
	var board_sys = handler.board_system if "board_system" in handler else null
	if not board_sys:
		return

	# カード復元
	for tile_idx in board_sys.tile_nodes.keys():
		var tile = board_sys.tile_nodes[tile_idx]
		if "creature_card_3d" in tile and tile.creature_card_3d:
			if tile.creature_card_3d.has_method("set_transparency"):
				tile.creature_card_3d.set_transparency(1.0)

	# キャラ復元
	for player_node in board_sys.player_nodes:
		if player_node:
			_set_node_transparency(player_node, 1.0)

	_clear_fade_cache()


## カメラドラッグ中は半透明を解除、戻ったら再適用
static func _update_fade_for_camera(handler, marker: Node3D) -> void:
	var board_sys = handler.board_system if "board_system" in handler else null
	if not board_sys or not board_sys.camera_controller:
		return

	var is_dragging: bool = board_sys.camera_controller.is_user_controlling()
	var was_dragging: bool = marker.get_meta("was_camera_dragging", false)

	if is_dragging and not was_dragging:
		# ドラッグ開始 → 全て不透明に
		restore_all_creature_transparency(handler)
		marker.set_meta("was_camera_dragging", true)
	elif not is_dragging and was_dragging:
		# ドラッグ終了 → 半透明を再適用（全体走査が必要）
		var parent_tile = marker.get_parent()
		if parent_tile and "tile_index" in parent_tile:
			var target_type: String = marker.get_meta("target_type", "")
			var target_pid: int = marker.get_meta("target_player_id", -1)
			# 復元直後なのでキャッシュをクリアして全体走査
			_last_fade_tile_index = -1
			fade_non_target_objects(handler, parent_tile.tile_index, target_type, target_pid)
			_last_fade_tile_index = parent_tile.tile_index
			_last_fade_target_type = target_type
			_last_fade_player_id = target_pid
		marker.set_meta("was_camera_dragging", false)


## Node3D配下の全MeshInstance3Dの透明度を設定
static func _set_node_transparency(node: Node3D, alpha: float) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mat = child.get_active_material(0)
			if mat and mat is StandardMaterial3D:
				var mat_copy: StandardMaterial3D = mat.duplicate() if not child.material_override else child.material_override
				if alpha < 1.0:
					mat_copy.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					mat_copy.albedo_color.a = alpha
				else:
					mat_copy.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
					mat_copy.albedo_color.a = 1.0
				child.material_override = mat_copy
		if child is Node3D:
			_set_node_transparency(child, alpha)
