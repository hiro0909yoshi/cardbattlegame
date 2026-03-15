extends Node
class_name LapSystem

## 周回管理システム
## ゲーム内の周回状態、チェックポイント通過、周回完了ボーナスを管理
## 破壊カウンターも含む


## シグナル
signal lap_completed(player_id: int)
signal checkpoint_signal_obtained(player_id: int, checkpoint_type: String)
signal checkpoint_processing_completed()  # チェックポイント処理完了（移動待機用）

## 周回状態
var player_lap_state: Dictionary = {}  # {player_id: {N: bool, S: bool, ..., lap_count: int}}

## 破壊カウンター
var destroy_count: int = 0

## 外部参照（初期化時に設定）
var player_system = null
var board_system_3d = null
var team_system = null  # Phase 4: チーム合算TEP用
var _ui_layer = null  # Phase B-2: ui_manager 依存解消、ui_layer 直接参照
var _message_service = null  # サービス注入用
var _show_dominio_order_button_cb: Callable = Callable()  # Phase B-2: ドミニオボタン表示 Callable
var is_game_ended_checker: Callable = func() -> bool: return false
var game_3d_ref = null  # game_3d直接参照（get_parent()チェーン廃止用）

## マップ設定（動的に変更可能）
var base_bonus: int = 120  # 周回ボーナス（デフォルト: standard）
var checkpoint_bonus: int = 100  # チェックポイント通過ボーナス（デフォルト: standard）
var required_checkpoints: Array = ["N", "S"]  # 必要シグナル（デフォルト: standard）

## UI要素（シグナル表示用ラベルのみ）
var signal_display_label: Label = null

## 処理中フラグ（通知ポップアップ表示中等）
var is_showing_notification: bool = false

## 初期化
func setup(p_system, b_system, p_ui_manager = null, _p_game_flow_manager = null, p_game_3d_ref = null):
	player_system = p_system
	board_system_3d = b_system
	game_3d_ref = p_game_3d_ref
	# サービス注入
	if p_ui_manager and p_ui_manager.has_meta("message_service"):
		_message_service = p_ui_manager.get_meta("message_service")
	elif p_ui_manager and "message_service" in p_ui_manager:
		_message_service = p_ui_manager.message_service
	# ui_layer 直接参照（Phase B-2: ui_manager 依存解消）
	if p_ui_manager and "ui_layer" in p_ui_manager:
		_ui_layer = p_ui_manager.ui_layer
	setup_ui()

## is_game_ended チェック用の Callable を設定
func set_game_ended_checker(checker: Callable) -> void:
	is_game_ended_checker = checker

## ドミニオコマンドボタン表示用の Callable を設定（Phase B-2）
func set_show_dominio_order_button_cb(cb: Callable) -> void:
	_show_dominio_order_button_cb = cb

## game_3d参照を設定（チュートリアルモード判定用）
func set_game_3d_ref(p_game_3d) -> void:
	game_3d_ref = p_game_3d

## UIのセットアップ
func setup_ui():
	if not _ui_layer:
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
	# UIツリー操作は _ui_layer 経由（Phase B-2）
	if _ui_layer:
		_ui_layer.add_child(signal_display_label)

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

