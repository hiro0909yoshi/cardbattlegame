# SpellFlowHandler - スペルフェーズのフロー制御を担当
extends RefCounted
class_name SpellFlowHandler

## === UI Signal 定義（Phase 6-A: UI層分離） ===
signal spell_ui_toast_requested(message: String)
signal spell_ui_action_prompt_shown(text: String)
signal spell_ui_action_prompt_hidden()
signal spell_ui_info_panels_hidden()
signal spell_ui_card_pending_cleared()
signal spell_ui_navigation_enabled(confirm_cb: Callable, back_cb: Callable)
signal spell_ui_navigation_disabled()
signal spell_ui_actions_cleared()
signal spell_ui_card_filter_set(filter: String)
signal spell_ui_hand_updated(player_id: int)
signal spell_ui_card_selection_deactivated()

## ===== 依存関係 =====
var _spell_state: SpellStateHandler = null  # 状態管理（必須）
var _spell_phase_handler = null  # 親ハンドラー（シグナル発火、他ハンドラー参照用）

## ===== システム参照 =====
var _game_flow_manager = null
var _spell_container: SpellSystemContainer = null

## === Phase A-3a: is_cpu_player Callable 化 ===
var _is_cpu_player_cb: Callable = Callable()
var _board_system = null
var _player_system = null
var _card_system = null
var _game_3d_ref = null

## ===== スペル処理用参照 =====
var _spell_cost_modifier = null
var _spell_synthesis = null
var _card_sacrifice_helper = null
var _spell_effect_executor = null
var _spell_target_selection_handler = null
var _target_selection_helper = null

## ===== 初期化 =====

func _init(spell_state: SpellStateHandler) -> void:
	_spell_state = spell_state

## 参照を設定（SpellPhaseHandlerから注入）
func setup(
	spell_phase_handler,
	game_flow_manager,
	board_system,
	player_system,
	card_system,
	game_3d_ref,
	spell_cost_modifier = null,
	spell_synthesis = null,
	card_sacrifice_helper = null,
	spell_effect_executor = null,
	spell_target_selection_handler = null,
	target_selection_helper = null
) -> void:
	_spell_phase_handler = spell_phase_handler
	_game_flow_manager = game_flow_manager
	_board_system = board_system
	_player_system = player_system
	_card_system = card_system
	_game_3d_ref = game_3d_ref
	_spell_cost_modifier = spell_cost_modifier
	_spell_synthesis = spell_synthesis
	_card_sacrifice_helper = card_sacrifice_helper
	_spell_effect_executor = spell_effect_executor
	_spell_target_selection_handler = spell_target_selection_handler
	_target_selection_helper = target_selection_helper

## GFM依存のCallable一括注入（Phase A-3a）
func inject_callbacks(
	is_cpu_player_cb: Callable,
) -> void:
	_is_cpu_player_cb = is_cpu_player_cb

## 直接参照の一括注入（Phase A-3b: spell_container直接注入）
func inject_dependencies(spell_container: SpellSystemContainer) -> void:
	_spell_container = spell_container
	assert(_spell_container != null, "[SpellFlowHandler] spell_container must not be null")

## ===== ヘルパーメソッド =====

## CPU判定ヘルパー（Phase A-3a）
func _is_cpu_player(player_id: int) -> bool:
	return _is_cpu_player_cb.call(player_id) if _is_cpu_player_cb.is_valid() else false

## スペルコストを支払えるか
func _can_afford_spell(spell_card: Dictionary) -> bool:
	if not _player_system:
		return false

	var magic = _player_system.get_magic(_spell_state.current_player_id)
	var cost = _get_spell_cost(spell_card)

	return magic >= cost

## スペルコストを取得（ウェイストワールド対応）
func _get_spell_cost(spell_card: Dictionary) -> int:
	var cost_data = spell_card.get("cost", {})
	if cost_data == null:
		cost_data = {}

	var base_cost = 0
	if typeof(cost_data) == TYPE_DICTIONARY:
		base_cost = cost_data.get("ep", 0)

	# ウェイストワールド（世界呪い）でコスト倍率を適用
	if _spell_cost_modifier:
		return _spell_cost_modifier.get_modified_cost(_spell_state.current_player_id, spell_card)

	return base_cost

