class_name CameraController
extends Node

## カメラ制御システム
## ドラッグ移動、モード管理、移動範囲制限、タップ選択を担当

# ========================================
# カメラモード
# ========================================

enum CameraMode {
	FIXED,      # 固定（操作不可）
	FOLLOW,     # プレイヤー追従
	MANUAL      # 手動操作可能
}

# ========================================
# シグナル
# ========================================

signal tile_tapped(tile_index: int, tile_data: Dictionary)
signal creature_tapped(tile_index: int, creature_data: Dictionary)
signal empty_tapped()  # タイル外をタップした時

# ========================================
# 設定
# ========================================

## ドラッグ感度
@export var drag_sensitivity: float = 0.05

## カメラ移動時間（秒）
@export var camera_move_duration: float = 0.5

## カメラの高さ（Y座標、固定）
@export var camera_height: float = 15.0

## タップ判定の移動閾値（これ以上動いたらドラッグ扱い）
@export var tap_threshold: float = 10.0

## カメラオフセット（GameConstantsから参照）

# ========================================
# 状態
# ========================================

var camera: Camera3D = null
var current_mode: CameraMode = CameraMode.FOLLOW
var is_dragging: bool = false
var current_player_id: int = 0

## タップ検出用
var _touch_start_position: Vector2 = Vector2.ZERO
var _total_drag_distance: float = 0.0
var _is_potential_tap: bool = false

## 現在のTween（競合防止用）
var current_tween: Tween = null
var _direction_tween: Tween = null  # 方向選択/到着予測カメラ用Tween

## 外部参照
var board_system = null
var player_system = null

## 凸包境界（マップ形状に合わせた移動制限）
var _boundary_hull: PackedVector2Array = PackedVector2Array()
var _boundary_center: Vector2 = Vector2.ZERO
var _boundary_initialized: bool = false

# ========================================
# 初期化
# ========================================

func setup(cam: Camera3D, board, player_sys):
	camera = cam
	board_system = board
	player_system = player_sys
	
	# マップ境界を計算
	_calculate_boundary_hull()


# ========================================
# 境界計算（凸包）
# ========================================

func _calculate_boundary_hull():
	"""タイル座標から凸包を計算してカメラ移動境界を設定"""
	if not board_system or not board_system.tile_nodes:
		return
	
	# 全タイルの座標を収集（X-Z平面）
	var points: PackedVector2Array = PackedVector2Array()
	for tile_index in board_system.tile_nodes:
		var tile = board_system.tile_nodes[tile_index]
		var pos = tile.global_position
		points.append(Vector2(pos.x, pos.z))
	
	if points.size() < 3:
		return
	
	# 凸包を計算
	_boundary_hull = _compute_convex_hull(points)
	
	# 中心点を計算
	_boundary_center = Vector2.ZERO
	for point in _boundary_hull:
		_boundary_center += point
	_boundary_center /= _boundary_hull.size()
	
	_boundary_initialized = true
	print("[CameraController] 境界凸包計算完了: %d頂点" % _boundary_hull.size())


func _compute_convex_hull(points: PackedVector2Array) -> PackedVector2Array:
	"""Graham Scanアルゴリズムで凸包を計算"""
	if points.size() < 3:
		return points
	
	# 最も下（Y最小）、同じなら左（X最小）の点を基準点とする
	var start_idx = 0
	for i in range(1, points.size()):
		if points[i].y < points[start_idx].y or \
		   (points[i].y == points[start_idx].y and points[i].x < points[start_idx].x):
			start_idx = i
	
	var start_point = points[start_idx]
	
	# 基準点からの角度でソート
	var sorted_points: Array = []
	for i in range(points.size()):
		if i != start_idx:
			sorted_points.append(points[i])
	
	sorted_points.sort_custom(func(a, b):
		var angle_a = atan2(a.y - start_point.y, a.x - start_point.x)
		var angle_b = atan2(b.y - start_point.y, b.x - start_point.x)
		if abs(angle_a - angle_b) < 0.0001:
			return start_point.distance_to(a) < start_point.distance_to(b)
		return angle_a < angle_b
	)
	
	# スタックで凸包を構築
	var hull: Array = [start_point]
	for point in sorted_points:
		while hull.size() > 1 and _cross_product(hull[-2], hull[-1], point) <= 0:
			hull.pop_back()
		hull.append(point)
	
	var result = PackedVector2Array()
	for p in hull:
		result.append(p)
	return result


