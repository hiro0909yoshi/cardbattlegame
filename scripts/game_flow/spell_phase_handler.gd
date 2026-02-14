# SpellPhaseHandler - スペルフェーズの処理を担当
extends Node
class_name SpellPhaseHandler

const CPUAIContextScript = preload("res://scripts/cpu_ai/cpu_ai_context.gd")
const CPUSpellPhaseHandlerScript = preload("res://scripts/cpu_ai/cpu_spell_phase_handler.gd")
const SpellStrategyFactory = preload("res://scripts/spells/strategies/spell_strategy_factory.gd")

# 共有コンテキスト（CPU AI用）
var _cpu_context: CPUAIContextScript = null

## シグナル
signal spell_phase_started()
signal spell_phase_completed()
signal spell_passed()
@warning_ignore("unused_signal")  # spell_effect_executorでemitされる（将来の拡張用）
signal spell_used(spell_card: Dictionary)
signal target_selection_required(spell_card: Dictionary, target_type: String)
signal target_confirmed(target_data: Dictionary)  # ターゲット選択完了時

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
signal external_spell_finished()  # 外部スペル実行完了

## 参照
var ui_manager = null
var hand_display = null  # hand_display参照
var game_flow_manager = null
var game_3d_ref = null  # game_3d直接参照（get_parent()チェーン廃止用）
var card_system = null
var player_system = null
var board_system = null
var creature_manager = null
var spell_mystic_arts = null  # アルカナアーツシステム
var spell_phase_ui_manager = null  # UIボタン管理
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
var spell_cost_modifier = null  # SpellCostModifier: コスト計算
var spell_draw = null  # SpellDraw: ドロー処理
var battle_status_overlay = null  # BattleStatusOverlay: バトルステータス表示
var target_selection_helper = null  # TargetSelectionHelper: ターゲット選択

var cpu_spell_ai: CPUSpellAI = null  # CPUスペル判断AI
var cpu_mystic_arts_ai: CPUMysticArtsAI = null  # CPUアルカナアーツ判断AI
var cpu_hand_utils: CPUHandUtils = null  # CPU手札ユーティリティ
var cpu_movement_evaluator: CPUMovementEvaluator = null  # CPU移動評価（ホーリーワード判断用）
var cpu_spell_phase_handler = null  # CPUスペルフェーズ処理
var spell_target_selection_handler = null  # SpellTargetSelectionHandler - 対象選択ハンドラー（Phase 6-1、循環参照回避のため型アノテーションなし）
var spell_confirmation_handler = null  # SpellConfirmationHandler - スペル発動確認ハンドラー（循環参照回避のため型アノテーションなし）
var spell_ui_controller = null  # SpellUIController - UI制御（Phase 7-1、循環参照回避のため型アノテーションなし）
var mystic_arts_handler = null  # MysticArtsHandler - アルカナアーツ処理（Phase 8-1、循環参照回避のため型アノテーションなし）

## ===== ハンドラー参照（Phase 3-A Day 9-12） =====
var spell_state: SpellStateHandler = null          # 状態管理（Day 9）
var spell_flow: SpellFlowHandler = null            # フロー制御（Day 10-11）
var spell_navigation_controller: SpellNavigationController = null  # ナビゲーション管理（Day 18）

func _ready():
	pass

func _process(delta):
	# 選択マーカーを回転
	TargetSelectionHelper.rotate_selection_marker(self, delta)
	# 確認フェーズ用マーカーを回転
	TargetSelectionHelper.rotate_confirmation_markers(self, delta)

## 初期化
func initialize(ui_mgr, flow_mgr, c_system = null, p_system = null, b_system = null):
	ui_manager = ui_mgr
	game_flow_manager = flow_mgr
	if ui_manager and ui_manager.get("hand_display"):
		hand_display = ui_manager.hand_display
	card_system = c_system if c_system else (flow_mgr.card_system if flow_mgr else null)
	# game_3d参照は別途set_game_3d_ref()で設定される
	player_system = p_system if p_system else (flow_mgr.player_system if flow_mgr else null)
	board_system = b_system if b_system else (flow_mgr.board_system_3d if flow_mgr else null)

