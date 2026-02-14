# SpellInitializer - SpellPhaseHandlerの初期化ロジックを担当
class_name SpellInitializer
extends RefCounted

## SpellPhaseHandler の初期化ロジックを完全管理
## 26個のサブシステムを正しい順序で初期化する
##
## 責務:
## - 基本参照の取得（CreatureManager など）
## - 11個のSpell**** クラスの初期化
## - 6個のハンドラーの初期化
## - CPU AI コンテキストの初期化

## 初期化を実行
func initialize(spell_phase_handler, game_stats: Dictionary) -> void:
	if not spell_phase_handler:
		push_error("[SpellInitializer] spell_phase_handler が null です")
		return

	# Step 1: 基本参照の取得
	_setup_base_references(spell_phase_handler, game_stats)

	# Step 2: 11個のSpell**** クラスを初期化
	_initialize_spell_systems(spell_phase_handler, game_stats)

	# Step 3: 6個のハンドラーを初期化
	_initialize_handlers(spell_phase_handler)

	# Step 4: CPU AI を初期化
	_initialize_cpu_ai(spell_phase_handler, game_stats)

	print("[SpellInitializer] 初期化完了（26個のサブシステム）")


## Step 1: 基本参照の取得
func _setup_base_references(sph, game_stats: Dictionary) -> void:
	# CreatureManager を取得
	if sph.board_system:
		sph.creature_manager = sph.board_system.get_node_or_null("CreatureManager")
		if not sph.creature_manager:
			push_error("[SpellInitializer] CreatureManager が見つかりません")

	# target_selection_helper の直接参照を設定
	if sph.game_flow_manager and sph.game_flow_manager.target_selection_helper:
		sph.target_selection_helper = sph.game_flow_manager.target_selection_helper


## Step 2: 11個のSpell**** クラスを初期化（SpellSubsystemContainer 経由）
func _initialize_spell_systems(sph, game_stats: Dictionary) -> void:
	# === Phase 3-A Day 18: SpellSubsystemContainer 初期化 ===
	if not sph.spell_systems:
		sph.spell_systems = SpellSubsystemContainer.new()

	# SpellDamage を初期化
	if not sph.spell_systems.spell_damage and sph.board_system:
		sph.spell_systems.spell_damage = SpellDamage.new(sph.board_system)

	# SpellCreatureMove を初期化
	if not sph.spell_systems.spell_creature_move and sph.board_system and sph.player_system:
		sph.spell_systems.spell_creature_move = SpellCreatureMove.new(sph.board_system, sph.player_system, sph)
		if sph.game_flow_manager:
			sph.spell_systems.spell_creature_move.set_game_flow_manager(sph.game_flow_manager)
		if sph.battle_status_overlay:
			sph.spell_systems.spell_creature_move.set_battle_status_overlay(sph.battle_status_overlay)

	# SpellCreatureSwap を初期化
	if not sph.spell_systems.spell_creature_swap and sph.board_system and sph.player_system and sph.card_system:
		sph.spell_systems.spell_creature_swap = SpellCreatureSwap.new(sph.board_system, sph.player_system, sph.card_system, sph)

	# SpellCreatureReturn を初期化
	if not sph.spell_systems.spell_creature_return and sph.board_system and sph.player_system and sph.card_system:
		sph.spell_systems.spell_creature_return = SpellCreatureReturn.new(sph.board_system, sph.player_system, sph.card_system, sph)

	# SpellCreaturePlace を初期化
	if not sph.spell_systems.spell_creature_place:
		sph.spell_systems.spell_creature_place = SpellCreaturePlace.new()

	# SpellDrawにSpellCreaturePlace参照を設定
	if sph.spell_draw and sph.spell_systems.spell_creature_place:
		sph.spell_draw.set_spell_creature_place(sph.spell_systems.spell_creature_place)

	# SpellBorrow を初期化
	if not sph.spell_systems.spell_borrow and sph.board_system and sph.player_system and sph.card_system:
		sph.spell_systems.spell_borrow = SpellBorrow.new(sph.board_system, sph.player_system, sph.card_system, sph)

	# SpellTransform を初期化
	if not sph.spell_systems.spell_transform and sph.board_system and sph.player_system and sph.card_system:
		sph.spell_systems.spell_transform = SpellTransform.new(sph.board_system, sph.player_system, sph.card_system, sph)

	# SpellPurify を初期化
	if not sph.spell_systems.spell_purify and sph.board_system and sph.creature_manager and sph.player_system and sph.game_flow_manager:
		sph.spell_systems.spell_purify = SpellPurify.new(sph.board_system, sph.creature_manager, sph.player_system, sph.game_flow_manager)

	# CardSacrificeHelper を初期化（スペル合成・クリーチャー合成共通）
	if not sph.spell_systems.card_sacrifice_helper and sph.card_system and sph.player_system:
		sph.spell_systems.card_sacrifice_helper = CardSacrificeHelper.new(sph.card_system, sph.player_system, sph.ui_manager)

	# SpellSynthesis を初期化
	if not sph.spell_systems.spell_synthesis and sph.spell_systems.card_sacrifice_helper:
		sph.spell_systems.spell_synthesis = SpellSynthesis.new(sph.spell_systems.card_sacrifice_helper)

	# SpellPhaseUIManager を初期化（手札更新時のボタン位置更新用）
	_initialize_spell_phase_ui(sph)

	# hand_displayのシグナルに接続（カードドロー後のボタン位置更新用）
	if sph.hand_display:
		if not sph.hand_display.hand_updated.is_connected(sph._on_hand_updated_for_buttons):
			sph.hand_display.hand_updated.connect(sph._on_hand_updated_for_buttons)

	# 発動通知UIを初期化
	_initialize_spell_cast_notification_ui(sph)

	# SpellDamageに通知UIを設定
	if sph.spell_systems and sph.spell_systems.spell_damage and sph.spell_cast_notification_ui:
		sph.spell_systems.spell_damage.set_notification_ui(sph.spell_cast_notification_ui)

	# カード選択ハンドラーを初期化
	_initialize_card_selection_handler(sph)

	# CPUTurnProcessorを取得（BoardSystem3Dの子ノードから）
	if sph.board_system and not sph.spell_systems.cpu_turn_processor:
		sph.spell_systems.cpu_turn_processor = sph.board_system.get_node_or_null("CPUTurnProcessor")


