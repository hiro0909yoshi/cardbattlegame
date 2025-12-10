class_name CameraController
extends Node

## カメラ制御システム
## ドラッグ移動、モード管理、移動範囲制限を担当

# ========================================
# カメラモード
# ========================================

enum CameraMode {
	FIXED,      # 固定（操作不可）
	FOLLOW,     # プレイヤー追従
	MANUAL      # 手動操作可能
}

# ========================================
# 設定
# ========================================

## ドラッグ感度
@export var drag_sensitivity: float = 0.05

## カメラ移動時間（秒）
@export var camera_move_duration: float = 0.5

## 移動範囲制限（マップに合わせて調整）
@export var min_x: float = -50.0
@export var max_x: float = 50.0
@export var min_z: float = -50.0
@export var max_z: float = 50.0

## カメラの高さ（Y座標、固定）
@export var camera_height: float = 15.0

## カメラオフセット（GameConstantsから参照）
const GameConstants = preload("res://scripts/game_constants.gd")

# ========================================
# 状態
# ========================================

var camera: Camera3D = null
var current_mode: CameraMode = CameraMode.FOLLOW
var is_dragging: bool = false
var current_player_id: int = 0

## 現在のTween（競合防止用）
var current_tween: Tween = null

## 外部参照
var board_system = null
var player_system = null

# ========================================
# 初期化
# ========================================

func setup(cam: Camera3D, board, player_sys):
	camera = cam
	board_system = board
	player_system = player_sys


# ========================================
# モード管理
# ========================================

## フェーズに応じてモードを設定
func set_mode_for_phase(phase: int, is_my_turn: bool):
	if not is_my_turn:
		current_mode = CameraMode.FOLLOW
		return
	
	# GameFlowManager.GamePhase の値に対応
	# SPELL = フェーズ変更前にスペルフェーズかどうかで判断
	# TILE_ACTION = 領地コマンド（召喚等）
	match phase:
		1, 3:  # DICE_ROLL, TILE_ACTION に相当（要調整）
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
	
	# マウス/タッチのドラッグ開始・終了
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_dragging = event.pressed
	
	# スクリーンタッチ（スマホ対応）
	if event is InputEventScreenTouch:
		is_dragging = event.pressed
	
	# ドラッグ移動
	if event is InputEventMouseMotion and is_dragging:
		_move_camera(event.relative)
	
	# スクリーンドラッグ（スマホ対応）
	if event is InputEventScreenDrag:
		_move_camera(event.relative)

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
	
	# 範囲制限を適用
	new_pos.x = clamp(new_pos.x, min_x, max_x)
	new_pos.z = clamp(new_pos.z, min_z, max_z)
	
	camera.global_position = new_pos

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
	
	# MovementControllerからプレイヤー位置を取得
	if board_system.movement_controller:
		var tile_index = board_system.movement_controller.get_player_tile(player_id)
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
	
	# すでに目標位置に近い場合はスキップ（Tween競合防止）
	if camera.global_position.distance_to(new_camera_pos) < 0.5:
		return
	
	if smooth:
		_smooth_move_to(new_camera_pos, look_target)
	else:
		camera.global_position = new_camera_pos
		camera.look_at(look_target, Vector3.UP)
		camera.look_at(look_target, Vector3.UP)

## スムーズにカメラを移動
func _smooth_move_to(target_pos: Vector3, look_target: Vector3):
	# 既存のTweenをキャンセル
	cancel_tween()
	
	current_tween = create_tween()
	current_tween.set_parallel(true)
	current_tween.tween_property(camera, "global_position", target_pos, camera_move_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	# look_atはTweenできないので、移動完了後に設定
	current_tween.set_parallel(false)
	current_tween.tween_callback(func(): camera.look_at(look_target, Vector3.UP))

## 現在のTweenをキャンセル（外部からも呼び出し可能）
func cancel_tween():
	if current_tween and current_tween.is_valid():
		current_tween.kill()
		current_tween = null
