extends RefCounted
class_name GameResultHandler

## ゲーム結果処理クラス
## 勝敗判定、リザルト画面表示、シーン遷移を管理

# システム参照
var game_flow_manager  # GameFlowManager
var player_system: PlayerSystem
var ui_manager: UIManager

# リザルト画面への参照
var result_screen: ResultScreen = null

# 現在のステージデータ（クエストモード用）
var current_stage_data: Dictionary = {}

# ゲーム終了フラグ（勝敗判定の重複防止）
var _game_ended: bool = false


## 初期化
func initialize(gfm, p_system: PlayerSystem, ui: UIManager) -> void:
	game_flow_manager = gfm
	player_system = p_system
	ui_manager = ui


## ゲーム終了済みかどうか
func is_game_ended() -> bool:
	return _game_ended


## ステージデータを設定（QuestGameから呼ばれる）
func set_stage_data(stage_data: Dictionary):
	current_stage_data = stage_data
	print("[GameResultHandler] ステージデータ設定: %s" % stage_data.get("id", "unknown"))


## リザルト画面を設定
func set_result_screen(screen: ResultScreen):
	result_screen = screen
	if result_screen:
		result_screen.result_confirmed.connect(_on_result_confirmed)


## プレイヤー勝利処理
func on_player_won(player_id: int):
	# 重複防止
	if _game_ended:
		print("[GameResultHandler] ゲームは既に終了しています")
		return
	_game_ended = true

	var _player = player_system.players[player_id]  # 将来の拡張用
	game_flow_manager.change_phase(game_flow_manager.GamePhase.SETUP)

	print("🎉 プレイヤー", player_id + 1, "の勝利！ 🎉")

	# プレイヤー0（人間）が勝利した場合のみリザルト処理
	# call_deferredで次フレームに実行（シグナル経由のawait問題回避）
	if player_id == 0:
		_start_victory_result.call_deferred()
	else:
		# CPU勝利 = プレイヤー敗北
		_start_defeat_result.call_deferred("cpu_win")


## プレイヤー敗北処理（降参・ターン制限）
func on_player_defeated(reason: String = ""):
	# 重複防止
	if _game_ended:
		print("[GameResultHandler] ゲームは既に終了しています")
		return
	_game_ended = true

	game_flow_manager.change_phase(game_flow_manager.GamePhase.SETUP)
	print("😢 プレイヤー敗北... (理由: %s)" % reason)
	await _process_defeat_result(reason)


## 規定ターン終了判定
func check_turn_limit() -> bool:
	var max_turns = current_stage_data.get("max_turns", 0)
	if max_turns <= 0:
		return false  # 制限なし

	var current_turn = game_flow_manager.current_turn_number
	if current_turn > max_turns:
		print("[GameResultHandler] 規定ターン(%d)終了" % max_turns)

		# TEP比較で勝敗判定
		var player_tep = player_system.calculate_total_assets(0)
		var highest_cpu_tep = 0

		for i in range(1, player_system.players.size()):
			var cpu_tep = player_system.calculate_total_assets(i)
			if cpu_tep > highest_cpu_tep:
				highest_cpu_tep = cpu_tep

		print("[GameResultHandler] プレイヤーTEP: %d, 最高CPU TEP: %d" % [player_tep, highest_cpu_tep])

		if player_tep > highest_cpu_tep:
			# プレイヤー勝利
			on_player_won(0)
		else:
			# プレイヤー敗北（同値も敗北）
			on_player_defeated("turn_limit")

		return true

	return false


# === 内部処理 ===

## 勝利リザルト開始（call_deferred用ラッパー）
func _start_victory_result():
	_process_victory_result()


## 敗北リザルト開始（call_deferred用ラッパー）
func _start_defeat_result(reason: String = ""):
	_process_defeat_result(reason)


## 勝利時のリザルト処理
func _process_victory_result():
	var stage_id = current_stage_data.get("id", "")

	# クエストモードでない場合は簡易表示
	if stage_id.is_empty():
		if ui_manager:
			ui_manager.show_win_screen(0)
		return

	# ランク計算
	var rank = RankCalculator.calculate_rank(game_flow_manager.current_turn_number)

	# 初回クリア判定
	var is_first_clear = StageRecordManager.is_first_clear(stage_id)

	# 報酬計算
	var rewards = RewardCalculator.calculate_rewards(current_stage_data, rank, is_first_clear)
	print("[GameResultHandler] 報酬計算結果: %s" % rewards)

	# 記録更新
	var record_result = StageRecordManager.update_record(stage_id, rank, game_flow_manager.current_turn_number)

	# ゴールド付与
	if rewards.total > 0:
		GameData.add_gold(rewards.total)
		print("[GameResultHandler] ゴールド付与: %d" % rewards.total)
	else:
		print("[GameResultHandler] 報酬なし（total: %d）" % rewards.total)

	# リザルト画面表示
	print("[GameResultHandler] リザルト画面: %s" % ("あり" if result_screen else "なし"))

	if result_screen:
		var result_data = {
			"stage_id": stage_id,
			"stage_name": current_stage_data.get("name", ""),
			"turn_count": game_flow_manager.current_turn_number,
			"rank": rank,
			"is_first_clear": is_first_clear,
			"is_best_updated": record_result.is_best_updated,
			"best_rank": record_result.best_rank,
			"best_turn": record_result.best_turn,
			"rewards": rewards
		}

		# 勝利演出
		if ui_manager:
			await ui_manager.show_win_screen_async(0)

		print("[GameResultHandler] リザルト画面表示開始")
		result_screen.show_victory(result_data)
	else:
		# リザルト画面がない場合は従来の勝利演出のみ
		print("[GameResultHandler] リザルト画面なし、勝利演出のみ")
		if ui_manager:
			ui_manager.show_win_screen(0)

		# 一定時間後にステージセレクトへ
		await game_flow_manager.get_tree().create_timer(3.0).timeout
		_return_to_stage_select()


## 敗北時のリザルト処理
func _process_defeat_result(reason: String):
	var stage_id = current_stage_data.get("id", "")

	# 報酬計算（敗北は0G）
	var rewards = RewardCalculator.calculate_defeat_rewards()

	# リザルト画面表示
	if result_screen:
		var result_data = {
			"stage_id": stage_id,
			"stage_name": current_stage_data.get("name", ""),
			"turn_count": game_flow_manager.current_turn_number,
			"defeat_reason": reason,
			"rewards": rewards
		}

		# 敗北演出
		if ui_manager:
			await ui_manager.show_lose_screen_async(0)

		result_screen.show_defeat(result_data)
	else:
		# リザルト画面がない場合
		print("[GameResultHandler] リザルト画面なし、タイトルへ戻る")
		_return_to_stage_select()


## リザルト確認後
func _on_result_confirmed():
	print("[GameResultHandler] リザルト確認完了、ステージセレクトへ")
	_return_to_stage_select()


## ステージセレクトへ戻る
func _return_to_stage_select():
	print("[GameResultHandler] _return_to_stage_select 開始")

	# チュートリアルはメインメニューへ
	var stage_id = current_stage_data.get("id", "")
	if stage_id == "stage_tutorial":
		print("[GameResultHandler] チュートリアル終了、メインメニューへ遷移")
		game_flow_manager.get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	# クエストモードならクエストセレクトへ
	elif not current_stage_data.is_empty():
		print("[GameResultHandler] クエストセレクトへ遷移")
		game_flow_manager.get_tree().change_scene_to_file("res://scenes/WorldStageSelect.tscn")
	else:
		# それ以外はメインメニューへ
		print("[GameResultHandler] メインメニューへ遷移")
		game_flow_manager.get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