## 使用者のクリーチャー数をカウント
func _count_own_creatures(player_id: int) -> int:
	if not _board_system:
		return 0

	var count = 0
	for tile_index in _board_system.tile_nodes.keys():
		var tile = _board_system.tile_nodes[tile_index]
		if tile and tile.owner_id == player_id and not tile.creature_data.is_empty():
			count += 1
	return count

## ===== メインフローロジック =====

## スペルを使用（166行のメインロジック）
func use_spell(spell_card: Dictionary):
	# 外部スペルモードでない場合のみ状態チェック
	if not _spell_state.is_in_external_spell_mode():
		if _spell_state.current_state != SpellStateHandler.State.WAITING_FOR_INPUT:
			return

		if _spell_state.spell_used_this_turn:
			return

		if not _can_afford_spell(spell_card):
			# EPが足りない場合はエラー表示して戻る
			var needed_cost = _get_spell_cost(spell_card)
			spell_ui_toast_requested.emit("EPが足りません（必要: %dEP）" % needed_cost)
			# インフォパネルを閉じる
			spell_ui_info_panels_hidden.emit()
			# カードのホバー状態を解除
			var card_script = load("res://scripts/card.gd")
			if card_script.currently_selected_card and card_script.currently_selected_card.has_method("deselect_card"):
				card_script.currently_selected_card.deselect_card()
			# カード選択状態をリセット
			spell_ui_card_pending_cleared.emit()
			# 入力ロックを解除
			if _game_flow_manager and _game_flow_manager.has_method("unlock_input"):
				_game_flow_manager.unlock_input()
			# スペル選択画面に戻る
			return_to_spell_selection()
			return

	_spell_state.set_spell_card(spell_card)
	_spell_state.set_spell_used_this_turn(true)

	# アクション指示パネルを閉じる
	spell_ui_action_prompt_hidden.emit()

	# コストを支払う（常に実行）
	var cost = _get_spell_cost(spell_card)

	if _player_system:
		_player_system.add_magic(_spell_state.current_player_id, -cost)

	# ライフフォース呪いチェック（スペル無効化）
	if _spell_cost_modifier:
		var nullify_result = _spell_cost_modifier.check_spell_nullify(_spell_state.current_player_id)
		if nullify_result.get("nullified", false):
			# スペルは無効化 → カードを捨て札へ
			spell_ui_action_prompt_shown.emit(nullify_result.get("message", "スペル無効化"))
			# 手札からカードを除去（捨て札へ）
			if _player_system:
				_player_system.remove_card_from_hand(_spell_state.current_player_id, _spell_state.get_spell_card())
			await _get_tree_ref().create_timer(1.5).timeout
			_spell_state.clear_spell_card()
			_spell_state.transition_to(SpellStateHandler.State.WAITING_FOR_INPUT)
			return

	# カード犠牲処理（スペル合成用）
	# マジックタイルモードではカード犠牲をスキップ（手札から使用していないため）
	var is_synthesized = false
	_spell_state.clear_pending_sacrifice_card()
	var disable_sacrifice = _is_card_sacrifice_disabled() or _spell_state.is_in_magic_tile_mode()
	if _spell_synthesis and _spell_synthesis.requires_sacrifice(spell_card) and not disable_sacrifice:
		# 手札選択UIを表示
		if _card_sacrifice_helper:
			var sacrifice_card = await _card_sacrifice_helper.show_hand_selection(
				_spell_state.current_player_id, "", "犠牲にするカードを選択"
			)

			if sacrifice_card.is_empty():
				# キャンセル時はコストを返却してスペルキャンセル
				if _player_system:
					_player_system.add_magic(_spell_state.current_player_id, cost)
				_spell_state.clear_spell_card()
				_spell_state.set_spell_used_this_turn(false)
				_spell_state.transition_to(SpellStateHandler.State.WAITING_FOR_INPUT)
				# ホバー状態を解除
				var card_script = load("res://scripts/card.gd")
				if card_script.currently_selected_card and card_script.currently_selected_card.has_method("deselect_card"):
					card_script.currently_selected_card.deselect_card()
				# スペル選択UIを再表示
				if _player_system and _card_system:
					var current_player = _player_system.get_current_player()
					var hand_data = _card_system.get_all_cards_for_player(_spell_state.current_player_id)
					_show_spell_selection_ui(hand_data, current_player.magic_power)
				return

			# 合成条件判定
			is_synthesized = _spell_synthesis.check_condition(spell_card, sacrifice_card)
			if is_synthesized:
				# カードを一時保存（スペル実行確定時に消費）
				_spell_state.set_pending_sacrifice_card(sacrifice_card)

	# 合成成立時はeffect_parsedを書き換え
	var parsed = spell_card.get("effect_parsed", {})
	if is_synthesized and _spell_synthesis:
		parsed = _spell_synthesis.apply_overrides(spell_card, true)
		spell_card["effect_parsed"] = parsed
		spell_card["is_synthesized"] = true
	var target_type = parsed.get("target_type", "")
	var target_filter = parsed.get("target_filter", "")
	var target_info = parsed.get("target_info", {}).duplicate()
	var effects = parsed.get("effects", [])

	# HP効果無効チェック用にaffects_hpをtarget_infoにコピー
	if parsed.get("affects_hp", false):
		target_info["affects_hp"] = true

	# リリーフ（swap_board_creatures）: 使用時点で2体未満なら弾く
	for effect in effects:
		if effect.get("effect_type") == "swap_board_creatures":
			var own_creature_count = _count_own_creatures(_spell_state.current_player_id)
			if own_creature_count < 2:
				spell_ui_toast_requested.emit("対象がいません")
				await _get_tree_ref().create_timer(1.0).timeout
				cancel_spell()
				return

	# target_filter または target_type が "self" の場合 → 確認フェーズへ
	if target_filter == "self" or target_type == "self":
		var target_data = {"type": "player", "player_id": _spell_state.current_player_id}
		_start_confirmation_phase("self", target_info, target_data)
	elif target_type == "all_creatures":
		# 全クリーチャー対象（条件付き）→ 確認フェーズへ
		var target_data = {"type": "all_creatures"}
		_start_confirmation_phase("all_creatures", target_info, target_data)
	elif target_type == "all_players":
		# 全プレイヤー対象（カオスパニック等）→ 確認フェーズへ
		var target_data = {"type": "all_players"}
		_start_confirmation_phase("all_players", target_info, target_data)
	elif target_type == "world":
		# 世界呪い → 確認フェーズへ
		var target_data = {"type": "world"}
		_start_confirmation_phase("world", target_info, target_data)
	elif not target_type.is_empty() and target_type != "none":
		# 対象選択が必要
		_spell_state.transition_to(SpellStateHandler.State.SELECTING_TARGET)
		if _spell_phase_handler:
			_spell_phase_handler.target_selection_required.emit(spell_card, target_type)

		# target_filterをtarget_infoに追加（get_valid_targetsで使用）
		if not target_filter.is_empty():
			target_info["target_filter"] = target_filter

		# 対象選択UIを表示
		var has_targets = await _show_target_selection_ui(target_type, target_info)
		if not has_targets:
			# 対象がいない場合
			if _spell_state.is_in_external_spell_mode():
				_spell_state.set_external_spell_no_target(true)  # 対象不在フラグ
			cancel_spell()
			return
	else:
		# target_type が空または "none" の場合 → 確認フェーズへ
		var target_data = {"type": "none"}
		_start_confirmation_phase("none", target_info, target_data)