func _cross_product(o: Vector2, a: Vector2, b: Vector2) -> float:
	"""外積を計算（反時計回りなら正）"""
	return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)


func _is_point_in_hull(point: Vector2) -> bool:
	"""点が凸包内にあるかチェック"""
	if not _boundary_initialized or _boundary_hull.size() < 3:
		return true  # 境界未設定なら制限なし
	
	var n = _boundary_hull.size()
	for i in range(n):
		var a = _boundary_hull[i]
		var b = _boundary_hull[(i + 1) % n]
		if _cross_product(a, b, point) < 0:
			return false
	return true


func _clamp_to_hull(point: Vector2) -> Vector2:
	"""点を凸包内に収める"""
	if _is_point_in_hull(point):
		return point
	
	# 凸包の最も近い点を探す
	var closest = point
	var min_dist = INF
	
	var n = _boundary_hull.size()
	for i in range(n):
		var a = _boundary_hull[i]
		var b = _boundary_hull[(i + 1) % n]
		var projected = _closest_point_on_segment(point, a, b)
		var dist = point.distance_to(projected)
		if dist < min_dist:
			min_dist = dist
			closest = projected
	
	return closest


func _closest_point_on_segment(point: Vector2, a: Vector2, b: Vector2) -> Vector2:
	"""線分上の最近点を計算"""
	var ab = b - a
	var ap = point - a
	var t = clamp(ap.dot(ab) / ab.dot(ab), 0.0, 1.0)
	return a + ab * t


# ========================================
# モード管理
# ========================================

## フェーズに応じてモードを設定
func set_mode_for_phase(phase: int, is_my_turn: bool):
	if not is_my_turn:
		current_mode = CameraMode.FOLLOW
		return
	
	match phase:
		1, 3:  # DICE_ROLL, TILE_ACTION に相当
			current_mode = CameraMode.MANUAL
		_:
			current_mode = CameraMode.FOLLOW

## スペル/召喚フェーズで手動モードを有効化
func enable_manual_mode():
	current_mode = CameraMode.MANUAL


## 固定モードに戻す
func enable_follow_mode():
	current_mode = CameraMode.FOLLOW
	is_dragging = false


## 現在手動操作中かどうか
func is_user_controlling() -> bool:
	return current_mode == CameraMode.MANUAL and is_dragging

## 手動モードかどうか
func is_manual_mode() -> bool:
	return current_mode == CameraMode.MANUAL

# ========================================
# 入力処理
# ========================================

func _input(event):
	if current_mode != CameraMode.MANUAL:
		return
	
	if not camera:
		return
	
	# マウスクリック
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# UIの上かどうかチェック
			if _is_over_ui(event.position):
				return
			
			if event.pressed:
				_start_touch(event.position)
			else:
				_end_touch(event.position)
	
	# スクリーンタッチ（モバイル）
	if event is InputEventScreenTouch:
		# UIの上かどうかチェック
		if _is_over_ui(event.position):
			return
		
		if event.pressed:
			_start_touch(event.position)
		else:
			_end_touch(event.position)
	
	# ドラッグ移動
	if event is InputEventMouseMotion and is_dragging:
		_total_drag_distance += event.relative.length()
		_move_camera(event.relative)
	
	# スクリーンドラッグ（モバイル）
	if event is InputEventScreenDrag:
		_total_drag_distance += event.relative.length()
		_move_camera(event.relative)


## 指定位置にUIがあるかチェック
func _is_over_ui(_screen_pos: Vector2) -> bool:
	"""画面位置にUIコントロールがあるかを判定"""
	var viewport = camera.get_viewport()
	if not viewport:
		return false
	
	# GUIにフォーカスがあるか、マウスがGUI上にあるか
	var gui_control = viewport.gui_get_focus_owner()
	if gui_control:
		return true
	
	# ビューポートのGUIがマウス入力をブロックしているか
	# get_mouse_position()でなくscreen_posを使用
	var hovered = viewport.gui_get_hovered_control()
	if hovered:
		return true
	
	return false


func _start_touch(position: Vector2):
	"""タッチ/クリック開始"""
	_touch_start_position = position
	_total_drag_distance = 0.0
	_is_potential_tap = true
	is_dragging = true


func _end_touch(position: Vector2):
	"""タッチ/クリック終了"""
	is_dragging = false

	# 移動量が閾値以下ならタップとして処理
	if _is_potential_tap and _total_drag_distance < tap_threshold:
		_handle_tap(position)

	_is_potential_tap = false


