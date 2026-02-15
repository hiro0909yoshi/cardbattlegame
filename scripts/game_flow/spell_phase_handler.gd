# SpellPhaseHandler - スペルフェーズの処理を担当
extends Node
class_name SpellPhaseHandler

const CPUAIContextScript = preload("res://scripts/cpu_ai/cpu_ai_context.gd")
const CPUSpellPhaseHandlerScript = preload("res://scripts/cpu_ai/cpu_spell_phase_handler.gd")

# 共有コンテキスト（CPU AI用）
var _cpu_context: CPUAIContextScript = null

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
var spell_magic = null  # SpellMagic: EP操作（新規追加）
var spell_curse_stat = null  # SpellCurseStat: ステータス変更（新規追加）
var battle_status_overlay = null  # BattleStatusOverlay: バトルステータス表示
var target_selection_helper = null  # TargetSelectionHelper: ターゲット選択
var spell_orchestrator = null  # SpellPhaseOrchestrator: フェーズ管理オーケストレーター

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

## スペル決定待機用フラグ（Lambda重複接続防止用）
var _waiting_for_spell_decision = false

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

## 直接参照を設定（GFM経由を廃止）
func set_spell_systems_direct(cost_modifier, draw, magic, curse_stat) -> void:
	spell_cost_modifier = cost_modifier
	spell_draw = draw
	spell_magic = magic              # 新規追加
	spell_curse_stat = curse_stat    # 新規追加

	# card_selection_handlerが既に初期化されている場合、spell_drawを設定
	if spell_draw and card_selection_handler:
		spell_draw.set_card_selection_handler(card_selection_handler)

func set_battle_status_overlay(overlay) -> void:
	battle_status_overlay = overlay
	if spell_systems and spell_systems.spell_creature_move:
		spell_systems.spell_creature_move.set_battle_status_overlay(overlay)

## スペルフェーズ開始
func start_spell_phase(player_id: int):
	if not spell_orchestrator:
		push_error("[SPH] spell_orchestrator が見つかりません")
		return

	# フェーズ開始をオーケストレーターに委譲
	await spell_orchestrator.start_spell_phase(player_id)

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
			# NOTE: 完了シグナル(spell_phase_completed)は以下のフローで既に発火済み
			# _execute_cpu_spell_from_decision() → execute_spell_effect()
			# → spell_effect_executor.execute_spell_effect() → handler.complete_spell_phase()
			# ここで重複呼び出しを防ぐため、コメント表示のみ
		"mystic":
			if mystic_arts_handler:
				await mystic_arts_handler._execute_cpu_mystic_arts(decision)
				# NOTE: 完了シグナルは mystic_arts_handler 内で発火済み
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
	return tile_indices[0]



## 外部スペルを実行（SpellFlowHandler に委譲）
func execute_external_spell(spell_card: Dictionary, player_id: int, from_magic_tile: bool = false) -> Dictionary:
	if not spell_flow:
		push_error("[SPH] spell_flow が初期化されていません")
		return {"status": "error", "warped": false}

	return await spell_flow.execute_external_spell(spell_card, player_id, from_magic_tile)

## スペルフェーズ完了（SpellPhaseOrchestrator に委譲）
func complete_spell_phase():
	if not spell_orchestrator:
		push_error("[SPH] spell_orchestrator が見つかりません")
		return

	spell_orchestrator.complete_spell_phase()

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
	if not spell_confirmation_handler:
		push_error("[SPH] spell_confirmation_handler が初期化されていません")
		return

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


## 待機中のspell_used シグナル処理（メンバー関数）
func _on_spell_used_while_waiting(_spell_card: Dictionary) -> void:
	"""待機中のspell_used シグナル処理"""
	_waiting_for_spell_decision = false

## 待機中のspell_passed シグナル処理（メンバー関数）
func _on_spell_passed_while_waiting() -> void:
	"""待機中のspell_passed シグナル処理"""
	_waiting_for_spell_decision = false

## 人間プレイヤーのスペル決定を待機
func _wait_for_human_spell_decision() -> void:
	"""
	人間プレイヤーがスペルを使用または通過するまで待機

	メンバー関数を使用してシグナル接続を管理し、
	lambda による重複接続問題を解決
	"""
	if not spell_flow:
		push_error("[SPH] spell_flow が初期化されていません")
		return

	# 初期UI表示
	if spell_navigation_controller:
		spell_navigation_controller._initialize_spell_phase_ui()
		spell_navigation_controller._show_spell_phase_buttons()
		spell_navigation_controller._setup_spell_selection_navigation()
	else:
		push_error("[SPH] spell_navigation_controller が初期化されていません")

	# CardSelectionUI を表示（is_active = true に設定）
	if spell_ui_controller and spell_state:
		var hand_data = card_system.get_all_cards_for_player(spell_state.current_player_id) if card_system else []
		var magic_power = 0
		if player_system and spell_state:
			var player = player_system.players[spell_state.current_player_id] if spell_state.current_player_id >= 0 and spell_state.current_player_id < player_system.players.size() else null
			if player:
				magic_power = player.magic_power
		spell_ui_controller.show_spell_selection_ui(hand_data, magic_power)

	# 待機フラグを設定
	_waiting_for_spell_decision = true

	# 古い接続があれば切断（安全のため）
	if spell_used.is_connected(_on_spell_used_while_waiting):
		spell_used.disconnect(_on_spell_used_while_waiting)

	if spell_passed.is_connected(_on_spell_passed_while_waiting):
		spell_passed.disconnect(_on_spell_passed_while_waiting)

	# シグナルを接続（メンバー関数なので is_connected() が正しく機能）
	spell_used.connect(_on_spell_used_while_waiting)
	spell_passed.connect(_on_spell_passed_while_waiting)

	# spell_used または spell_passed が発行されるまで待機
	while _waiting_for_spell_decision:
		await get_tree().process_frame

	# シグナルを切断（確実に）
	if spell_used.is_connected(_on_spell_used_while_waiting):
		spell_used.disconnect(_on_spell_used_while_waiting)

	if spell_passed.is_connected(_on_spell_passed_while_waiting):
		spell_passed.disconnect(_on_spell_passed_while_waiting)