## スペルをキャンセル（対象選択からスペル選択に戻る）
func cancel_spell():
	# コストを返却
	var cost_data = _spell_state.get_spell_card().get("cost", {})
	if cost_data == null:
		cost_data = {}

	var cost = 0
	if typeof(cost_data) == TYPE_DICTIONARY:
		cost = cost_data.get("ep", 0)

	if _player_system and cost > 0:
		_player_system.add_magic(_spell_state.current_player_id, cost)

	_spell_state.clear_spell_card()
	_spell_state.set_spell_used_this_turn(false)

	# 犠牲カードをクリア（消費せずに破棄）
	if not _spell_state.get_pending_sacrifice_card().is_empty():
		_spell_state.clear_pending_sacrifice_card()

	# 確認フェーズ変数をクリア
	_spell_state.clear_confirmation_state()

	# 外部スペルモードの場合
	if _spell_state.is_in_external_spell_mode():
		_spell_state.set_external_spell_cancelled(true)  # キャンセルフラグを立てる

		# 対象選択フェーズを抜ける共通処理
		_exit_target_selection_phase()

		_spell_state.transition_to(SpellStateHandler.State.INACTIVE)
		# シグナルを遅延発火（use_spell()が完了してからawaitで受け取れるようにする）
		if _spell_phase_handler:
			_spell_phase_handler.call_deferred("emit_signal", "external_spell_finished")
		return

	_spell_state.transition_to(SpellStateHandler.State.WAITING_FOR_INPUT)

	# スペル選択UIを再表示
	return_to_spell_selection()