func _handle_tap(screen_position: Vector2):
	"""タップ処理：Raycastでタイルを検出"""
	print("[CameraController] タップ検出: %s" % screen_position)
	
	if not camera or not board_system:
		print("[CameraController] カメラまたはボードシステムがない")
		return
	
	# スクリーン座標からレイを生成
	var from = camera.project_ray_origin(screen_position)
	var to = from + camera.project_ray_normal(screen_position) * 1000.0
	
	# PhysicsRayQueryを使用
	var space_state = camera.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	
	var result = space_state.intersect_ray(query)
	
	if result.is_empty():
		print("[CameraController] Raycastヒットなし - 空タップ")
		empty_tapped.emit()
		return
	
	# ヒットしたオブジェクトからタイルを特定
	var hit_object = result.collider
	print("[CameraController] ヒットオブジェクト: %s" % hit_object.name if hit_object else "null")
	
	var tile = _find_tile_from_object(hit_object)
	
	if tile:
		print("[CameraController] タイル検出: %s (index: %d)" % [tile.name, tile.tile_index if "tile_index" in tile else -1])
		_on_tile_tapped(tile)


func _find_tile_from_object(obj: Node) -> Node:
	"""オブジェクトから親のタイルノードを探す"""
	var current = obj
	while current:
		if current.has_method("get_tile_info"):
			return current
		current = current.get_parent()
	return null


func _on_tile_tapped(tile: Node):
	"""タイルがタップされた時の処理"""
	var tile_info = tile.get_tile_info() if tile.has_method("get_tile_info") else {}
	var tile_index = tile.tile_index if "tile_index" in tile else -1
	
	# シグナルを発火
	tile_tapped.emit(tile_index, tile_info)
	
	# クリーチャーがいる場合は追加シグナル
	var creature_data = tile.creature_data if "creature_data" in tile else {}
	if not creature_data.is_empty():
		creature_tapped.emit(tile_index, creature_data)
		print("[CameraController] クリーチャータップ: タイル%d - %s" % [tile_index, creature_data.get("name", "不明")])


## カメラを移動
func _move_camera(delta: Vector2):
	if not camera:
		return
	
	# X/Z平面での移動（Y軸回転を考慮）
	var move_x = -delta.x * drag_sensitivity
	var move_z = delta.y * drag_sensitivity
	
	# カメラの向きに合わせて移動方向を調整
	var forward = -camera.global_transform.basis.z
	forward.y = 0
	forward = forward.normalized()
	
	var right = camera.global_transform.basis.x
	right.y = 0
	right = right.normalized()
	
	var movement = right * move_x + forward * move_z
	
	# 新しい位置を計算
	var new_pos = camera.global_position + movement
	
	# 画面中央が見ている地点で境界判定
	var look_point = _get_screen_center_ground_point(new_pos)
	if look_point != Vector2.INF:
		var clamped_look = _clamp_to_hull(look_point)
		
		# 見ている地点がクランプされた場合、カメラ位置も調整
		if look_point != clamped_look:
			var offset = clamped_look - look_point
			new_pos.x += offset.x
			new_pos.z += offset.y
	
	camera.global_position = new_pos


## 指定カメラ位置から画面中央が地面と交差する点を取得
func _get_screen_center_ground_point(cam_pos: Vector3) -> Vector2:
	"""画面中央のレイが地面（Y=0平面）と交差する点を計算"""
	if not camera:
		return Vector2.INF
	
	# カメラの向きベクトルを取得
	var cam_forward = -camera.global_transform.basis.z
	
	# Y=0平面との交差を計算
	# cam_pos + t * cam_forward で Y = 0 となる t を求める
	if abs(cam_forward.y) < 0.001:
		# カメラが水平を向いている場合は交差しない
		return Vector2.INF
	
	var t = -cam_pos.y / cam_forward.y
	if t < 0:
		# カメラが上を向いている場合
		return Vector2.INF
	
	var ground_point = cam_pos + cam_forward * t
	return Vector2(ground_point.x, ground_point.z)

# ========================================
# フォーカス機能
# ========================================

## 現在のプレイヤーIDを設定
func set_current_player(player_id: int):
	current_player_id = player_id