## コメントを表示してクリック待ち（MessageServiceに委譲）
## player_id: 明示的にプレイヤーIDを指定（CPU判定に使用）
func _show_comment_and_wait(message: String, player_id: int = -1):
	is_showing_notification = true
	if _message_service:
		await _message_service.show_comment_and_wait(message, player_id, true)
	else:
		print("[LapSystem] WARNING: _message_service is null")
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
	# 新形式: lap_bonus_preset / checkpoint_preset
	# 旧形式: lap_settings.bonus_preset / lap_settings.checkpoint_preset
	var lap_bonus_preset: String
	var checkpoint_preset: String
	
	if map_data.has("lap_bonus_preset"):
		# 新形式
		lap_bonus_preset = map_data.get("lap_bonus_preset", "standard")
		checkpoint_preset = map_data.get("checkpoint_preset", "standard")
	else:
		# 旧形式（後方互換）
		var lap_settings = map_data.get("lap_settings", {})
		lap_bonus_preset = lap_settings.get("bonus_preset", "standard")
		checkpoint_preset = lap_settings.get("checkpoint_preset", "standard")
	
	# プリセットからボーナス値を取得
	base_bonus = GameConstants.get_lap_bonus(lap_bonus_preset)
	checkpoint_bonus = GameConstants.get_checkpoint_bonus(lap_bonus_preset)
	
	# 必要シグナルを取得
	required_checkpoints = GameConstants.get_required_checkpoints(checkpoint_preset)
	
	# プレイヤー状態を新しいシグナル設定で再初期化
	_reinitialize_player_states()
	
	print("[LapSystem] マップ設定適用 - 周回ボーナス: %d, CP通過ボーナス: %d, 必要シグナル: %s" % [base_bonus, checkpoint_bonus, required_checkpoints])

## プレイヤー状態を現在のrequired_checkpointsで再初期化
func _reinitialize_player_states():
	for player_id in player_lap_state.keys():
		var lap_count = player_lap_state[player_id].get("lap_count", 1)
		var state = {
			"lap_count": lap_count
		}
		for checkpoint in required_checkpoints:
			state[checkpoint] = false
		player_lap_state[player_id] = state

## スタート地点通過（シグナルリレー受信のみ）
## 注意: チェックポイント状態のリセットは complete_lap() で既に実施済み
## ここでリセットすると、周回完了後のチェックポイント状態が失われ、
## CPU の方向選択ロジックが誤動作する原因となる
func on_start_passed(_player_id: int):
	# デバッグログのみ
	pass

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
	# ゲーム終了判定
	if is_game_ended_checker.call():
		print("[LapSystem] ゲーム終了済み、チェックポイント処理スキップ")
		checkpoint_processing_completed.emit()
		return
	
	if not player_lap_state.has(player_id):
		return
	
	# 必要なシグナルかチェック
	if not checkpoint_type in required_checkpoints:
		print("[LapSystem] 不明なシグナル: %s (必要: %s)" % [checkpoint_type, required_checkpoints])
		await get_tree().process_frame
		checkpoint_processing_completed.emit()
		return
	
	# 既に取得済みでも勝敗判定は行う
	if player_lap_state[player_id].get(checkpoint_type, false):
		print("[LapSystem] プレイヤー%d: シグナル %s は既に取得済み" % [player_id + 1, checkpoint_type])
		# 勝敗判定（チェックポイント到達時は常に判定）
		if not _is_tutorial_mode():
			if _check_win_condition(player_id):
				await get_tree().process_frame
				checkpoint_processing_completed.emit()
				return
		# 呼び出し元のawaitが先にセットアップされるよう1フレーム待ってからemit
		await get_tree().process_frame
		checkpoint_processing_completed.emit()
		return
	
	# シグナル取得 - チェックポイント通過ボーナス付与
	player_lap_state[player_id][checkpoint_type] = true
	if player_system:
		player_system.add_magic(player_id, checkpoint_bonus)
		print("[シグナル取得] プレイヤー%d: %s EP+%d" % [player_id + 1, checkpoint_type, checkpoint_bonus])
	
	# シグナル発行
	checkpoint_signal_obtained.emit(player_id, checkpoint_type)
	
	# 全シグナル揃ったか確認（周回完了時はそちらでまとめて表示）
	if check_lap_complete(player_id):
		# 周回ボーナスを先に付与してから勝利判定
		await complete_lap(player_id)
		# チュートリアルモードでは勝利判定をスキップ（lap_completedで終了処理）
		if not _is_tutorial_mode():
			_check_win_condition(player_id)
		checkpoint_processing_completed.emit()
		return
	
	# 周回完了でない場合のみシグナル取得コメントを表示
	# UI表示: シグナルを画面中央に大きく表示
	_show_signal_display(checkpoint_type)
	
	# UI表示: EPボーナスのコメント（クリック待ち）
	await _show_comment_and_wait("[color=yellow]シグナル %s 取得！[/color]\nEP +%d" % [checkpoint_type, checkpoint_bonus], player_id)
	
	# 勝利判定（シグナル取得時にEPが目標以上なら勝利）
	# チュートリアルモードではスキップ
	if not _is_tutorial_mode():
		if _check_win_condition(player_id):
			checkpoint_processing_completed.emit()
			return  # 勝利処理で終了
	
	# 処理完了を通知
	checkpoint_processing_completed.emit()