## スペル選択画面に戻る（UI再表示 + ナビゲーション再設定）
func return_to_spell_selection():
	# 対象選択フェーズを抜ける共通処理
	_exit_target_selection_phase()

	# UIを更新してスペル選択モードに戻す
	_update_spell_phase_ui()

	# アクション指示パネルで表示
	spell_ui_action_prompt_shown.emit("スペルを使用するか、ダイスを振ってください")

	# グローバルナビゲーションをスペル選択用に再設定
	_setup_spell_selection_navigation()

	# アルカナアーツボタンを再表示
	_show_spell_phase_buttons()

## ===== スペル効果実行 =====

## スペル効果を実行（Strategy パターンで試行、フォールバック対応）
func execute_spell_effect(spell_card: Dictionary, target_data: Dictionary):

	# 犠牲カードを消費（スペル実行確定時）
	if not _spell_state.get_pending_sacrifice_card().is_empty() and _card_sacrifice_helper:
		_card_sacrifice_helper.consume_card(_spell_state.current_player_id, _spell_state.get_pending_sacrifice_card())
		_spell_state.clear_pending_sacrifice_card()

	# Strategy パターンで実行を試行（Day 1-2 試験的実装）
	var strategy_executed = await _try_execute_spell_with_strategy(spell_card, target_data)

	if strategy_executed:
		# Strategy により実行完了 → 背景処理完了を待機してからフェーズ完了
		await _get_tree_ref().create_timer(0.5).timeout
		complete_spell_phase()
		return

	# フォールバック: 従来のロジックで実行
	if _spell_effect_executor:
		# SpellEffectExecutor は内部で complete_spell_phase() を呼ぶ
		# → フォールバック完了時には既に complete_spell_phase() が呼ばれている
		await _spell_effect_executor.execute_spell_effect(spell_card, target_data)

	# NOTE: 戻ったときには complete_spell_phase() は既に呼び出し済み
	# ここで重複呼び出しを防ぐため、何もしない

## Strategy パターンで実行を試行
func _try_execute_spell_with_strategy(spell_card: Dictionary, target_data: Dictionary) -> bool:
	var spell_id = spell_card.get("id", -1)

	var strategy = SpellStrategyFactory.create_strategy(spell_id)

	# Strategy が未実装の場合は false を返す（フォールバック用）
	if not strategy:
		return false


	# Strategy が実装されている場合
	var context = _build_strategy_context(spell_card, target_data)

	# バリデーション
	if not strategy.validate(context):
		return false

	# 効果実行
	@warning_ignore("redundant_await")  # Strategy.execute() は内部で await を含むため必須
	await strategy.execute(context)
	return true

