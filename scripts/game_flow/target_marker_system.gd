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
const MARKER_BOB_AMPLITUDE: float = 0.2    # ボビング振幅
const MARKER_BOB_BASE_Y: float = 0.5       # ボビング基準Y位置
const MARKER_ROTATE_SPEED: float = 2.5     # Y軸周回速度(rad/s)
const MARKER_ORBIT_RADIUS: float = 1.8     # 周回半径（タイルを包むサイズ）
const MARKER_ORB_COUNT: int = 2            # 光の玉の数
const MARKER_ORB_RADIUS: float = 0.12      # 光の玉の半径
const MARKER_ORB_HEIGHT: float = 0.24      # 光の玉の高さ

# トレイル（残光）定数
const TRAIL_AMOUNT: int = 80               # トレイル粒子の数
const TRAIL_LIFETIME: float = 0.2          # トレイル寿命(秒)
const TRAIL_QUAD_SIZE: float = 0.2         # トレイルQuadのサイズ
const TRAIL_SCALE_MIN: float = 0.1         # トレイル粒子の最小スケール（生成時）
const TRAIL_SCALE_MAX: float = 1.0         # トレイル粒子の最大スケール（生成時）
const TRAIL_SCALE_OVER_LIFE_MIN: float = 1.0  # ライフ開始時のスケール
const TRAIL_SCALE_OVER_LIFE_MAX: float = 0.0  # ライフ終了時のスケール（消滅）

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
## 光の玉が円状に周回するマーカー
## 戻り値: Node3D（コンテナ）の中に複数の光の玉（MeshInstance3D）
static func create_marker_mesh() -> Node3D:
	var container = Node3D.new()

	# 発光マテリアルを共有
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 1.0, 0.3, 0.85)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.9, 0.2)
	material.emission_energy_multiplier = 4.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# トレイル用QuadMesh（ビルボード、全パーティクル共有 - 2ポリゴンで軽量）
	var trail_quad = QuadMesh.new()
	trail_quad.size = Vector2(TRAIL_QUAD_SIZE, TRAIL_QUAD_SIZE)

	# トレイル用マテリアル（発光＋半透明、ビルボード、VertexColor対応）
	var trail_material = StandardMaterial3D.new()
	trail_material.albedo_color = Color(1.0, 1.0, 0.3, 0.8)
	trail_material.emission_enabled = true
	trail_material.emission = Color(1.0, 0.9, 0.2)
	trail_material.emission_energy_multiplier = 3.0
	trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_material.vertex_color_use_as_albedo = true  # color_rampのフェードを反映
	trail_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED  # 常にカメラを向く

	# 光の玉を等間隔に配置
	for i in range(MARKER_ORB_COUNT):
		var orb = MeshInstance3D.new()
		var sphere = SphereMesh.new()
		sphere.radius = MARKER_ORB_RADIUS
		sphere.height = MARKER_ORB_HEIGHT
		orb.mesh = sphere
		orb.material_override = material

		# 周回半径上に等間隔配置
		var angle: float = TAU * i / MARKER_ORB_COUNT
		orb.position = Vector3(
			cos(angle) * MARKER_ORBIT_RADIUS,
			0,
			sin(angle) * MARKER_ORBIT_RADIUS
		)

		# トレイル（残光パーティクル）を追加
		var trail = _create_trail_particles(trail_quad, trail_material)
		orb.add_child(trail)

		container.add_child(orb)

	return container


## トレイル用GPUParticles3Dを作成
static func _create_trail_particles(draw_mesh: QuadMesh, mat_override: StandardMaterial3D) -> GPUParticles3D:
	var particles = GPUParticles3D.new()
	particles.amount = TRAIL_AMOUNT
	particles.lifetime = TRAIL_LIFETIME
	particles.local_coords = false  # ワールド座標で残す（移動跡が残る）
	particles.draw_pass_1 = draw_mesh
	particles.material_override = mat_override

	# パーティクルの挙動設定
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	mat.direction = Vector3.ZERO
	mat.spread = 0.0
	mat.initial_velocity_min = 0.0
	mat.initial_velocity_max = 0.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = TRAIL_SCALE_MIN
	mat.scale_max = TRAIL_SCALE_MAX

	# 色のフェードアウト（明るい黄金色 → 透明に徐々に薄くなる）
	var color_gradient = Gradient.new()
	color_gradient.set_color(0, Color(1.0, 1.0, 0.3, 0.7))
	color_gradient.add_point(0.3, Color(1.0, 0.95, 0.2, 0.4))
	color_gradient.set_color(1, Color(1.0, 0.7, 0.1, 0.0))
	var color_texture = GradientTexture1D.new()
	color_texture.gradient = color_gradient
	mat.color_ramp = color_texture

	# スケールのフェード（大→小に縮んで消える）
	var scale_curve = CurveTexture.new()
	var curve = Curve.new()
	curve.add_point(Vector2(0.0, TRAIL_SCALE_OVER_LIFE_MIN))
	curve.add_point(Vector2(1.0, TRAIL_SCALE_OVER_LIFE_MAX))
	scale_curve.curve = curve
	mat.scale_curve = scale_curve

	particles.process_material = mat

	return particles


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
	
	# カメラを土地の上方に移動
	var tile_pos = tile.global_position
	var camera_offset = Vector3(12, 15, 12)
	camera.position = tile_pos + camera_offset
	
	# カメラを土地に向ける
	camera.look_at(tile_pos + Vector3(0, GameConstants.CAMERA_LOOK_OFFSET_Y, 0), Vector3.UP)


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