## game_statsを設定（GFM経由を廃止）
func set_game_stats(p_game_stats) -> void:
	game_stats = p_game_stats

	# SpellInitializer で全サブシステムを初期化
	var initializer = SpellInitializer.new()
	initializer.initialize(self, game_stats)

	# SpellMysticArts を MysticArtsHandler経由で初期化
	if mystic_arts_handler:
		mystic_arts_handler.initialize_spell_mystic_arts()
		spell_mystic_arts = mystic_arts_handler.get_spell_mystic_arts()

## SpellEffectExecutorにスペルコンテナを設定（辞書展開廃止）
func set_spell_effect_executor_container(container: SpellSystemContainer) -> void:
	if spell_effect_executor:
		spell_effect_executor.set_spell_container(container)

## game_3d参照を設定（TutorialManager取得用）
func set_game_3d_ref(p_game_3d) -> void:
	game_3d_ref = p_game_3d

## 直接参照を設定（GFM経由を廃止）
func set_spell_systems_direct(cost_modifier, draw) -> void:
	spell_cost_modifier = cost_modifier
	spell_draw = draw
	print("[SpellPhaseHandler] spell_cost_modifier, spell_draw 直接参照を設定")

	# card_selection_handlerが既に初期化されている場合、spell_drawを設定
	if spell_draw and card_selection_handler:
		spell_draw.set_card_selection_handler(card_selection_handler)

func set_battle_status_overlay(overlay) -> void:
	battle_status_overlay = overlay
	if spell_systems and spell_systems.spell_creature_move:
		spell_systems.spell_creature_move.set_battle_status_overlay(overlay)
	print("[SpellPhaseHandler] battle_status_overlay 直接参照を設定")

## スペルフェーズ開始
func start_spell_phase(player_id: int):
	if not spell_state:
		push_error("[SPH] spell_state が初期化されていません")
		return

	if spell_state.current_state != SpellStateHandler.State.INACTIVE:
		return

	# SpellStateHandler で状態を初期化
	spell_state.transition_to(SpellStateHandler.State.WAITING_FOR_INPUT)
	spell_state.set_current_player_id(player_id)
	spell_state.set_spell_used_this_turn(false)
	spell_state.set_skip_dice_phase(false)
	spell_state.clear_spell_card()

	spell_phase_started.emit()

	# UIを更新（スペルカードのみ選択可能にする）
	if ui_manager:
		_update_spell_phase_ui()
		_show_spell_phase_buttons()

	# CPUの場合は簡潔に委譲
	if is_cpu_player(player_id):
		await _delegate_to_cpu_spell_handler(player_id)
	else:
		# 人間プレイヤーの場合：カメラ手動モード有効化
		if board_system and board_system.has_method("enable_manual_camera"):
			board_system.enable_manual_camera()
			if board_system.has_method("set_camera_player"):
				board_system.set_camera_player(player_id)
		else:
			push_error("[SPH] board_system のカメラメソッドが利用不可")

		# グローバルナビゲーション設定（戻るボタンのみ = スペルを使わない）
		_setup_spell_selection_navigation()

		# 入力待ち
		if ui_manager and ui_manager.phase_display:
			ui_manager.show_action_prompt("スペルを使用するか、ダイスを振ってください")

## UIメソッド（内部使用のため簡潔実装）
func _update_spell_phase_ui():
	if spell_ui_controller:
		spell_ui_controller.update_spell_phase_ui()

func _show_spell_selection_ui(_hand_data: Array, _available_magic: int):
	if spell_ui_controller:
		spell_ui_controller.show_spell_selection_ui(_hand_data, _available_magic)

## アルカナアーツフェーズ開始（外部APIとして保持）
func start_mystic_arts_phase():
	"""アルカナアーツ選択フェーズを開始"""
	if mystic_arts_handler:
		await mystic_arts_handler.start_mystic_arts_phase()


