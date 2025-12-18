extends Node
class_name LapSystem

## 周回管理システム
## ゲーム内の周回状態、チェックポイント通過、周回完了ボーナスを管理
## 破壊カウンターも含む

const GameConstants = preload("res://scripts/game_constants.gd")

## シグナル
signal lap_completed(player_id: int)
signal checkpoint_signal_obtained(player_id: int, checkpoint_type: String)

## 周回状態
var player_lap_state: Dictionary = {}  # {player_id: {N: bool, S: bool, ..., lap_count: int}}

## 破壊カウンター
var destroy_count: int = 0

## 外部参照（初期化時に設定）
var player_system = null
var board_system_3d = null
var ui_manager = null

## マップ設定（動的に変更可能）
var base_bonus: int = 120  # 基礎ボーナス（デフォルト: standard）
var required_checkpoints: Array = ["N", "S"]  # 必要シグナル（デフォルト: standard）

## UI要素（シグナル表示用ラベルのみ）
var signal_display_label: Label = null

## 処理中フラグ（通知ポップアップ表示中等）
var is_showing_notification: bool = false

## 初期化
func setup(p_system, b_system, p_ui_manager = null):
	player_system = p_system
	board_system_3d = b_system
	ui_manager = p_ui_manager
	_setup_ui()

## UIのセットアップ
func _setup_ui():
	if not ui_manager:
		return
	
	# 既に作成済みならスキップ
	if signal_display_label != null:
		return
	
	# シグナル表示用ラベル（大きな文字で画面中央）
	signal_display_label = Label.new()
	signal_display_label.name = "SignalDisplayLabel"
	signal_display_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	signal_display_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	signal_display_label.add_theme_font_size_override("font_size", 120)
	signal_display_label.add_theme_color_override("font_color", Color.YELLOW)
	signal_display_label.add_theme_color_override("font_outline_color", Color.BLACK)
	signal_display_label.add_theme_constant_override("outline_size", 8)
	signal_display_label.set_anchors_preset(Control.PRESET_CENTER)
	signal_display_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	signal_display_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	signal_display_label.visible = false
	signal_display_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_manager.add_child(signal_display_label)

## シグナル/周回数を画面中央に大きく表示
func _show_signal_display(signal_type: String):
	if not signal_display_label:
		return
	
	signal_display_label.text = signal_type
	signal_display_label.visible = true
	signal_display_label.modulate.a = 1.0
	
	# フェードアウトアニメーション
	var tween = create_tween()
	tween.tween_interval(0.8)  # 0.8秒表示
	tween.tween_property(signal_display_label, "modulate:a", 0.0, 0.3)  # 0.3秒でフェードアウト
	tween.tween_callback(func(): signal_display_label.visible = false)

## コメントを表示してクリック待ち（GlobalCommentUIに委譲）
## player_id: 明示的にプレイヤーIDを指定（CPU判定に使用）
func _show_comment_and_wait(message: String, player_id: int = -1):
	print("[LapSystem] _show_comment_and_wait: ", message, " (player_id: %d)" % player_id)
	is_showing_notification = true
	if ui_manager and ui_manager.global_comment_ui:
		# show_and_wait()内でclick_confirmedをawaitするので、ここでawaitするだけでOK
		await ui_manager.global_comment_ui.show_and_wait(message, player_id)
	else:
		print("[LapSystem] WARNING: ui_manager or global_comment_ui is null")
	is_showing_notification = false

## 周回状態を初期化
func initialize_lap_state(player_count: int):
	player_lap_state.clear()
	destroy_count = 0
	
	for i in range(player_count):
		var state = {
			"lap_count": 1  # 周回数カウント（1周目からスタート）
		}
		# 必要シグナルのフラグを初期化
		for checkpoint in required_checkpoints:
			state[checkpoint] = false
		player_lap_state[i] = state