## スペル戦略実行用のコンテキストを構築（Strategy パターン用）
func _build_strategy_context(spell_card: Dictionary = {}, target_data: Dictionary = {}) -> Dictionary:
	var spell_container = _spell_container
	var spell_systems = _spell_phase_handler.spell_systems if _spell_phase_handler else null

	return {
		"spell_card": spell_card if not spell_card.is_empty() else _spell_state.get_spell_card(),
		"spell_id": spell_card.get("id", _spell_state.get_spell_card().get("id", -1)),
		"spell_phase_handler": _spell_phase_handler,
		"target_data": target_data,
		"current_player_id": _spell_state.current_player_id,
		"board_system": _board_system,
		"player_system": _player_system,
		"card_system": _card_system,
		"spell_container": spell_container,
		"spell_effect_executor": _spell_effect_executor,
		# === 直接参照（SpellEffectExecutor と同様） ===
		"spell_draw": spell_container.spell_draw if spell_container else null,
		"spell_dice": spell_container.spell_dice if spell_container else null,
		"spell_land": spell_container.spell_land if spell_container else null,
		"spell_magic": spell_container.spell_magic if spell_container else null,
		"spell_curse": spell_container.spell_curse if spell_container else null,
		"spell_curse_stat": spell_container.spell_curse_stat if spell_container else null,
		"spell_curse_toll": spell_container.spell_curse_toll if spell_container else null,
		"spell_cost_modifier": spell_container.spell_cost_modifier if spell_container else null,
		"spell_player_move": spell_container.spell_player_move if spell_container else null,
		"spell_creature_move": spell_systems.spell_creature_move if spell_systems else null,
		"spell_damage": spell_systems.spell_damage if spell_systems else null,
		"spell_purify": spell_systems.spell_purify if spell_systems else null,
		"spell_creature_place": spell_systems.spell_creature_place if spell_systems else null,
		"spell_creature_swap": spell_systems.spell_creature_swap if spell_systems else null,
		"spell_borrow": spell_systems.spell_borrow if spell_systems else null,
		"spell_transform": spell_systems.spell_transform if spell_systems else null,
		"spell_creature_return": spell_systems.spell_creature_return if spell_systems else null,
	}

## ===== 確認フェーズ =====

## 確認フェーズを開始
func _start_confirmation_phase(target_type: String, target_info: Dictionary, target_data: Dictionary):
	_spell_state.transition_to(SpellStateHandler.State.CONFIRMING_EFFECT)
	_spell_state.set_confirmation_state(target_type, target_info, target_data)

	# 対象をハイライト表示
	var target_count = TargetSelectionHelper.show_confirmation_highlights(_spell_phase_handler, target_type, target_info)

	# 対象がいない場合（all_creaturesで防魔等で0体）
	if target_type == "all_creatures" and target_count == 0:
		spell_ui_toast_requested.emit("対象となるクリーチャーがいません")
		await _get_tree_ref().create_timer(1.0).timeout
		cancel_spell()
		return

	# CPUの場合は自動で確定
	if _is_cpu_player(_spell_state.current_player_id):
		await _get_tree_ref().create_timer(0.3).timeout  # 少し待つ
		_confirm_spell_effect()
		return

	# プレイヤーの場合：アクション指示パネルで確認テキストを表示
	var confirmation_text = TargetSelectionHelper.get_confirmation_text(target_type, target_count)
	spell_ui_action_prompt_shown.emit(confirmation_text)

	# ナビゲーションボタン設定（決定/戻る）
	spell_ui_navigation_enabled.emit(
		func(): _confirm_spell_effect(),  # 決定
		func(): _cancel_confirmation()    # 戻る
	)

## 確認フェーズ: 効果発動を確定
func _confirm_spell_effect():
	if _spell_state.current_state != SpellStateHandler.State.CONFIRMING_EFFECT:
		return

	# ハイライトとマーカーをクリア
	TargetSelectionHelper.clear_all_highlights(_spell_phase_handler)
	TargetSelectionHelper.hide_selection_marker(_spell_phase_handler)
	TargetSelectionHelper.clear_confirmation_markers(_spell_phase_handler)

	# ナビゲーションを無効化
	spell_ui_navigation_disabled.emit()

	# 効果を実行
	var confirmation_state = _spell_state.get_confirmation_state()
	var target_type = confirmation_state.get("target_type", "")
	var target_info = confirmation_state.get("target_info", {})
	var target_data = confirmation_state.get("target_data", {})

	# 確認フェーズ変数をクリア
	_spell_state.clear_confirmation_state()

	# 対象タイプに応じて実行
	match target_type:
		"self":
			execute_spell_effect(_spell_state.get_spell_card(), target_data)
		"all_creatures":
			_execute_spell_on_all_creatures(_spell_state.get_spell_card(), target_info)
		"all_players":
			execute_spell_effect(_spell_state.get_spell_card(), target_data)
		"world":
			execute_spell_effect(_spell_state.get_spell_card(), target_data)
		"none", _:
			execute_spell_effect(_spell_state.get_spell_card(), target_data)