## CPUのスペル使用判定（新AI使用）
## CPUSpellPhaseHandlerへの簡潔な委譲
func _delegate_to_cpu_spell_handler(player_id: int) -> void:
	"""CPU スペルフェーズの処理を CPUSpellPhaseHandler に完全委譲"""
	await get_tree().create_timer(0.5).timeout  # 思考時間

	# スペル使用確率判定（キャラクターポリシー）
	var battle_policy = _get_cpu_battle_policy()
	if battle_policy and not battle_policy.should_use_spell():
		print("[CPU SpellPhase] スペル使用スキップ（確率判定: %.0f%%）" % (battle_policy.get_spell_use_rate() * 100))
		pass_spell(false)
		return

	# CPUSpellPhaseHandlerで判断
	if not cpu_spell_phase_handler:
		cpu_spell_phase_handler = CPUSpellPhaseHandlerScript.new()
		cpu_spell_phase_handler.initialize(self)

	var action_result = cpu_spell_phase_handler.decide_action(player_id)
	var action = action_result.get("action", "pass")
	var decision = action_result.get("decision", {})

	match action:
		"spell":
			await _execute_cpu_spell_from_decision(decision, player_id)
		"mystic":
			if mystic_arts_handler:
				await mystic_arts_handler._execute_cpu_mystic_arts(decision)
			else:
				pass_spell(false)
		_:
			pass_spell(false)

## CPUがスペルを実行（decision から実行）
func _execute_cpu_spell_from_decision(decision: Dictionary, player_id: int) -> void:
	if not spell_state:
		push_error("[SPH] spell_state が初期化されていません")
		pass_spell(false)
		return

	if not cpu_spell_phase_handler:
		push_error("[SPH] cpu_spell_phase_handler が初期化されていません")
		pass_spell(false)
		return

	# CPUSpellPhaseHandlerで準備処理
	var prep = cpu_spell_phase_handler.prepare_spell_execution(decision, player_id)
	if not prep.get("success", false):
		pass_spell(false)
		return

	var spell_card = prep.get("spell_card", {})
	var target_data = prep.get("target_data", {})
	var cost = prep.get("cost", 0)
	var target = prep.get("target", {})

	# コストを支払う
	if player_system:
		player_system.add_magic(player_id, -cost)

	spell_state.set_spell_card(spell_card)
	spell_state.set_spell_used_this_turn(true)

	# 効果実行（target_typeに応じて分岐）
	var parsed = spell_card.get("effect_parsed", {})
	var target_type = parsed.get("target_type", "")

	if target_type == "all_creatures":
		# 全クリーチャー対象スペル（スウォーム等）は専用ルートで実行
		# 通知・カード捨て札・フェーズ完了は_execute_spell_on_all_creatures内で処理
		var target_info = parsed.get("target_info", {})
		await _execute_spell_on_all_creatures(spell_card, target_info)
	else:
		# 発動通知表示
		if spell_cast_notification_ui and player_system:
			var caster_name = "CPU"
			if player_id >= 0 and player_id < player_system.players.size():
				caster_name = player_system.players[player_id].name
			await show_spell_cast_notification(caster_name, target, spell_card, false)

		await execute_spell_effect(spell_card, target_data)

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

## カメラを使用者に戻す（内部）
func return_camera_to_player():
	if spell_ui_controller:
		spell_ui_controller.return_camera_to_player()

## タイルリストから選択（SpellCreatureMove用など）
## TargetSelectionHelperに委譲
func select_tile_from_list(tile_indices: Array, message: String) -> int:
	if tile_indices.is_empty():
		return -1

	# CPUの場合は自動選択（最初の候補を使用）
	if spell_state and is_cpu_player(spell_state.current_player_id):
		return tile_indices[0]

	# TargetSelectionHelper経由で選択（直接参照）
	if target_selection_helper:
		return await target_selection_helper.select_tile_from_list(tile_indices, message)

	# フォールバック：TargetSelectionHelperがない場合は最初のタイルを返す
	print("[SpellPhaseHandler] WARNING: TargetSelectionHelperが見つかりません、最初のタイルを選択")
	return tile_indices[0]



