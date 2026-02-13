extends RefCounted
class_name UIWinScreen

# 勝利・敗北演出画面
# UIManagerから委譲される

var ui_manager: UIManager = null


func _init(p_ui_manager: UIManager) -> void:
	ui_manager = p_ui_manager


## 勝利画面を表示
func show_win_screen(player_id: int):
	if not ui_manager.ui_layer:
		return

	ui_manager.set_phase_text("")

	var win_panel = Panel.new()
	win_panel.name = "WinScreen"
	win_panel.set_anchors_preset(Control.PRESET_FULL_RECT)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	win_panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	win_panel.add_child(vbox)

	var win_label = Label.new()
	win_label.text = "WIN"
	win_label.add_theme_font_size_override("font_size", 200)
	win_label.add_theme_color_override("font_color", Color.GOLD)
	win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(win_label)

	var player_name = "プレイヤー%d" % (player_id + 1)
	if ui_manager.player_system_ref and player_id < ui_manager.player_system_ref.players.size():
		player_name = ui_manager.player_system_ref.players[player_id].name

	var player_label = Label.new()
	player_label.text = player_name + " の勝利！"
	player_label.add_theme_font_size_override("font_size", 48)
	player_label.add_theme_color_override("font_color", Color.WHITE)
	player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(player_label)

	vbox.position = Vector2(-200, -150)
	vbox.custom_minimum_size = Vector2(400, 300)

	ui_manager.ui_layer.add_child(win_panel)

	win_panel.modulate.a = 0
	win_label.scale = Vector2(0.5, 0.5)
	win_label.pivot_offset = win_label.size / 2

	var tween = ui_manager.create_tween()
	tween.set_parallel(true)
	tween.tween_property(win_panel, "modulate:a", 1.0, 0.5)
	tween.tween_property(win_label, "scale", Vector2(1.0, 1.0), 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	print("[UIManager] 勝利画面表示: プレイヤー", player_id + 1)


## 勝利画面を表示（非同期版 - クリック待ち）
func show_win_screen_async(player_id: int):
	show_win_screen(player_id)

	await _wait_for_click()

	var win_screen = ui_manager.ui_layer.get_node_or_null("WinScreen")
	if win_screen:
		win_screen.queue_free()


## 敗北画面を表示（非同期版 - クリック待ち）
func show_lose_screen_async(player_id: int):
	if not ui_manager.ui_layer:
		return

	ui_manager.set_phase_text("")

	var lose_panel = Panel.new()
	lose_panel.name = "LoseScreen"
	lose_panel.set_anchors_preset(Control.PRESET_FULL_RECT)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	lose_panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	lose_panel.add_child(vbox)

	var lose_label = Label.new()
	lose_label.text = "LOSE..."
	lose_label.add_theme_font_size_override("font_size", 150)
	lose_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	lose_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lose_label)

	vbox.position = Vector2(-200, -100)
	vbox.custom_minimum_size = Vector2(400, 200)

	ui_manager.ui_layer.add_child(lose_panel)

	lose_panel.modulate.a = 0

	var tween = ui_manager.create_tween()
	tween.tween_property(lose_panel, "modulate:a", 1.0, 0.5)

	print("[UIManager] 敗北画面表示: プレイヤー", player_id + 1)

	await _wait_for_click()

	lose_panel.queue_free()


## クリック待ち
func _wait_for_click():
	print("[UIManager] クリック待ち開始")
	await ui_manager.get_tree().create_timer(2.0).timeout
	print("[UIManager] クリック待ち完了")