## 確認フェーズ: キャンセル
func _cancel_confirmation():
	if _spell_state.current_state != SpellStateHandler.State.CONFIRMING_EFFECT:
		return

	# ハイライトとマーカーをクリア
	TargetSelectionHelper.clear_all_highlights(_spell_phase_handler)
	TargetSelectionHelper.hide_selection_marker(_spell_phase_handler)
	TargetSelectionHelper.clear_confirmation_markers(_spell_phase_handler)

	# 確認フェーズ変数をクリア
	_spell_state.clear_confirmation_state()

	# スペルをキャンセル
	cancel_spell()

## ===== サポートメソッド =====

## スペルをパス（×ボタンで呼ばれる）
## auto_roll: trueの場合、サイコロを自動で振る
func pass_spell(auto_roll: bool = true):
	if _spell_phase_handler:
		_spell_phase_handler.spell_passed.emit()
	complete_spell_phase()

	# サイコロを自動で振る（×ボタン押下時）
	if auto_roll and _game_flow_manager:
		# フェーズ遷移後に呼ぶ必要があるためcall_deferred使用
		_game_flow_manager.roll_dice.call_deferred()

## スペルフェーズ完了
func complete_spell_phase():
	if _spell_state.current_state == SpellStateHandler.State.INACTIVE:
		# 既に INACTIVE でもシグナルは emit する（GameFlowManager が await している）
		if _spell_phase_handler:
			_spell_phase_handler.spell_phase_completed.emit()
		return

	# 外部スペルモードの場合（マジックタイル等から呼ばれた場合）
	if _spell_state.is_in_external_spell_mode():
		_spell_state.transition_to(SpellStateHandler.State.INACTIVE)
		# スペル用のナビゲーションのみクリア（ドミニオボタン等の特殊ボタンは維持）
		# _hide_spell_phase_buttons()は呼ばない（外部モードではミスティックボタン未設定、
		# 代わりにドミニオボタンが表示されており消してはいけない）
		spell_ui_actions_cleared.emit()
		if _spell_phase_handler:
			_spell_phase_handler.external_spell_finished.emit()
		return

	_spell_state.transition_to(SpellStateHandler.State.INACTIVE)
	_spell_state.clear_spell_card()

	# アクション指示パネルを閉じる
	spell_ui_action_prompt_hidden.emit()

	# スペルフェーズのフィルターをクリア
	spell_ui_card_filter_set.emit("")
	# 手札表示を更新してグレーアウトを解除
	if _player_system:
		var current_player = _player_system.get_current_player()
		if current_player:
			spell_ui_hand_updated.emit(current_player.id)

	# カード選択UIを非アクティブ化
	spell_ui_card_selection_deactivated.emit()

	# スペルフェーズボタンを非表示
	_hide_spell_phase_buttons()

	# グローバルナビゲーションをクリア
	_clear_spell_navigation()

	# カメラを追従モードに戻す（位置は移動処理で自然に戻る）
	if _board_system:
		_board_system.enable_follow_camera()

	if _spell_phase_handler:
		_spell_phase_handler.spell_phase_completed.emit()

	# 次のフェーズ（ダイスフェーズ）への遷移は GameFlowManager が行う

## 外部スペルを実行
func execute_external_spell(spell_card: Dictionary, player_id: int, from_magic_tile: bool = false) -> Dictionary:

	# 外部スペルモードを有効化
	_spell_state.set_external_spell_mode(true, from_magic_tile)
	_spell_state.set_skip_dice_phase(false)  # リセット

	# 現在のプレイヤーIDを保存して設定
	var original_player_id = _spell_state.current_player_id
	var original_state = _spell_state.current_state
	_spell_state.set_current_player_id(player_id)
	_spell_state.transition_to(SpellStateHandler.State.WAITING_FOR_INPUT)

	# use_spellを呼び出す（通常のスペルフェーズと同じ処理）
	await use_spell(spell_card)

	# 完了を待つ（対象選択がある場合はUIが表示され、選択後に進む）
	if _spell_phase_handler:
		await _spell_phase_handler.external_spell_finished

	# 結果を保存
	var external_result = _spell_state.get_external_spell_result()
	var was_cancelled = external_result.get("cancelled", false)
	var was_no_target = external_result.get("no_target", false)
	var was_warped = _spell_state.should_skip_dice_phase()  # ワープしたかどうか

	# 外部スペルモードを無効化
	_spell_state.set_external_spell_mode(false)
	_spell_state.set_skip_dice_phase(false)
	_spell_state.set_current_player_id(original_player_id)
	_spell_state.transition_to(original_state)
	_spell_state.clear_spell_card()
	_spell_state.set_spell_used_this_turn(false)  # 外部スペルはターン制限に影響しない


	# Dictionary形式で結果を返す
	var result_status = "success"
	if was_no_target:
		result_status = "no_target"
	elif was_cancelled:
		result_status = "cancelled"

	return {
		"status": result_status,
		"warped": was_warped
	}