## 外部スペルを実行（SpellFlowHandler に委譲）
func execute_external_spell(spell_card: Dictionary, player_id: int, from_magic_tile: bool = false) -> Dictionary:
	if not spell_flow:
		push_error("[SPH] spell_flow が初期化されていません")
		return {"status": "error", "warped": false}

	return await spell_flow.execute_external_spell(spell_card, player_id, from_magic_tile)

## スペルフェーズ完了（SpellFlowHandler に委譲）
func complete_spell_phase():
	if not spell_flow:
		push_error("[SPH] spell_flow が初期化されていません")
		return

	spell_flow.complete_spell_phase()

## ============ Delegation Methods to SpellFlowHandler ============

## スペルを使用（SpellFlowHandler に委譲）
func use_spell(spell_card: Dictionary):
	if not spell_flow:
		push_error("[SPH] spell_flow が初期化されていません")
		return
	await spell_flow.use_spell(spell_card)

## スペルをキャンセル（SpellFlowHandler に委譲）
func cancel_spell():
	if not spell_flow:
		push_error("[SPH] spell_flow が初期化されていません")
		return
	spell_flow.cancel_spell()

## スペル効果を実行（SpellFlowHandler に委譲）
func execute_spell_effect(spell_card: Dictionary, target_data: Dictionary):
	if not spell_flow:
		push_error("[SPH] spell_flow が初期化されていません")
		return
	await spell_flow.execute_spell_effect(spell_card, target_data)

## 全クリーチャー対象スペルを実行（SpellFlowHandler に委譲）
func _execute_spell_on_all_creatures(spell_card: Dictionary, target_info: Dictionary):
	if not spell_flow:
		push_error("[SPH] spell_flow が初期化されていません")
		return
	await spell_flow._execute_spell_on_all_creatures(spell_card, target_info)

## スペル効果を確認（SpellFlowHandler に委譲）
func _confirm_spell_effect():
	if not spell_flow:
		push_error("[SPH] spell_flow が初期化されていません")
		return
	spell_flow._confirm_spell_effect()

## スペル確認をキャンセル（SpellFlowHandler に委譲）
func _cancel_confirmation():
	if not spell_flow:
		push_error("[SPH] spell_flow が初期化されていません")
		return
	spell_flow._cancel_confirmation()

## スペルをパス（SpellFlowHandler に委譲）
func pass_spell(auto_roll: bool = true):
	if not spell_flow:
		push_error("[SPH] spell_flow が初期化されていません")
		return
	spell_flow.pass_spell(auto_roll)

## CPUプレイヤーかどうか
func is_cpu_player(player_id: int) -> bool:
	if not game_flow_manager:
		return false

	var cpu_settings = game_flow_manager.player_is_cpu

	if DebugSettings.manual_control_all:
		return false  # デバッグモードでは全員手動

	return player_id < cpu_settings.size() and cpu_settings[player_id]

## スペル関連のコンテキストを構築（世界呪い等）
func _build_spell_context() -> Dictionary:
	var context = {}
	
	if game_flow_manager and "game_stats" in game_flow_manager:
		context["world_curse"] = game_flow_manager.game_stats.get("world_curse", {})
	
	return context


## プレイヤーの順位を取得（委譲メソッド経由）
func get_player_ranking(player_id: int) -> int:
	if ui_manager:
		return ui_manager.get_player_ranking(player_id)
	# フォールバック: 常に1位を返す
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

# ============ アルカナアーツシステム対応（新規追加）============

## アルカナアーツが利用可能か確認（外部API）
func has_available_mystic_arts(player_id: int) -> bool:
	if mystic_arts_handler:
		return mystic_arts_handler.has_available_mystic_arts(player_id)
	return false

## SpellMysticArtsクラスが存在するか（外部API）
func has_spell_mystic_arts() -> bool:
	if mystic_arts_handler:
		return mystic_arts_handler._has_spell_mystic_arts()
	return spell_mystic_arts != null and spell_mystic_arts is SpellMysticArts

# ============ UIボタン管理 ============

## UIボタン管理（内部）
## UI初期化 - 委譲メソッド
func _initialize_spell_phase_ui():
	if spell_navigation_controller:
		spell_navigation_controller._initialize_spell_phase_ui()
	else:
		push_error("[SPH] spell_navigation_controller が初期化されていません")

