# SpellPhaseHandler - スペルフェーズの処理を担当
extends Node
class_name SpellPhaseHandler

## シグナル
@warning_ignore("unused_signal")  # GameFlowManager で await されている（game_flow_manager.gd:276）
signal spell_phase_completed()
@warning_ignore("unused_signal")  # SpellFlowHandler で emit されている（spell_flow_handler.gd:540）
signal spell_passed()
@warning_ignore("unused_signal")  # spell_effect_executorでemitされる（将来の拡張用）
signal spell_used(spell_card: Dictionary)
@warning_ignore("unused_signal")  # SpellFlowHandler で emit されている（spell_flow_handler.gd:259）
signal target_selection_required(spell_card: Dictionary, target_type: String)
@warning_ignore("unused_signal")  # SpellTargetSelectionHandler で emit されている（spell_target_selection_handler.gd:271,303）
signal target_confirmed(target_data: Dictionary)  # ターゲット選択完了時
@warning_ignore("unused_signal")  # SpellUIManager で listen される
signal human_spell_phase_started(player_id: int, hand_data: Array, magic_power: int)

## 参照
## （状態変数は SpellStateHandler に移行済み - Phase 3-A Day 9）

## デバッグ設定
## 密命カードのテストを一時的に無効化
## true: 密命カードを通常カードとして扱う（失敗判定・復帰[ブック]をスキップ）
## false: 通常通り密命として動作
## 使い方: GameFlowManagerのセットアップ後に設定
##   DebugSettings.disable_secret_cards = true
# NOTE: debug_disable_secret_cardsはDebugSettings.disable_secret_cardsに移行済み

## カード犠牲・土地条件のデバッグフラグはTileActionProcessorで一元管理
## 参照: board_system.tile_action_processor.debug_disable_card_sacrifice
## 参照: board_system.tile_action_processor.debug_disable_lands_required

## カード選択ハンドラー（敵手札選択、デッキカード選択）
var card_selection_handler: CardSelectionHandler = null

## 外部スペル実行完了シグナル
@warning_ignore("unused_signal")  # SpellFlowHandler で await/emit されている（spell_flow_handler.gd:569,633, spell_effect_executor.gd:231）
signal external_spell_finished()  # 外部スペル実行完了

## 参照
var game_flow_manager = null
var game_3d_ref = null  # game_3d直接参照（get_parent()チェーン廃止用）
var card_system = null
var player_system = null
var board_system = null
var creature_manager = null
var spell_mystic_arts = null  # アルカナアーツシステム
var spell_cast_notification_ui = null  # 発動通知UI

## === Phase 3-A Day 18: SpellSubsystemContainer 導入 ===
## 11個のSpell**** クラスと関連参照を集約するコンテナ
## （削減対象: 11個の個別参照）
var spell_systems: SpellSubsystemContainer = null

## 効果実行（分離クラス）
var spell_effect_executor: SpellEffectExecutor = null

# === 直接参照（GFM経由を廃止） ===
var game_stats  # GameFlowManager.game_stats への直接参照

# === 直接参照（GFM経由を廃止） ===
var battle_status_overlay = null  # BattleStatusOverlay: バトルステータス表示
var target_selection_helper = null  # TargetSelectionHelper: ターゲット選択

var cpu_spell_phase_handler = null  # CPUスペルフェーズ処理
var spell_target_selection_handler = null  # SpellTargetSelectionHandler - 対象選択ハンドラー（Phase 6-1、循環参照回避のため型アノテーションなし）
var mystic_arts_handler = null  # MysticArtsHandler - アルカナアーツ処理（Phase 8-1、循環参照回避のため型アノテーションなし）

## === Phase 5-1: SpellUIManager 統合 ===
var spell_ui_manager = null  # SpellUIManager - UI管理システム（Phase 5-1、循環参照回避のため型アノテーションなし）

## ===== ハンドラー参照（Phase 3-A Day 9-12） =====
var spell_state: SpellStateHandler = null          # 状態管理（Day 9）
var spell_flow: SpellFlowHandler = null            # フロー制御（Day 10-11）


func _ready():
	pass

func _process(delta):
	# 選択マーカーを回転
	TargetSelectionHelper.rotate_selection_marker(self, delta)
	# 確認フェーズ用マーカーを回転
	TargetSelectionHelper.rotate_confirmation_markers(self, delta)

## 初期化
func initialize(ui_mgr, flow_mgr, c_system = null, p_system = null, b_system = null):
	game_flow_manager = flow_mgr
	card_system = c_system if c_system else (flow_mgr.card_system if flow_mgr else null)
	# game_3d参照は別途set_game_3d_ref()で設定される
	player_system = p_system if p_system else (flow_mgr.player_system if flow_mgr else null)
	board_system = b_system if b_system else (flow_mgr.board_system_3d if flow_mgr else null)

## game_statsを設定（GFM経由を廃止）
func set_game_stats(p_game_stats) -> void:
	game_stats = p_game_stats