## マップ設定を適用
func apply_map_settings(map_data: Dictionary):
	var lap_settings = map_data.get("lap_settings", {})
	
	# 基礎ボーナス設定
	var bonus_preset = lap_settings.get("bonus_preset", "standard")
	if GameConstants.LAP_BONUS_PRESETS.has(bonus_preset):
		base_bonus = GameConstants.LAP_BONUS_PRESETS[bonus_preset]
	else:
		base_bonus = GameConstants.LAP_BONUS_PRESETS["standard"]
	
	# 必要シグナル設定
	var checkpoint_preset = lap_settings.get("checkpoint_preset", "standard")
	if GameConstants.CHECKPOINT_PRESETS.has(checkpoint_preset):
		required_checkpoints = GameConstants.CHECKPOINT_PRESETS[checkpoint_preset].duplicate()
	else:
		required_checkpoints = GameConstants.CHECKPOINT_PRESETS["standard"].duplicate()
	
	print("[LapSystem] マップ設定適用 - 基礎ボーナス: %d, 必要シグナル: %s" % [base_bonus, required_checkpoints])

## CheckpointTileのシグナルを接続
func connect_checkpoint_signals():
	if not board_system_3d or not board_system_3d.tile_nodes:
		return
	
	# 少し待ってからシグナル接続（CheckpointTileの_ready()を待つ）
	await get_tree().process_frame
	await get_tree().process_frame
	
	for tile_index in board_system_3d.tile_nodes.keys():
		var tile = board_system_3d.tile_nodes[tile_index]
		if tile and is_instance_valid(tile):
			if tile.has_signal("checkpoint_passed"):
				if not tile.checkpoint_passed.is_connected(_on_checkpoint_passed):
					tile.checkpoint_passed.connect(_on_checkpoint_passed)

## チェックポイント通過イベント
func _on_checkpoint_passed(player_id: int, checkpoint_type: String):
	if not player_lap_state.has(player_id):
		return
	
	# 必要なシグナルかチェック
	if not checkpoint_type in required_checkpoints:
		print("[LapSystem] 不明なシグナル: %s (必要: %s)" % [checkpoint_type, required_checkpoints])
		return
	
	# 既に取得済みならスキップ
	if player_lap_state[player_id].get(checkpoint_type, false):
		print("[LapSystem] プレイヤー%d: シグナル %s は既に取得済み" % [player_id + 1, checkpoint_type])
		return
	
	# シグナル取得 - 基礎ボーナス付与
	player_lap_state[player_id][checkpoint_type] = true
	if player_system:
		player_system.add_magic(player_id, base_bonus)
		print("[シグナル取得] プレイヤー%d: %s 魔力+%d" % [player_id + 1, checkpoint_type, base_bonus])
	
	# シグナル発行
	checkpoint_signal_obtained.emit(player_id, checkpoint_type)
	
	# 全シグナル揃ったか確認（周回完了時はそちらでまとめて表示）
	if _check_lap_complete(player_id):
		# 勝利判定（周回完了前に確認）
		if _check_win_condition(player_id):
			return  # 勝利処理で終了
		await complete_lap(player_id)
		return
	
	# 周回完了でない場合のみシグナル取得コメントを表示
	# UI表示: シグナルを画面中央に大きく表示
	_show_signal_display(checkpoint_type)
	
	# UI表示: 魔力ボーナスのコメント（クリック待ち）
	await _show_comment_and_wait("[color=yellow]シグナル %s 取得！[/color]\n魔力 +%d G" % [checkpoint_type, base_bonus], player_id)
	
	# 勝利判定（シグナル取得時に魔力が目標以上なら勝利）
	if _check_win_condition(player_id):
		return  # 勝利処理で終了

## 周回完了判定（全シグナルが揃っているか）
func _check_lap_complete(player_id: int) -> bool:
	for checkpoint in required_checkpoints:
		if not player_lap_state[player_id].get(checkpoint, false):
			return false
	return true

## 追加ボーナスを計算
## 追加ボーナス = 基礎ボーナス × (クリーチャー数×0.4 + (周回数-1)×0.4)
func _calculate_additional_bonus(player_id: int, lap_count: int) -> int:
	# 配置クリーチャー数を取得
	var creature_count = _get_player_creature_count(player_id)
	
	# 係数を計算
	var creature_rate = creature_count * GameConstants.LAP_BONUS_CREATURE_RATE
	var lap_rate = (lap_count - 1) * GameConstants.LAP_BONUS_LAP_RATE
	var total_rate = creature_rate + lap_rate
	
	# 追加ボーナスを計算（切り捨て）
	var bonus = int(base_bonus * total_rate)
	
	print("[周回ボーナス計算] クリーチャー%d体(×%.1f=%.1f) + 周回%d(×%.1f=%.1f) = 係数%.1f → %dG" % [
		creature_count, GameConstants.LAP_BONUS_CREATURE_RATE, creature_rate,
		lap_count - 1, GameConstants.LAP_BONUS_LAP_RATE, lap_rate,
		total_rate, bonus
	])
	
	return bonus