## スペルフェーズボタン表示 - 委譲メソッド
func _show_spell_phase_buttons():
	if spell_navigation_controller:
		spell_navigation_controller._show_spell_phase_buttons()
	else:
		push_error("[SPH] spell_navigation_controller が初期化されていません")

## スペルフェーズボタン非表示 - 委譲メソッド
func _hide_spell_phase_buttons():
	if spell_navigation_controller:
		spell_navigation_controller._hide_spell_phase_buttons()
	else:
		push_error("[SPH] spell_navigation_controller が初期化されていません")


# ============ グローバルナビゲーション設定 ============

## スペル選択時のナビゲーション設定（決定 = スペルを使わない → サイコロ）- 委譲メソッド
func _setup_spell_selection_navigation():
	if spell_navigation_controller:
		spell_navigation_controller._setup_spell_selection_navigation()
	else:
		push_error("[SPH] spell_navigation_controller が初期化されていません")

## 閲覧モード（グレーアウトカードタップ等）から戻る時のナビゲーション復元
## state別にナビゲーション + 特殊ボタン + フェーズコメントを復元する
func restore_navigation():
	if spell_navigation_controller:
		spell_navigation_controller.restore_navigation()
	else:
		push_error("[SPH] spell_navigation_controller が初期化されていません")

## state別のナビゲーション復元（アルカナアーツ判定をスキップ）
## spell_mystic_arts.restore_navigation()からの再帰呼び出し時に使用
func restore_navigation_for_state():
	if spell_navigation_controller:
		spell_navigation_controller.restore_navigation_for_state()
	else:
		push_error("[SPH] spell_navigation_controller が初期化されていません")

## ナビゲーション設定（ターゲット選択）- 委譲メソッド
func _setup_target_selection_navigation() -> void:
	if spell_navigation_controller:
		spell_navigation_controller._setup_target_selection_navigation()
	else:
		push_error("[SPH] spell_navigation_controller が初期化されていません")

## ナビゲーション設定解除 - 委譲メソッド
func _clear_spell_navigation() -> void:
	if spell_navigation_controller:
		spell_navigation_controller._clear_spell_navigation()
	else:
		push_error("[SPH] spell_navigation_controller が初期化されていません")

## ターゲット確認 - 委譲メソッド
func _on_target_confirm() -> void:
	if spell_navigation_controller:
		spell_navigation_controller._on_target_confirm()
	else:
		push_error("[SPH] spell_navigation_controller が初期化されていません")

## ターゲット選択キャンセル - 委譲メソッド
func _on_target_cancel() -> void:
	if spell_navigation_controller:
		spell_navigation_controller._on_target_cancel()
	else:
		push_error("[SPH] spell_navigation_controller が初期化されていません")

## ターゲット選択前へ - 委譲メソッド
func _on_target_prev() -> void:
	if spell_navigation_controller:
		spell_navigation_controller._on_target_prev()
	else:
		push_error("[SPH] spell_navigation_controller が初期化されていません")

## ターゲット選択次へ - 委譲メソッド
func _on_target_next() -> void:
	if spell_navigation_controller:
		spell_navigation_controller._on_target_next()
	else:
		push_error("[SPH] spell_navigation_controller が初期化されていません")


## アルカナアーツ関連（内部）
func update_mystic_button_visibility():
	if mystic_arts_handler:
		mystic_arts_handler.update_mystic_button_visibility()

func _on_mystic_art_used():
	if mystic_arts_handler:
		mystic_arts_handler._on_mystic_art_used()

func _on_mystic_phase_completed():
	if mystic_arts_handler:
		mystic_arts_handler._on_mystic_phase_completed()

func _on_mystic_target_selection_requested(targets: Array) -> void:
	if mystic_arts_handler:
		mystic_arts_handler._on_mystic_target_selection_requested(targets)

func _on_mystic_ui_message_requested(message: String):
	if mystic_arts_handler:
		mystic_arts_handler._on_mystic_ui_message_requested(message)


# ============ 発動通知UI ============