## Step 3: 6個のハンドラーを初期化
func _initialize_handlers(sph) -> void:
	# SpellTargetSelectionHandler を初期化（Phase 6-1）
	sph._initialize_spell_target_selection_handler()

	# SpellConfirmationHandler を初期化（Phase 6-2）
	sph._initialize_spell_confirmation_handler()

	# SpellUIController を初期化（Phase 7-1）
	sph._initialize_spell_ui_controller()

	# MysticArtsHandler を初期化（Phase 8-1）
	sph._initialize_mystic_arts_handler()

	# SpellStateHandler と SpellFlowHandler を初期化（Phase 3-A Day 9-12）
	sph._initialize_spell_state_and_flow()


## Step 4: CPU AI を初期化
func _initialize_cpu_ai(sph, game_stats: Dictionary) -> void:
	# CPU AI共有コンテキストを初期化
	sph._initialize_cpu_context(sph.game_flow_manager)

	# CPU スペル/アルカナアーツ AI を初期化
	if not sph.cpu_spell_ai:
		sph.cpu_spell_ai = CPUSpellAI.new()
		sph.cpu_spell_ai.initialize(sph._cpu_context)
		sph.cpu_spell_ai.set_hand_utils(sph.cpu_hand_utils)
		sph.cpu_spell_ai.set_battle_ai(sph._cpu_battle_ai)
		# SpellSynthesisを設定（犠牲カード選択用）
		if sph.spell_systems and sph.spell_systems.spell_synthesis:
			sph.cpu_spell_ai.set_spell_synthesis(sph.spell_systems.spell_synthesis)
		# CPUMovementEvaluatorを設定（ホーリーワード判断用）
		if sph.cpu_movement_evaluator:
			sph.cpu_spell_ai.set_movement_evaluator(sph.cpu_movement_evaluator)
		# === game_stats直接参照を設定（チェーンアクセス解消） ===
		if sph.game_flow_manager and sph.game_flow_manager.has_method("get"):
			sph.cpu_spell_ai.set_game_stats(sph.game_flow_manager.game_stats)

	if not sph.cpu_mystic_arts_ai:
		sph.cpu_mystic_arts_ai = CPUMysticArtsAI.new()
		sph.cpu_mystic_arts_ai.initialize(sph._cpu_context)
		sph.cpu_mystic_arts_ai.set_hand_utils(sph.cpu_hand_utils)
		sph.cpu_mystic_arts_ai.set_battle_ai(sph._cpu_battle_ai)
		# === game_stats直接参照を設定（チェーンアクセス解消） ===
		if sph.game_flow_manager and sph.game_flow_manager.has_method("get"):
			sph.cpu_mystic_arts_ai.set_game_stats(sph.game_flow_manager.game_stats)

	# SpellEffectExecutor を初期化
	if not sph.spell_effect_executor:
		sph.spell_effect_executor = SpellEffectExecutor.new(sph)


## === 内部ヘルパーメソッド ===

## SpellPhaseUIManager を初期化（内部）
func _initialize_spell_phase_ui(sph) -> void:
	if sph.spell_ui_controller:
		sph.spell_ui_controller.initialize_spell_phase_ui()


## 発動通知UIを初期化（内部）
func _initialize_spell_cast_notification_ui(sph) -> void:
	if sph.spell_confirmation_handler:
		sph.spell_confirmation_handler.initialize_spell_cast_notification_ui()
		sph.spell_cast_notification_ui = sph.spell_confirmation_handler.get_spell_cast_notification_ui()


## カード選択ハンドラーを初期化（内部）
func _initialize_card_selection_handler(sph) -> void:
	if sph.card_selection_handler:
		return

	sph.card_selection_handler = CardSelectionHandler.new()
	sph.card_selection_handler.name = "CardSelectionHandler"
	sph.add_child(sph.card_selection_handler)

	# 参照を設定
	sph.card_selection_handler.setup(
		sph.ui_manager,
		sph.player_system,
		sph.card_system,
		sph,
		sph.spell_phase_ui_manager
	)

	# SpellDrawにもcard_selection_handlerを設定
	if sph.spell_draw:
		sph.spell_draw.set_card_selection_handler(sph.card_selection_handler)

	# 選択完了シグナルを接続（重複接続防止）
	if not sph.card_selection_handler.selection_completed.is_connected(sph._on_card_selection_completed):
		sph.card_selection_handler.selection_completed.connect(sph._on_card_selection_completed)
