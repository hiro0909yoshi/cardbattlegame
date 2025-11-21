extends Node

# 3Dゲームメイン管理スクリプト
# GameSystemManager への委譲により大幅に簡潔化

# システム参照
var system_manager: GameSystemManager

# 設定
var player_count = 2
var player_is_cpu = [false, true]  # Player1=人間, Player2=CPU

# 🔧 デバッグ設定: trueにするとCPUも手動操作できる
var debug_manual_control_all = true  # デバッグモード有効化

func _ready():
	# GameSystemManager を作成・初期化
	system_manager = GameSystemManager.new()
	add_child(system_manager)
	
	# 全フェーズを実行（Phase 1-6）
	system_manager.initialize_all(
		self,
		player_count,
		player_is_cpu,
		debug_manual_control_all
	)
	
	# === 診断ログ: カメラ初期位置確認 ===
	var camera = get_node_or_null("Camera3D")
	if camera:
		print("\n[game_3d] [診断] GameSystemManager.initialize_all() 直後:")
		print("  - カメラ位置: ", camera.position)
		print("  - カメラグローバル位置: ", camera.global_position)
		if system_manager.board_system_3d and system_manager.board_system_3d.camera:
			print("  - board_system_3d.camera と同じ参照か: ", camera == system_manager.board_system_3d.camera)
			print("  - board_system_3d.camera の位置: ", system_manager.board_system_3d.camera.position)
	
	# ゲーム開始待機
	await get_tree().create_timer(0.5).timeout
	
	# === 診断ログ: 0.5秒後のカメラ位置 ===
	if camera:
		print("\n[game_3d] [診断] 0.5秒待機後:")
		print("  - カメラ位置: ", camera.position)
	
	# ゲーム開始
	system_manager.start_game()

# デバッグ入力
func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				if system_manager:
					system_manager.game_flow_manager.roll_dice()
			KEY_V:
				# Vキーで表示切替
				if system_manager:
					var board_system_3d = system_manager.board_system_3d
					if board_system_3d and board_system_3d.tile_info_display:
						board_system_3d.tile_info_display.switch_mode()
						board_system_3d.update_all_tile_displays()
						var mode_name = board_system_3d.tile_info_display.get_current_mode_name()
						print("表示切替: ", mode_name)
						# UIに表示（オプション）
						if system_manager.ui_manager and system_manager.ui_manager.phase_label:
							var original_text = system_manager.ui_manager.phase_label.text
							system_manager.ui_manager.phase_label.text = "表示: " + mode_name
							await get_tree().create_timer(1.0).timeout
							system_manager.ui_manager.phase_label.text = original_text
			KEY_S:
				# Sキーでシグナル接続状態を表示（デバッグ）
				SignalRegistry.debug_print_connections()
				var stats = SignalRegistry.get_stats()
				print("総接続数: ", stats.get("total_connections", 0))
			KEY_6:
				if system_manager:
					system_manager.debug_controller.set_debug_dice(6)
			KEY_1:
				if system_manager:
					system_manager.debug_controller.set_debug_dice(1)
			KEY_2:
				if system_manager:
					system_manager.debug_controller.set_debug_dice(2)
			KEY_3:
				if system_manager:
					system_manager.debug_controller.set_debug_dice(3)
			KEY_4:
				if system_manager:
					system_manager.debug_controller.set_debug_dice(4)
			KEY_5:
				if system_manager:
					system_manager.debug_controller.set_debug_dice(5)
			KEY_0:
				if system_manager:
					system_manager.debug_controller.clear_debug_dice()
			KEY_D:
				if system_manager:
					system_manager.ui_manager.toggle_debug_mode()
