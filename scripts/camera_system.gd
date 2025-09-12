extends Node
class_name CameraSystem

# カメラ管理システム
# ズーム、移動、プレイヤー追従を制御

signal zoom_changed(zoom_level: float)
signal camera_moved(position: Vector2)

# カメラ設定
const MIN_ZOOM = 0.5  # 最小ズーム（全体表示）
const MAX_ZOOM = 2.0  # 最大ズーム（詳細表示）
const DEFAULT_ZOOM = 1.0  # デフォルトズーム
const ZOOM_STEP = 0.1  # ズーム変化量
const CAMERA_SPEED = 300.0  # 手動移動速度

# カメラ参照
var camera: Camera2D = null
var is_following_player = true
var manual_control = false  # 初期は自動追従モード
var current_zoom = DEFAULT_ZOOM

# 移動制限（マップ全体を見渡せるように拡張）
var map_bounds: Rect2 = Rect2(-200, -200, 1400, 1000)  # 右側と全体を拡張

func _ready():
	pass

# カメラを初期化
func initialize(parent_node: Node) -> Camera2D:
	# Camera2Dを作成
	camera = Camera2D.new()
	camera.name = "MainCamera"
	camera.enabled = true
	camera.zoom = Vector2(DEFAULT_ZOOM, DEFAULT_ZOOM)
	
	# 初期位置をプレイヤー情報パネルの間（画面中央）に設定
	# プレイヤー1パネル右端(200) + プレイヤー2パネル左端(600) の中間 = 400
	# 少し下にオフセット
	camera.position = Vector2(400, 350)  
	
	# スムージング設定
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	
	parent_node.add_child(camera)
	
	# 初期状態を自動追従モードに設定
	manual_control = false
	is_following_player = true
	
	print("CameraSystem: カメラ初期化完了")
	print("カメラ操作: 矢印キーまたはIJKLで移動、+/-でズーム、Fでプレイヤーフォーカス")
	print("現在: 自動追従モード（スペースキーで手動モードに切り替え可能）")
	return camera

# 入力処理
func _input(event):
	if not camera:
		return
	
	# ズーム処理（マウスホイール）
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_in()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_out()
	
	# キーボードショートカット
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_EQUAL, KEY_KP_ADD:  # +キー
				zoom_in()
			KEY_MINUS, KEY_KP_SUBTRACT:  # -キー
				zoom_out()
			KEY_F:  # Fキーで現在プレイヤーにフォーカス
				focus_on_current_player()
			KEY_SPACE:  # スペースで手動/自動切り替え
				toggle_manual_control()
			KEY_C:  # Cキーでボード中心にフォーカス
				focus_on_board_center()
			KEY_R:  # Rキーでリセット（初期位置に戻る）
				reset_camera_position()

# プロセス処理（手動カメラ移動）
func _process(delta):
	if not camera or not manual_control:
		return
	
	var move_vector = Vector2.ZERO
	
	# 矢印キーまたはIJKLで移動
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_J):
		move_vector.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_L):
		move_vector.x += 1
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_I):
		move_vector.y -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_K):
		move_vector.y += 1
	
	if move_vector != Vector2.ZERO:
		move_vector = move_vector.normalized() * CAMERA_SPEED * delta
		move_camera(camera.position + move_vector)

# ズームイン
func zoom_in():
	set_zoom(current_zoom + ZOOM_STEP)

# ズームアウト
func zoom_out():
	set_zoom(current_zoom - ZOOM_STEP)

# ズーム設定
func set_zoom(zoom_level: float):
	current_zoom = clamp(zoom_level, MIN_ZOOM, MAX_ZOOM)
	
	if camera:
		var tween = get_tree().create_tween()
		tween.tween_property(camera, "zoom", Vector2(current_zoom, current_zoom), 0.2)
		
		emit_signal("zoom_changed", current_zoom)
		print("ズーム: ", current_zoom)

# カメラ位置を設定
func move_camera(position: Vector2):
	if not camera:
		return
	
	# マップ境界内に制限
	position.x = clamp(position.x, map_bounds.position.x, map_bounds.position.x + map_bounds.size.x)
	position.y = clamp(position.y, map_bounds.position.y, map_bounds.position.y + map_bounds.size.y)
	
	camera.position = position
	emit_signal("camera_moved", position)

# プレイヤーにフォーカス
func focus_on_player(player_position: Vector2):
	if not camera:
		return
	
	if is_following_player and not manual_control:
		var tween = get_tree().create_tween()
		tween.tween_property(camera, "position", player_position, 0.5)

# 現在のプレイヤーにフォーカス
func focus_on_current_player():
	manual_control = false
	is_following_player = true
	
	# PlayerSystemから現在のプレイヤー位置を取得
	var player_system = get_tree().get_root().get_node_or_null("Game/PlayerSystem")
	if player_system:
		var current_player = player_system.get_current_player()
		if current_player and current_player.piece_node:
			focus_on_player(current_player.piece_node.position)
	
	print("カメラ: 自動追従モード")

# ボード中心にフォーカス
func focus_on_board_center():
	if camera:
		var tween = get_tree().create_tween()
		tween.tween_property(camera, "position", Vector2(400, 400), 0.5)
		print("カメラ: ボード中心にフォーカス")

# カメラを初期位置にリセット
func reset_camera_position():
	if camera:
		var tween = get_tree().create_tween()
		tween.tween_property(camera, "position", Vector2(400, 350), 0.5)
		current_zoom = DEFAULT_ZOOM
		camera.zoom = Vector2(DEFAULT_ZOOM, DEFAULT_ZOOM)
		print("カメラ: 初期位置にリセット")

# 手動/自動制御切り替え
func toggle_manual_control():
	manual_control = !manual_control
	
	if manual_control:
		is_following_player = false
		print("カメラ: 手動操作モード (矢印キー/IJKLで移動)")
	else:
		is_following_player = true
		focus_on_current_player()

# マップ境界を設定
func set_map_bounds(bounds: Rect2):
	map_bounds = bounds
	print("カメラ境界設定: ", bounds)

# デバッグ情報取得
func get_debug_info() -> String:
	if not camera:
		return "カメラ未初期化"
	
	return "ズーム: %.1f | 位置: %s | モード: %s" % [
		current_zoom,
		camera.position,
		"手動" if manual_control else "自動"
	]