## プレイヤー位置に戻す（スムーズ移動）
func return_to_player(smooth: bool = true):
	if not camera or not board_system or not player_system:
		return
	
	focus_on_player(current_player_id, smooth)
	is_dragging = false

## 指定プレイヤーにフォーカス
func focus_on_player(player_id: int, smooth: bool = true):
	if not camera or not board_system:
		return
	
	var tile_index = board_system.get_player_tile(player_id)
	focus_on_tile(tile_index, smooth)

## 指定タイルにフォーカス
func focus_on_tile(tile_index: int, smooth: bool = true):
	if not camera or not board_system:
		return
	
	if not board_system.tile_nodes.has(tile_index):
		return
	
	var tile = board_system.tile_nodes[tile_index]
	var tile_pos = tile.global_position
	var look_target = tile_pos + Vector3(0, 1.0, 0)
	var new_camera_pos = look_target + GameConstants.CAMERA_OFFSET
	
	if camera.global_position.distance_to(new_camera_pos) < 0.5:
		return
	
	if smooth:
		_smooth_move_to(new_camera_pos, look_target)
	else:
		camera.global_position = new_camera_pos
		camera.look_at(look_target + Vector3(0, GameConstants.CAMERA_LOOK_OFFSET_Y, 0), Vector3.UP)

## 指定タイルにゆっくりフォーカス（到着予測カメラ用）
func focus_on_tile_slow(tile_index: int, duration: float = 1.2):
	if not camera or not board_system:
		return
	if not board_system.tile_nodes.has(tile_index):
		return
	var tile = board_system.tile_nodes[tile_index]
	var tile_pos = tile.global_position
	var lt = tile_pos + Vector3(0, 1.0, 0)
	var cp = lt + GameConstants.CAMERA_OFFSET
	if camera.global_position.distance_to(cp) < 0.3:
		return
	_smooth_transition_to(cp, lt, duration)

## 指定位置にゆっくりフォーカス（方向選択カメラ用）
func focus_on_position_slow(world_pos: Vector3, duration: float = 0.5):
	if not camera:
		return
	# マップ境界内にクランプ
	var clamped_xz = _clamp_to_hull(Vector2(world_pos.x, world_pos.z))
	var clamped_pos = Vector3(clamped_xz.x, world_pos.y, clamped_xz.y)
	var lt = clamped_pos + Vector3(0, 1.0, 0)
	var cp = lt + GameConstants.CAMERA_OFFSET
	if camera.global_position.distance_to(cp) < 0.3:
		return
	_smooth_transition_to(cp, lt, duration)

## 方向選択/到着予測のカメラTweenが動作中か
func is_direction_camera_active() -> bool:
	return _direction_tween != null and _direction_tween.is_valid() and _direction_tween.is_running()

## 方向選択/到着予測カメラTweenをキャンセル
func cancel_direction_tween():
	if _direction_tween and _direction_tween.is_valid():
		_direction_tween.kill()
		_direction_tween = null

## 前のTweenをキャンセルせず滑らかに新目標へ移行（方向選択用）
## カメラ位置のみ移動し、アングル（look_at）は変えない
func _smooth_transition_to(target_pos: Vector3, _look_target: Vector3, duration: float):
	if _direction_tween and _direction_tween.is_valid():
		_direction_tween.kill()
	_direction_tween = create_tween()
	_direction_tween.tween_property(camera, "global_position", target_pos, duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)

## スムーズにカメラを移動
func _smooth_move_to(target_pos: Vector3, look_target: Vector3):
	cancel_tween()
	
	current_tween = create_tween()
	current_tween.set_parallel(true)
	current_tween.tween_property(camera, "global_position", target_pos, camera_move_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	current_tween.set_parallel(false)
	current_tween.tween_callback(func(): camera.look_at(look_target + Vector3(0, GameConstants.CAMERA_LOOK_OFFSET_Y, 0), Vector3.UP))

## 現在のTweenをキャンセル
func cancel_tween():
	if current_tween and current_tween.is_valid():
		current_tween.kill()
		current_tween = null

## Tween動作中かどうか
func is_tweening() -> bool:
	return current_tween != null and current_tween.is_valid()

## Tween完了を待機
func await_tween_completion() -> void:
	if current_tween and current_tween.is_valid():
		await current_tween.finished


# ========================================
# 境界の再計算（マップ変更時用）
# ========================================

func recalculate_boundary():
	"""境界を再計算（マップが動的に変わる場合用）"""
	_calculate_boundary_hull()