## ===== 内部UI制御メソッド =====

## 対象選択UIを表示
func _show_target_selection_ui(target_type: String, target_info: Dictionary) -> bool:
	if _spell_target_selection_handler:
		_spell_state.transition_to(SpellStateHandler.State.SELECTING_TARGET)
		return await _spell_target_selection_handler.show_target_selection_ui(target_type, target_info)

	# フォールバック（ハンドラーがない場合）
	push_error("[SpellFlowHandler] spell_target_selection_handler が初期化されていません")
	return false

## 対象選択フェーズを抜けるときの共通処理
func _exit_target_selection_phase():
	if _spell_target_selection_handler:
		_spell_target_selection_handler._exit_target_selection_phase()
	else:
		push_error("[SpellFlowHandler] spell_target_selection_handler が初期化されていません")

## スペルフェーズUIを更新
func _update_spell_phase_ui():
	if _spell_phase_handler and _spell_phase_handler.spell_ui_manager:
		_spell_phase_handler.spell_ui_manager.update_spell_phase_ui()
	else:
		push_error("[SpellFlowHandler] spell_ui_manager が初期化されていません")

## スペル選択UIを表示
func _show_spell_selection_ui(_hand_data: Array, _available_magic: int):
	if _spell_phase_handler and _spell_phase_handler.spell_ui_manager:
		_spell_phase_handler.spell_ui_manager.show_spell_selection_ui(_hand_data, _available_magic)
	else:
		push_error("[SpellFlowHandler] spell_ui_manager が初期化されていません")

## スペルフェーズ開始時にボタンを表示
func _show_spell_phase_buttons():
	if _spell_phase_handler and _spell_phase_handler.spell_ui_manager:
		_spell_phase_handler.spell_ui_manager.show_spell_phase_buttons()
	else:
		push_error("[SpellFlowHandler] spell_ui_manager が初期化されていません")

## スペルフェーズ終了時にボタンを非表示
func _hide_spell_phase_buttons():
	if _spell_phase_handler and _spell_phase_handler.spell_ui_manager:
		_spell_phase_handler.spell_ui_manager.hide_spell_phase_buttons()
	else:
		push_error("[SpellFlowHandler] spell_ui_manager が初期化されていません")

## スペル選択時のナビゲーション設定（決定 = スペルを使わない → サイコロ）
func _setup_spell_selection_navigation():
	spell_ui_navigation_enabled.emit(
		func(): pass_spell(),  # 決定 = スペルを使わない → サイコロを振る
		Callable()             # 戻るなし
	)

## ナビゲーションをクリア
func _clear_spell_navigation() -> void:
	if _spell_target_selection_handler:
		_spell_target_selection_handler._clear_spell_navigation()
	else:
		spell_ui_navigation_disabled.emit()

## 全クリーチャー対象スペルを実行（SpellEffectExecutorに委譲）
func _execute_spell_on_all_creatures(spell_card: Dictionary, target_info: Dictionary):
	if _spell_effect_executor:
		await _spell_effect_executor.execute_spell_on_all_creatures(spell_card, target_info)

## カード犠牲が無効化されているか（TileActionProcessorから取得）
func _is_card_sacrifice_disabled() -> bool:
	if _board_system and _board_system.tile_action_processor:
		return _board_system.tile_action_processor.debug_disable_card_sacrifice if _board_system and _board_system.tile_action_processor else false
	return false

## ツリー参照を取得（RefCountedなので直接get_treeは使えない）
func _get_tree_ref():
	if _spell_phase_handler:
		return _spell_phase_handler.get_tree()
	return null