## 発動通知UIを初期化（内部）
func _initialize_spell_cast_notification_ui():
	if spell_confirmation_handler:
		spell_confirmation_handler.initialize_spell_cast_notification_ui()
		spell_cast_notification_ui = spell_confirmation_handler.get_spell_cast_notification_ui()

## カード選択ハンドラーを初期化
func _initialize_card_selection_handler():
	if card_selection_handler:
		return
	
	card_selection_handler = CardSelectionHandler.new()
	card_selection_handler.name = "CardSelectionHandler"
	add_child(card_selection_handler)
	
	# 参照を設定
	card_selection_handler.setup(
		ui_manager,
		player_system,
		card_system,
		self,
		spell_phase_ui_manager
	)

	# SpellDrawにもcard_selection_handlerを設定
	if spell_draw:
		spell_draw.set_card_selection_handler(card_selection_handler)
	
	# 選択完了シグナルを接続（重複接続防止）
	if not card_selection_handler.selection_completed.is_connected(_on_card_selection_completed):
		card_selection_handler.selection_completed.connect(_on_card_selection_completed)

## カード選択完了時のコールバック
func _on_card_selection_completed():
	complete_spell_phase()

## スペル/アルカナアーツ発動通知を表示（内部）
func show_spell_cast_notification(caster_name: String, target_data: Dictionary, spell_or_mystic: Dictionary, is_mystic: bool = false):
	if spell_confirmation_handler:
		await spell_confirmation_handler.show_spell_cast_notification(caster_name, target_data, spell_or_mystic, is_mystic)


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


## 手札更新時にボタン位置を再計算（グローバルボタンは自動配置のため空実装）
func _on_hand_updated_for_buttons():
	# グローバルボタンに移行したため、手動での位置更新は不要
	pass


# =============================================================================
# CPU AI コンテキスト初期化
# =============================================================================

# CPUBattleAI（ローカル）
var _cpu_battle_ai: CPUBattleAI = null

## CPU AI用の共有コンテキストを初期化
func _initialize_cpu_context(flow_mgr) -> void:
	if _cpu_context:
		return  # 既に初期化済み
	
	var player_buff_system = flow_mgr.player_buff_system if flow_mgr else null
	
	# コンテキストを作成
	_cpu_context = CPUAIContextScript.new()
	_cpu_context.setup(board_system, player_system, card_system)
	_cpu_context.setup_optional(
		creature_manager,
		flow_mgr.lap_system if flow_mgr else null,
		flow_mgr,
		null,  # battle_system
		player_buff_system
	)
	
	# CPUBattleAIを初期化（共通バトル評価用）
	if not _cpu_battle_ai:
		_cpu_battle_ai = CPUBattleAI.new()
		_cpu_battle_ai.setup_with_context(_cpu_context)
	
	# cpu_hand_utilsはcontextから取得
	cpu_hand_utils = _cpu_context.get_hand_utils()


# =============================================================================
# TapTargetManager連携（スペルターゲット選択）
# =============================================================================

## Tap Target Manager 関連（内部）
func _start_spell_tap_target_selection(targets: Array, target_type: String) -> void:
	if spell_target_selection_handler:
		spell_target_selection_handler._start_spell_tap_target_selection(targets, target_type)

func _end_spell_tap_target_selection() -> void:
	if spell_target_selection_handler:
		spell_target_selection_handler._end_spell_tap_target_selection()

func _check_tutorial_target_allowed(tile_index: int) -> bool:
	if spell_target_selection_handler:
		return spell_target_selection_handler._check_tutorial_target_allowed(tile_index)
	return true

func _check_tutorial_player_target_allowed(player_id: int) -> bool:
	if spell_target_selection_handler:
		return spell_target_selection_handler._check_tutorial_player_target_allowed(player_id)
	return true

func _on_spell_tap_target_selected(tile_index: int, creature_data: Dictionary) -> void:
	if spell_target_selection_handler:
		spell_target_selection_handler._on_spell_tap_target_selected(tile_index, creature_data)

func _start_mystic_tap_target_selection(targets: Array) -> void:
	if spell_target_selection_handler:
		spell_target_selection_handler._start_mystic_tap_target_selection(targets)