## 周回完了判定（全シグナルが揃っているか）
func check_lap_complete(player_id: int) -> bool:
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
	
	print("[周回ボーナス計算] クリーチャー%d体(×%.1f=%.1f) + 周回%d(×%.1f=%.1f) = 係数%.1f → %dEP" % [
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

## チュートリアルモード判定
func _is_tutorial_mode() -> bool:
	if not game_3d_ref:
		return false
	if "is_tutorial_mode" in game_3d_ref:
		return game_3d_ref.is_tutorial_mode
	return false


## 勝利判定（チェックポイント通過時）
func _check_win_condition(player_id: int) -> bool:
	if not player_system:
		return false
	
	var player = player_system.players[player_id]
	var total_assets = calculate_total_assets(player_id)
	var target_magic = player.target_magic
	
	if total_assets >= target_magic:
		print("🎉 プレイヤー%d 勝利条件達成！ TEP: %d / %d 🎉" % [player_id + 1, total_assets, target_magic])
		player_system.emit_signal("player_won", player_id)
		return true
	
	return false

## TEPを計算（チーム合算TEPに変更）
func calculate_total_assets(player_id: int) -> int:
	if team_system and team_system.has_teams():
		return team_system.get_team_total_assets(player_id)
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
	if board_system_3d:
		board_system_3d.clear_all_down_states_for_player(player_id)
		print("[周回完了] プレイヤー%d ダウン解除" % [player_id + 1])
		# ダウン解除によりドミニオコマンドが使用可能になった場合、ボタンを表示（Phase B-2: Callable駆動化）
		if _show_dominio_order_button_cb.is_valid():
			_show_dominio_order_button_cb.call()
	
	# HP回復+10
	if board_system_3d:
		board_system_3d.heal_all_creatures_for_player(player_id, 10)
		print("[周回完了] プレイヤー%d HP回復+10" % [player_id + 1])
	
	# UI表示: 3段階の通知ポップアップ
	# 1. O周完了
	await _show_comment_and_wait("[color=yellow]%d周完了[/color]" % current_lap, player_id)
	
	# 2. 周回ボーナス（基礎＋追加）
	var bonus_text = "[color=cyan]周回ボーナス %d EP[/color]\n（基礎 %d EP + 追加 %d EP）" % [lap_total_bonus, base_bonus, additional_bonus]
	await _show_comment_and_wait(bonus_text, player_id)
	
	# 3. ダウン解除＋HP回復
	await _show_comment_and_wait("[color=lime]ダウン解除 ＋ HP回復 +10[/color]", player_id)
	
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

## 訪問済みチェックポイント数を取得
func get_visited_checkpoint_count(player_id: int) -> int:
	if not player_lap_state.has(player_id):
		return 0
	
	var count = 0
	for checkpoint in required_checkpoints:
		if player_lap_state[player_id].get(checkpoint, false):
			count += 1
	return count

## 必要チェックポイント数を取得
func get_required_checkpoint_count() -> int:
	return required_checkpoints.size()

## 周回完了判定（全チェックポイント訪問済み）
func is_lap_complete(player_id: int) -> bool:
	return check_lap_complete(player_id)