## SpellEffectExecutorにスペルコンテナを設定（辞書展開廃止）
func set_spell_effect_executor_container(container: SpellSystemContainer) -> void:
	# ★ NEW: null チェック
	if not container:
		push_error("[SPH] set_spell_effect_executor_container: container が null です")
		return

	if not spell_effect_executor:
		push_error("[SPH] set_spell_effect_executor_container: spell_effect_executor が null です")
		return

	spell_effect_executor.set_spell_container(container)

	# ★ NEW: 設定確認
	if spell_effect_executor.spell_container:
		if spell_effect_executor.spell_container.is_valid():
			pass
		else:
			push_warning("[SPH] spell_effect_executor.spell_container は不完全です")
			spell_effect_executor.spell_container.debug_print_status()
	else:
		push_error("[SPH] spell_effect_executor.spell_container が null のままです")

## game_3d参照を設定（TutorialManager取得用）
func set_game_3d_ref(p_game_3d) -> void:
	game_3d_ref = p_game_3d


func set_battle_status_overlay(overlay) -> void:
	battle_status_overlay = overlay
	if spell_systems and spell_systems.spell_creature_move:
		spell_systems.spell_creature_move.set_battle_status_overlay(overlay)

## スペルフェーズ開始
func start_spell_phase(player_id: int):
	if not spell_state:
		push_error("[SPH] spell_state が見つかりません")
		return

	# フェーズ状態をリセット
	spell_state.reset_turn_state()
	spell_state.set_current_player_id(player_id)

	# スペルフェーズの初期状態に遷移（reset_turn_state() は INACTIVE に設定するため）
	spell_state.transition_to(SpellStateHandler.State.WAITING_FOR_INPUT)

	# CPU / 人間プレイヤーで分岐
	if game_flow_manager and game_flow_manager.is_cpu_player(player_id):
		await _delegate_to_cpu_spell_handler(player_id)
	else:
		# 人間プレイヤー向け: UI初期化のみ
		# シグナル駆動で自動的にフェーズが進行（spell_flow.use_spell() or pass_spell()）
		_initialize_human_player_ui()


## CPUのスペル使用判定（新AI使用）
## CPUSpellPhaseHandlerへの簡潔な委譲
func _delegate_to_cpu_spell_handler(player_id: int) -> void:
	"""CPU スペルターンを委譲（CPU固有ロジック削除）"""
	if not cpu_spell_phase_handler:
		push_error("[SPH] cpu_spell_phase_handler が初期化されていません（GameSystemManager で初期化してください）")
		return

	await cpu_spell_phase_handler.execute_cpu_spell_turn(player_id)

## 対象選択UIを表示（内部インターフェース）
func show_target_selection_ui(target_type: String, target_info: Dictionary) -> bool:
	if not spell_target_selection_handler:
		return false
	if spell_state:
		spell_state.transition_to(SpellStateHandler.State.SELECTING_TARGET)
	return await spell_target_selection_handler.show_target_selection_ui(target_type, target_info)

## 入力処理（内部インターフェース）
func _input(event: InputEvent) -> void:
	if spell_target_selection_handler:
		spell_target_selection_handler._input(event)


## タイルリストから選択（SpellCreatureMove用など）
## TargetSelectionHelperに委譲
func select_tile_from_list(tile_indices: Array, message: String) -> int:
	if tile_indices.is_empty():
		return -1

	# CPUの場合は自動選択（最初の候補を使用）
	if spell_state and game_flow_manager and game_flow_manager.is_cpu_player(spell_state.current_player_id):
		return tile_indices[0]

	# TargetSelectionHelper経由で選択（直接参照）
	if target_selection_helper:
		return await target_selection_helper.select_tile_from_list(tile_indices, message)

	# フォールバック：TargetSelectionHelperがない場合は最初のタイルを返す
	return tile_indices[0]



## 外部スペルを実行（SpellFlowHandler に委譲）
func execute_external_spell(spell_card: Dictionary, player_id: int, from_magic_tile: bool = false) -> Dictionary:
	if not spell_flow:
		push_error("[SPH] spell_flow が初期化されていません")
		return {"status": "error", "warped": false}

	return await spell_flow.execute_external_spell(spell_card, player_id, from_magic_tile)

## スペルフェーズ完了
func complete_spell_phase():
	if not spell_state:
		push_error("[SPH] spell_state が見つかりません")
		return

	# フェーズ状態を INACTIVE に遷移
	spell_state.transition_to(SpellStateHandler.State.INACTIVE)

	# スペルフェーズ完了シグナルを発行（GameFlowManager が待っている）
	spell_phase_completed.emit()

## ============ Delegation Methods to SpellFlowHandler ============

## スペルを使用（SpellFlowHandler に委譲）
func use_spell(spell_card: Dictionary):
	if not spell_flow:
		push_error("[SPH] spell_flow が初期化されていません")
		return
	await spell_flow.use_spell(spell_card)