## プレイヤーの配置クリーチャー数を取得
func _get_player_creature_count(player_id: int) -> int:
	if not board_system_3d:
		return 0
	
	var count = 0
	var tiles = board_system_3d.get_player_tiles(player_id)
	for tile in tiles:
		if tile.creature_data and not tile.creature_data.is_empty():
			count += 1
	
	return count

## 勝利判定（チェックポイント通過時）
func _check_win_condition(player_id: int) -> bool:
	if not player_system:
		return false
	
	var player = player_system.players[player_id]
	var total_assets = calculate_total_assets(player_id)
	var target_magic = player.target_magic
	
	if total_assets >= target_magic:
		print("🎉 プレイヤー%d 勝利条件達成！ 総魔力: %d / %d 🎉" % [player_id + 1, total_assets, target_magic])
		player_system.emit_signal("player_won", player_id)
		return true
	
	return false

## 総魔力を計算（PlayerSystemに委譲）
func calculate_total_assets(player_id: int) -> int:
	if not player_system:
		return 0
	return player_system.calculate_total_assets(player_id)

## 周回完了処理
func complete_lap(player_id: int):
	# 現在の周回数を取得（ボーナス計算用）
	var current_lap = player_lap_state[player_id]["lap_count"]
	
	# UI表示: 周回数を画面中央に大きく表示
	_show_signal_display("%d周" % current_lap)
	
	# 周回数をインクリメント
	player_lap_state[player_id]["lap_count"] += 1
	print("[周回完了] プレイヤー%d 周回数: %d → %d" % [player_id + 1, current_lap, player_lap_state[player_id]["lap_count"]])
	
	# フラグをリセット
	for checkpoint in required_checkpoints:
		player_lap_state[player_id][checkpoint] = false
	
	# ボーナス計算
	# 追加ボーナス = 基礎ボーナス × (クリーチャー数×0.4 + (周回数-1)×0.4)
	var additional_bonus = _calculate_additional_bonus(player_id, current_lap)
	# 周回完了時のボーナス合計 = 基礎ボーナス + 追加ボーナス
	var lap_total_bonus = base_bonus + additional_bonus
	
	# 追加ボーナスを付与（基礎ボーナスはシグナル入手時に付与済み）
	if player_system and additional_bonus > 0:
		player_system.add_magic(player_id, additional_bonus)
		print("[周回完了] プレイヤー%d 追加ボーナス+%d" % [player_id + 1, additional_bonus])
	
	# ダウン解除
	if board_system_3d and board_system_3d.movement_controller:
		board_system_3d.movement_controller.clear_all_down_states_for_player(player_id)
		print("[周回完了] プレイヤー%d ダウン解除" % [player_id + 1])
	
	# HP回復+10
	if board_system_3d and board_system_3d.movement_controller:
		board_system_3d.movement_controller.heal_all_creatures_for_player(player_id, 10)
		print("[周回完了] プレイヤー%d HP回復+10" % [player_id + 1])
	
	# UI表示: 4段階の通知ポップアップ
	# 1. O周完了
	await _show_comment_and_wait("[color=yellow]%d周完了[/color]" % current_lap, player_id)
	
	# 2. 周回ボーナス（基礎＋追加）
	var bonus_text = "[color=cyan]周回ボーナス %d G[/color]\n（基礎 %d G + 追加 %d G）" % [lap_total_bonus, base_bonus, additional_bonus]
	await _show_comment_and_wait(bonus_text, player_id)
	
	# 3. ダウン解除
	await _show_comment_and_wait("[color=lime]ダウン解除[/color]", player_id)
	
	# 4. HP回復
	await _show_comment_and_wait("[color=lime]HP回復 +10[/color]", player_id)
	
	# 全クリーチャーに周回ボーナスを適用
	if board_system_3d:
		_apply_lap_bonus_to_all_creatures(player_id)
	
	# シグナル発行
	lap_completed.emit(player_id)

