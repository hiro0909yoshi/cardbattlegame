# DebugCommandHandler - デバッグ用のキーコマンド処理
extends Node
class_name DebugCommandHandler

## 参照
var board_system_3d
var land_command_handler

## デバッグモード
var debug_mode: bool = false

func _ready():
	print("[DebugCommandHandler] 初期化完了")
	set_process_input(true)

## 初期化
func initialize(board_sys, land_cmd_handler):
	board_system_3d = board_sys
	land_command_handler = land_cmd_handler
	print("[DebugCommandHandler] 参照設定完了")

## デバッグモード切り替え
func toggle_debug_mode():
	debug_mode = not debug_mode
	print("[DebugCommandHandler] デバッグモード: ", "ON" if debug_mode else "OFF")

## 入力処理
func _input(event):
	if not debug_mode:
		return
	
	if event is InputEventKey and event.pressed:
		# 数字キー 0-9 で土地選択
		if event.keycode >= KEY_0 and event.keycode <= KEY_9:
			var tile_index = event.keycode - KEY_0
			on_number_key_pressed(tile_index)
		
		# Cキーでダウン状態解除
		elif event.keycode == KEY_C:
			on_clear_down_pressed()

## 数字キー押下（土地選択）
func on_number_key_pressed(tile_index: int):
	print("[DebugCommandHandler] 数字キー押下: ", tile_index)
	
	if land_command_handler and land_command_handler.is_active:
		land_command_handler.select_tile(tile_index)

## Cキー押下（ダウン解除）
func on_clear_down_pressed():
	print("[DebugCommandHandler] ダウン状態一括解除")
	
	if not board_system_3d:
		return
	
	var cleared_count = 0
	for tile in board_system_3d.tiles:
		if tile.is_down():
			tile.clear_down_state()
			cleared_count += 1
	
	print("[DebugCommandHandler] ", cleared_count, "個の土地のダウンを解除")