## スペル関連のコンテキストを構築（世界呪い等）
func _build_spell_context() -> Dictionary:
	var context = {}
	
	if game_flow_manager and "game_stats" in game_flow_manager:
		context["world_curse"] = game_flow_manager.game_stats.get("world_curse", {})
	
	return context


## プレイヤーの順位を取得（PlayerSystem経由）
func get_player_ranking(player_id: int) -> int:
	if player_system:
		return player_system.get_player_ranking(player_id)
	return 1

## アクティブか
func is_spell_phase_active() -> bool:
	if not spell_state:
		return false
	return spell_state.current_state != SpellStateHandler.State.INACTIVE

## カード選択を処理（GFMのルーティング用）
## 戻り値: true=処理済み, false=処理不要
func try_handle_card_selection(card_index: int) -> bool:
	# カード選択ハンドラーが選択中の場合
	if card_selection_handler:
		if card_selection_handler.is_selecting_enemy_card():
			card_selection_handler.on_enemy_card_selected(card_index)
			return true
		if card_selection_handler.is_selecting_deck_card():
			card_selection_handler.on_deck_card_selected(card_index)
			return true
		if card_selection_handler.is_selecting_transform_card():
			card_selection_handler.on_transform_card_selected(card_index)
			return true

	# スペルフェーズ中かチェック（アイテムフェーズがアクティブでない場合）
	if is_spell_phase_active():
		if not spell_state:
			return false

		# スペルカードのみ使用可能
		var hand = card_system.get_all_cards_for_player(spell_state.current_player_id) if card_system else []
		if card_index >= hand.size():
			return true  # インデックスが範囲外なので処理終了

		var card = hand[card_index]
		var card_type = card.get("type", "")

		if card_type == "spell":
			use_spell(card)
			return true
		else:
			# スペルカード以外は使用不可
			return true

	# スペルフェーズがアクティブでない場合
	return false
	

## カード選択ハンドラーを初期化
func _initialize_card_selection_handler(ui_mgr = null):
	if card_selection_handler:
		return

	card_selection_handler = CardSelectionHandler.new()
	card_selection_handler.name = "CardSelectionHandler"
	add_child(card_selection_handler)

	# 参照を設定
	card_selection_handler.setup(
		ui_mgr,
		player_system,
		card_system,
		self
	)

	# SpellDrawにもcard_selection_handlerを設定
	if game_flow_manager and game_flow_manager.spell_container and game_flow_manager.spell_container.spell_draw:
		game_flow_manager.spell_container.spell_draw.set_card_selection_handler(card_selection_handler)
	
	# 選択完了シグナルを接続（重複接続防止）
	if not card_selection_handler.selection_completed.is_connected(_on_card_selection_completed):
		card_selection_handler.selection_completed.connect(_on_card_selection_completed)

## カード選択完了時のコールバック
func _on_card_selection_completed():
	complete_spell_phase()

## スペル/アルカナアーツ発動通知を表示（内部）
func show_spell_cast_notification(caster_name: String, target_data: Dictionary, spell_or_mystic: Dictionary, is_mystic: bool = false):
	if not spell_ui_manager:
		push_error("[SPH] spell_ui_manager が初期化されていません")
		return

	await spell_ui_manager.show_spell_cast_notification(caster_name, target_data, spell_or_mystic, is_mystic)


## カード犠牲が無効化されているか（TileActionProcessorから取得）
func _is_card_sacrifice_disabled() -> bool:
	if board_system and board_system.tile_action_processor:
		return board_system.tile_action_processor.debug_disable_card_sacrifice if board_system and board_system.tile_action_processor else false
	return false


## 土地条件が無効化されているか（TileActionProcessorから取得）
func _is_lands_required_disabled() -> bool:
	if board_system and board_system.tile_action_processor:
		return board_system.tile_action_processor.debug_disable_lands_required if board_system and board_system.tile_action_processor else false
	return false


# =============================================================================
# CPUバトルポリシー取得
# =============================================================================

## 現在のCPUのバトルポリシーを取得
func _get_cpu_battle_policy():
	if spell_systems and spell_systems.cpu_turn_processor and spell_systems.cpu_turn_processor.cpu_ai_handler:
		return spell_systems.cpu_turn_processor.cpu_ai_handler.battle_policy
	return null


## 人間プレイヤー向けスペルフェーズUI初期化（Signal駆動）
func _initialize_human_player_ui() -> void:
	if not spell_state:
		push_error("[SPH] spell_state が見つかりません")
		return

	var player_id = spell_state.current_player_id
	var hand_data = card_system.get_all_cards_for_player(player_id) if card_system else []
	var magic_power = 0
	if player_system:
		var player = player_system.players[player_id] if player_id >= 0 and player_id < player_system.players.size() else null
		if player:
			magic_power = player.magic_power

	human_spell_phase_started.emit(player_id, hand_data, magic_power)
