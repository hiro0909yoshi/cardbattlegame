extends Node
class_name DiscardHandler

# 手札調整ハンドラー
# ターン終了時の手札サイズ超過チェック・調整機能を担当

# 依存システム
var player_system = null
var card_system = null
var spell_phase_handler = null
var ui_manager = null

# CPU判定用
var player_is_cpu = []

## セットアップメソッド
func setup(p_player_system, p_card_system, p_spell_phase_handler, p_ui_manager, p_player_is_cpu: Array = []):
	player_system = p_player_system
	card_system = p_card_system
	spell_phase_handler = p_spell_phase_handler
	ui_manager = p_ui_manager
	player_is_cpu = p_player_is_cpu

## 手札調整処理（ターン終了時）
func check_and_discard_excess_cards(player_id: int = -1):
	# player_idが指定されていない場合は現在のプレイヤーを取得
	if player_id == -1:
		if not player_system:
			return
		var current_player = player_system.get_current_player()
		if not current_player:
			return
		player_id = current_player.id

	if not card_system or not player_system:
		return

	var hand_size = card_system.get_hand_size_for_player(player_id)

	if hand_size <= GameConstants.MAX_HAND_SIZE:
		return  # 調整不要

	var cards_to_discard = hand_size - GameConstants.MAX_HAND_SIZE
	print("手札調整が必要: ", hand_size, "枚 → 6枚（", cards_to_discard, "枚捨てる）")

	# CPUの場合はレートの低いカードから捨てる（デバッグモードでは無効化）
	var is_cpu = player_id < player_is_cpu.size() and player_is_cpu[player_id] and not DebugSettings.manual_control_all
	if is_cpu:
		if spell_phase_handler and spell_phase_handler.cpu_hand_utils:
			spell_phase_handler.cpu_hand_utils.discard_excess_cards_by_rate(player_id, GameConstants.MAX_HAND_SIZE)
		else:
			# フォールバック: 従来の方法
			card_system.discard_excess_cards_auto(player_id, GameConstants.MAX_HAND_SIZE)
		return

	# 人間プレイヤーの場合は手動で選択
	for i in range(cards_to_discard):
		await prompt_discard_card(player_id)

## カード捨て札をプロンプト
func prompt_discard_card(player_id: int = -1):
	# player_idが指定されていない場合は現在のプレイヤーを取得
	if player_id == -1:
		if not player_system:
			return
		player_id = player_system.get_current_player().id

	if not player_system or not card_system or not ui_manager:
		return

	var current_player = player_system.get_player_by_id(player_id) if player_system.has_method("get_player_by_id") else player_system.get_current_player()
	if not current_player:
		return

	# フィルターをリセット（グレーアウト解除）
	ui_manager.card_selection_filter = ""

	# カード選択UIを表示（discardモード）
	ui_manager.show_card_selection_ui_mode(current_player, "discard")

	# カード選択を待つ
	var card_index = await ui_manager.card_selected

	# カードを捨てる（理由: discard）
	card_system.discard_card(player_id, card_index, "discard")

	# UIを閉じる
	ui_manager.hide_card_selection_ui()

	# アクション指示を非表示
	if ui_manager.phase_display:
		ui_manager.hide_action_prompt()