# =============================================================================
# CPUバトルポリシー取得
# =============================================================================

## 現在のCPUのバトルポリシーを取得
func _get_cpu_battle_policy():
	if spell_systems and spell_systems.cpu_turn_processor and spell_systems.cpu_turn_processor.cpu_ai_handler:
		return spell_systems.cpu_turn_processor.cpu_ai_handler.battle_policy
	return null

## SpellTargetSelectionHandler を初期化（Phase 6-1）
func _initialize_spell_target_selection_handler() -> void:
	if spell_target_selection_handler:
		return  # 既に初期化済み

	spell_target_selection_handler = SpellTargetSelectionHandler.new()
	spell_target_selection_handler.name = "SpellTargetSelectionHandler"
	add_child(spell_target_selection_handler)

	# 参照を設定（setup() 時に注入）
	spell_target_selection_handler.setup(
		self,
		ui_manager,
		board_system,
		player_system,
		game_3d_ref
	)

## SpellConfirmationHandler を初期化（Phase 6-2）
func _initialize_spell_confirmation_handler() -> void:
	if spell_confirmation_handler:
		return  # 既に初期化済み

	spell_confirmation_handler = SpellConfirmationHandler.new()
	spell_confirmation_handler.name = "SpellConfirmationHandler"
	add_child(spell_confirmation_handler)

	# 参照を設定（setup() 時に注入）
	spell_confirmation_handler.setup(
		self,
		ui_manager,
		board_system,
		player_system,
		game_3d_ref
	)

	# 発動通知UIを初期化
	spell_confirmation_handler.initialize_spell_cast_notification_ui()

## SpellUIController を初期化（Phase 7-1）
func _initialize_spell_ui_controller() -> void:
	if spell_ui_controller:
		return  # 既に初期化済み

	spell_ui_controller = SpellUIController.new()
	spell_ui_controller.name = "SpellUIController"
	add_child(spell_ui_controller)

	# 参照を設定（setup() 時に注入）
	spell_ui_controller.setup(
		self,
		ui_manager,
		board_system,
		player_system,
		game_3d_ref,
		card_system
	)

	# SpellPhaseUIManager を初期化
	spell_ui_controller.initialize_spell_phase_ui()

## MysticArtsHandler を初期化（Phase 8-1）
func _initialize_mystic_arts_handler() -> void:
	if mystic_arts_handler:
		return  # 既に初期化済み

	mystic_arts_handler = MysticArtsHandler.new()
	mystic_arts_handler.name = "MysticArtsHandler"
	add_child(mystic_arts_handler)

	# 参照を設定（setup() 時に注入）
	mystic_arts_handler.setup(
		self,
		ui_manager,
		board_system,
		player_system,
		card_system,
		game_3d_ref
	)

## SpellStateHandler と SpellFlowHandler を初期化（Phase 3-A Day 9-12）
func _initialize_spell_state_and_flow() -> void:
	if spell_state:
		return  # 既に初期化済み

	# SpellStateHandler 作成
	spell_state = SpellStateHandler.new()

	# SpellFlowHandler 作成
	spell_flow = SpellFlowHandler.new(spell_state)

	# SpellFlowHandler に参照を注入
	spell_flow.setup(
		self,                    # spell_phase_handler
		ui_manager,
		game_flow_manager,
		board_system,
		player_system,
		card_system,
		game_3d_ref,
		spell_cost_modifier,     # オプショナル参照
		spell_systems.spell_synthesis if spell_systems else null,
		spell_systems.card_sacrifice_helper if spell_systems else null,
		spell_effect_executor,
		spell_target_selection_handler,
		target_selection_helper
	)

	# SpellNavigationController を初期化（Day 18）
	if not spell_navigation_controller:
		spell_navigation_controller = SpellNavigationController.new()
		spell_navigation_controller.setup(
			self,
			ui_manager,
			spell_ui_controller,
			spell_target_selection_handler,
			spell_state
		)

	print("[SPH] SpellStateHandler と SpellFlowHandler を初期化完了")