## 全クリーチャーに周回ボーナスを適用
func _apply_lap_bonus_to_all_creatures(player_id: int):
	var tiles = board_system_3d.get_player_tiles(player_id)
	
	for tile in tiles:
		if tile.creature_data:
			_apply_lap_bonus_to_creature(tile.creature_data)

## クリーチャーに周回ボーナスを適用
func _apply_lap_bonus_to_creature(creature_data: Dictionary):
	if not creature_data.has("ability_parsed"):
		return
	
	var effects = creature_data.get("ability_parsed", {}).get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "per_lap_permanent_bonus":
			_apply_per_lap_bonus(creature_data, effect)

## 周回ごと永続ボーナスを適用
func _apply_per_lap_bonus(creature_data: Dictionary, effect: Dictionary):
	var stat = effect.get("stat", "ap")
	var value = effect.get("value", 10)
	
	# 周回カウントを増加
	if not creature_data.has("map_lap_count"):
		creature_data["map_lap_count"] = 0
	creature_data["map_lap_count"] += 1
	
	# base_up_hp/ap に加算
	if stat == "ap":
		if not creature_data.has("base_up_ap"):
			creature_data["base_up_ap"] = 0
		creature_data["base_up_ap"] += value
		print("[Lap Bonus] ", creature_data.get("name", ""), " ST+", value, 
			  " (周回", creature_data["map_lap_count"], "回目)")
	
	elif stat == "max_hp":
		if not creature_data.has("base_up_hp"):
			creature_data["base_up_hp"] = 0
		
		# リセット条件チェック（モスタイタン用）
		var reset_condition = effect.get("reset_condition")
		if reset_condition:
			var reset_max_hp = creature_data.get("hp", 0) + creature_data.get("base_up_hp", 0)
			var check = reset_condition.get("max_hp_check", {})
			var operator = check.get("operator", ">=")
			var threshold = check.get("value", 80)
			
			# MHP + 新しいボーナスがしきい値を超えるかチェック
			if operator == ">=" and (reset_max_hp + value) >= threshold:
				var reset_to = check.get("reset_to", 0)
				var reset_base_hp = creature_data.get("hp", 0)
				creature_data["base_up_hp"] = reset_to - reset_base_hp
				creature_data["current_hp"] = reset_to
				
				print("[Lap Bonus] ", creature_data.get("name", ""), 
					  " MHPリセット → ", reset_to, " HP:", reset_to)
				return
		
		creature_data["base_up_hp"] += value
		
		# 現在HPも回復
		var base_hp = creature_data.get("hp", 0)
		var base_up_hp = creature_data["base_up_hp"]
		var max_hp = base_hp + base_up_hp
		var current_hp = creature_data.get("current_hp", max_hp)
		var new_hp = min(current_hp + value, max_hp)
		creature_data["current_hp"] = new_hp
		
		print("[Lap Bonus] ", creature_data.get("name", ""), 
			  " MHP+", value, " HP+", value,
			  " (周回", creature_data["map_lap_count"], "回目)",
			  " HP:", current_hp, "→", new_hp, " / MHP:", max_hp)

# ========================================
# 破壊カウンター管理
# ========================================

## クリーチャー破壊時に呼ばれる
func on_creature_destroyed():
	destroy_count += 1
	print("[破壊カウント] 累計: ", destroy_count)

## 破壊カウント取得
func get_destroy_count() -> int:
	return destroy_count

## 破壊カウントリセット（スペル用）
func reset_destroy_count():
	destroy_count = 0
	print("[破壊カウント] リセットしました")

## 周回数取得
func get_lap_count(player_id: int) -> int:
	if player_lap_state.has(player_id):
		return player_lap_state[player_id].get("lap_count", 0)
	return 0

## チェックポイントフラグを設定（外部から呼び出し用）
func set_checkpoint_flag(player_id: int, checkpoint_type: String):
	if player_lap_state.has(player_id):
		player_lap_state[player_id][checkpoint_type] = true
