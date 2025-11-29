# SpellPhaseHandler - スペルフェーズの処理を担当
extends Node
class_name SpellPhaseHandler

## シグナル
signal spell_phase_started()
signal spell_phase_completed()
signal spell_passed()
signal spell_used(spell_card: Dictionary)
signal target_selection_required(spell_card: Dictionary, target_type: String)

## 状態
enum State {
	INACTIVE,
	WAITING_FOR_INPUT,  # スペル選択またはダイス待ち
	SELECTING_TARGET,    # 対象選択中
	EXECUTING_EFFECT     # 効果実行中
}

var current_state: State = State.INACTIVE
var current_player_id: int = -1
var selected_spell_card: Dictionary = {}
var spell_used_this_turn: bool = false  # 1ターン1回制限

## カード選択ハンドラー（敵手札選択、デッキカード選択）
var card_selection_handler: CardSelectionHandler = null

## スペル失敗フラグ
var spell_failed: bool = false  # 復帰[ブック]フラグ（条件不成立でデッキに戻る）

## デバッグ設定
## 密命カードのテストを一時的に無効化
## true: 密命カードを通常カードとして扱う（失敗判定・復帰[ブック]をスキップ）
## false: 通常通り密命として動作
## 使い方: GameFlowManagerのセットアップ後に設定
##   spell_phase_handler.debug_disable_secret_cards = true
var debug_disable_secret_cards: bool = false

## ターゲット選択（領地コマンドと同じ構造）
var available_targets: Array = []
var current_target_index: int = 0
var selection_marker: MeshInstance3D = null
var is_tile_selection_mode: bool = false  # タイル選択モード（SpellCreatureMove用）

## 参照
var ui_manager = null
var game_flow_manager = null
var card_system = null
var player_system = null
var board_system = null
var creature_manager = null
var spell_mystic_arts = null  # 秘術システム
var spell_phase_ui_manager = null  # UIボタン管理
var spell_cast_notification_ui = null  # 発動通知UI
var spell_damage: SpellDamage = null  # ダメージ・回復処理
var spell_creature_move: SpellCreatureMove = null  # クリーチャー移動
var spell_creature_swap: SpellCreatureSwap = null  # クリーチャー交換
var spell_creature_return: SpellCreatureReturn = null  # クリーチャー手札戻し
var cpu_turn_processor: CPUTurnProcessor = null  # CPU処理

func _ready():
	pass

func _process(delta):
	# 選択マーカーを回転
	TargetSelectionHelper.rotate_selection_marker(self, delta)

## 初期化
func initialize(ui_mgr, flow_mgr, c_system = null, p_system = null, b_system = null):
	ui_manager = ui_mgr
	game_flow_manager = flow_mgr
	card_system = c_system if c_system else (flow_mgr.card_system if flow_mgr else null)
	player_system = p_system if p_system else (flow_mgr.player_system if flow_mgr else null)
	board_system = b_system if b_system else (flow_mgr.board_system_3d if flow_mgr else null)
	
	# CreatureManagerを取得
	if board_system:
		creature_manager = board_system.get_node_or_null("CreatureManager")
	
	# SpellMysticArts を初期化
	if not spell_mystic_arts and board_system and player_system and card_system:
		spell_mystic_arts = SpellMysticArts.new(
			board_system,
			player_system,
			card_system,
			self
		)
		# シグナル接続
		spell_mystic_arts.mystic_phase_completed.connect(_on_mystic_phase_completed)
		spell_mystic_arts.mystic_art_used.connect(_on_mystic_art_used)
		spell_mystic_arts.target_selection_requested.connect(_on_mystic_target_selection_requested)
		spell_mystic_arts.ui_message_requested.connect(_on_mystic_ui_message_requested)
	
	# SpellDamage を初期化
	if not spell_damage and board_system:
		spell_damage = SpellDamage.new(board_system)
	
	# SpellCreatureMove を初期化
	if not spell_creature_move and board_system and player_system:
		spell_creature_move = SpellCreatureMove.new(board_system, player_system, self)
	
	# SpellCreatureSwap を初期化
	if not spell_creature_swap and board_system and player_system and card_system:
		spell_creature_swap = SpellCreatureSwap.new(board_system, player_system, card_system, self)
	
	# SpellCreatureReturn を初期化
	if not spell_creature_return and board_system and player_system and card_system:
		spell_creature_return = SpellCreatureReturn.new(board_system, player_system, card_system, self)
	
	# SpellPhaseUIManager を初期化
	_initialize_spell_phase_ui()
	
	# 発動通知UIを初期化
	_initialize_spell_cast_notification_ui()
	
	# SpellDamageに通知UIを設定
	if spell_damage and spell_cast_notification_ui:
		spell_damage.set_notification_ui(spell_cast_notification_ui)
	
	# カード選択ハンドラーを初期化
	_initialize_card_selection_handler()
	
	# CPUTurnProcessorを取得
	if game_flow_manager and not cpu_turn_processor:
		cpu_turn_processor = game_flow_manager.get_node_or_null("CPUTurnProcessor")

## スペルフェーズ開始
func start_spell_phase(player_id: int):
	if current_state != State.INACTIVE:
		return
	
	current_state = State.WAITING_FOR_INPUT
	current_player_id = player_id
	spell_used_this_turn = false
	selected_spell_card = {}
	
	spell_phase_started.emit()
	
	# UIを更新（スペルカードのみ選択可能にする）
	if ui_manager:
		_update_spell_phase_ui()
		_show_spell_phase_buttons()
	
	# CPUの場合は簡易AI
	if is_cpu_player(player_id):
		_handle_cpu_spell_turn()
	else:
		# 人間プレイヤーの場合は入力待ち
		if ui_manager and ui_manager.phase_label:
			ui_manager.phase_label.text = "スペルを使用するか、ダイスを振ってください"

## スペルフェーズUIの更新
func _update_spell_phase_ui():
	# 手札のスペルカード以外をグレーアウト
	if not ui_manager or not card_system:
		return
	
	var current_player = player_system.get_current_player() if player_system else null
	if not current_player:
		return
	
	# 手札を取得
	var hand_data = card_system.get_all_cards_for_player(current_player.id)
	
	# スペルカードのみ選択可能にする設定
	if ui_manager:
		ui_manager.card_selection_filter = "spell"
		# 手札表示を更新してグレーアウトを適用
		if ui_manager.hand_display:
			ui_manager.hand_display.update_hand_display(current_player.id)
	
	# スペル選択UIを表示（人間プレイヤーのみ）
	if not is_cpu_player(current_player.id):
		_show_spell_selection_ui(hand_data, current_player.magic_power)
	
	# ダイスボタンのテキストはそのまま「ダイスを振る」

## スペル選択UIを表示
func _show_spell_selection_ui(hand_data: Array, _available_magic: int):
	if not ui_manager or not ui_manager.card_selection_ui:
		return
	
	# スペルカードのみフィルター
	var spell_cards = []
	for card in hand_data:
		if card.get("type", "") == "spell":
			spell_cards.append(card)
	
	if spell_cards.is_empty():
		return
	
	# 現在のプレイヤー情報を取得
	var current_player = player_system.get_current_player() if player_system else null
	if not current_player:
		return
	
	# CardSelectionUIを使用してスペル選択
	if ui_manager.card_selection_ui.has_method("show_selection"):
		ui_manager.card_selection_ui.show_selection(current_player, "spell")

## 秘術フェーズ開始（SpellMysticArtsに委譲）
func start_mystic_arts_phase():
	"""秘術選択フェーズを開始"""
	if not spell_mystic_arts:
		if ui_manager and ui_manager.phase_label:
			ui_manager.phase_label.text = "秘術システムが初期化されていません"
		return
	
	if not player_system:
		return
	
	var current_player = player_system.get_current_player()
	if not current_player:
		return
	
	# SpellMysticArtsに委譲
	await spell_mystic_arts.start_mystic_phase(current_player.id)


## CPUのスペル使用判定（CPUTurnProcessorに委譲）
func _handle_cpu_spell_turn():
	if cpu_turn_processor:
		cpu_turn_processor.cpu_spell_completed.connect(_on_cpu_spell_completed, CONNECT_ONE_SHOT)
		cpu_turn_processor.process_cpu_spell_turn(current_player_id)
	else:
		# フォールバック: CPUTurnProcessorがない場合はパス
		pass_spell()

## CPU スペル処理完了コールバック
func _on_cpu_spell_completed(used_spell: bool):
	if used_spell:
		# TODO: 将来的にはCPUが選んだスペルを実行する
		pass_spell()
	else:
		pass_spell()

## スペルコストを支払えるか
func _can_afford_spell(spell_card: Dictionary) -> bool:
	if not player_system:
		return false
	
	var magic = player_system.get_magic(current_player_id)
	var cost_data = spell_card.get("cost", {})
	if cost_data == null:
		cost_data = {}
	
	var cost = 0
	if typeof(cost_data) == TYPE_DICTIONARY:
		cost = cost_data.get("mp", 0)
	
	return magic >= cost

## スペルを使用
func use_spell(spell_card: Dictionary):
	if current_state != State.WAITING_FOR_INPUT:
		return
	
	if spell_used_this_turn:
		return
	
	if not _can_afford_spell(spell_card):
		return
	
	selected_spell_card = spell_card
	spell_used_this_turn = true
	
	# コストを支払う
	var cost_data = spell_card.get("cost", {})
	if cost_data == null:
		cost_data = {}
	
	var cost = 0
	if typeof(cost_data) == TYPE_DICTIONARY:
		cost = cost_data.get("mp", 0)
	
	if player_system:
		player_system.add_magic(current_player_id, -cost)
	
	# 対象選択が必要かチェック
	var parsed = spell_card.get("effect_parsed", {})
	var target_type = parsed.get("target_type", "")
	var target_filter = parsed.get("target_filter", "")
	var target_info = parsed.get("target_info", {})
	var effects = parsed.get("effects", [])
	
	# リリーフ（swap_board_creatures）: 使用時点で2体未満なら弾く
	for effect in effects:
		if effect.get("effect_type") == "swap_board_creatures":
			var own_creature_count = _count_own_creatures(current_player_id)
			if own_creature_count < 2:
				if ui_manager and ui_manager.phase_label:
					ui_manager.phase_label.text = "対象がいません"
				await get_tree().create_timer(1.0).timeout
				cancel_spell()
				return
	
	# target_filter または target_type が "self" の場合は、即座に効果発動（対象選択UIなし）
	if target_filter == "self" or target_type == "self":
		# 対象選択なし。効果実行時に current_player_id を使用
		var target_data = {"type": "player", "player_id": current_player_id}
		execute_spell_effect(spell_card, target_data)
	elif target_type == "all_creatures":
		# 全クリーチャー対象（条件付き）
		_execute_spell_on_all_creatures(spell_card, target_info)
	elif not target_type.is_empty() and target_type != "none":
		# 対象選択が必要
		current_state = State.SELECTING_TARGET
		target_selection_required.emit(spell_card, target_type)
		
		# target_filterをtarget_infoに追加（get_valid_targetsで使用）
		if not target_filter.is_empty():
			target_info["target_filter"] = target_filter
		
		# 対象選択UIを表示
		_show_target_selection_ui(target_type, target_info)
	else:
		# 即座に効果発動（target_type が空または "none" の場合）
		execute_spell_effect(spell_card, {})

## 対象選択UIを表示（領地コマンドと同じ方式）
func _show_target_selection_ui(target_type: String, target_info: Dictionary):
	# 有効な対象を取得（ヘルパー使用）
	var targets = TargetSelectionHelper.get_valid_targets(self, target_type, target_info)
	
	if targets.is_empty():
		# 対象がいない場合はメッセージ表示してキャンセル
		if ui_manager and ui_manager.phase_label:
			ui_manager.phase_label.text = "対象がいません"
		await get_tree().create_timer(1.0).timeout
		cancel_spell()
		return
	
	# 領地コマンドと同じ方式で選択開始
	available_targets = targets
	current_target_index = 0
	current_state = State.SELECTING_TARGET
	
	# 最初の対象を表示
	_update_target_selection()

## 選択を更新
func _update_target_selection():
	if available_targets.is_empty():
		return
	
	var target = available_targets[current_target_index]
	
	# 汎用ヘルパーを使用して視覚的に選択
	TargetSelectionHelper.select_target_visually(self, target)
	
	# UI更新
	_update_selection_ui()

## 選択UIを更新（領地コマンドと同じ形式）
func _update_selection_ui():
	if not ui_manager or not ui_manager.phase_label:
		return
	
	if available_targets.is_empty():
		return
	
	var target = available_targets[current_target_index]
	
	# ヘルパーを使用してテキスト生成
	var text = TargetSelectionHelper.format_target_info(target, current_target_index + 1, available_targets.size())
	ui_manager.phase_label.text = text




## 入力処理
func _input(event):
	if current_state != State.SELECTING_TARGET:
		return
	
	if event is InputEventKey and event.pressed:
		
		# ↑キーまたは←キー: 前の対象
		if event.keycode == KEY_UP or event.keycode == KEY_LEFT:
			if TargetSelectionHelper.move_target_previous(self):
				_update_target_selection()
			get_viewport().set_input_as_handled()
		
		# ↓キーまたは→キー: 次の対象
		elif event.keycode == KEY_DOWN or event.keycode == KEY_RIGHT:
			if TargetSelectionHelper.move_target_next(self):
				_update_target_selection()
			get_viewport().set_input_as_handled()
		
		# Enterキー: 確定
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_confirm_target_selection()
			get_viewport().set_input_as_handled()
		
		# 数字キー1-9, 0: 直接選択して即確定
		elif TargetSelectionHelper.is_number_key(event.keycode):
			var index = TargetSelectionHelper.get_number_from_key(event.keycode)
			if TargetSelectionHelper.select_target_by_index(self, index):
				_update_target_selection()
				# 数字キーの場合は即座に確定
				_confirm_target_selection()
			get_viewport().set_input_as_handled()
		
		# Cキーまたはエスケープ: キャンセル
		elif event.keycode == KEY_C or event.keycode == KEY_ESCAPE:
			_cancel_target_selection()
			get_viewport().set_input_as_handled()

## 対象選択を確定
func _confirm_target_selection():
	if available_targets.is_empty():
		return
	
	var selected_target = available_targets[current_target_index]
	
	# 選択をクリア
	TargetSelectionHelper.clear_selection(self)
	
	# タイル選択モードの場合（SpellCreatureMove用）
	if is_tile_selection_mode:
		var tile_index = selected_target.get("tile_index", -1)
		tile_selection_completed.emit(tile_index)
		return
	
	# 秘術かスペルかで分岐
	if spell_mystic_arts and spell_mystic_arts.is_active():
		# 秘術実行（SpellMysticArtsに委譲）
		spell_mystic_arts.on_target_confirmed(selected_target)
	else:
		# スペル実行
		execute_spell_effect(selected_spell_card, selected_target)

## 対象選択をキャンセル
func _cancel_target_selection():
	# 選択をクリア
	TargetSelectionHelper.clear_selection(self)
	
	# タイル選択モードの場合（SpellCreatureMove用）
	if is_tile_selection_mode:
		tile_selection_completed.emit(-1)  # キャンセル時は-1
		return
	
	# 秘術かスペルかで分岐
	if spell_mystic_arts and spell_mystic_arts.is_active():
		# 秘術キャンセル
		spell_mystic_arts.clear_selection()
		spell_mystic_arts._end_mystic_phase()
		current_state = State.WAITING_FOR_INPUT
	else:
		# スペルキャンセル
		cancel_spell()

## スペルをキャンセル
func cancel_spell():
	# コストを返却
	var cost_data = selected_spell_card.get("cost", {})
	if cost_data == null:
		cost_data = {}
	
	var cost = 0
	if typeof(cost_data) == TYPE_DICTIONARY:
		cost = cost_data.get("mp", 0)
	
	if player_system and cost > 0:
		player_system.add_magic(current_player_id, cost)
	
	selected_spell_card = {}
	spell_used_this_turn = false
	current_state = State.WAITING_FOR_INPUT

## スペル効果を実行
func execute_spell_effect(spell_card: Dictionary, target_data: Dictionary):
	current_state = State.EXECUTING_EFFECT
	
	# 復帰[ブック]フラグをリセット
	spell_failed = false
	
	# 発動通知を表示（クリック待ち）
	var caster_name = "プレイヤー%d" % (current_player_id + 1)
	if player_system and current_player_id >= 0 and current_player_id < player_system.players.size():
		caster_name = player_system.players[current_player_id].name
	await _show_spell_cast_notification(caster_name, target_data, spell_card, false)
	
	# スペル効果を実行
	var parsed = spell_card.get("effect_parsed", {})
	var effects = parsed.get("effects", [])
	
	# 復帰[ブック]判定（常にデッキに戻す場合）
	var return_to_deck = parsed.get("return_to_deck", false)
	if return_to_deck:
		if game_flow_manager and game_flow_manager.spell_land:
			if game_flow_manager.spell_land.return_spell_to_deck(current_player_id, spell_card):
				spell_failed = true  # 捨て札処理をスキップするためのフラグ
	
	# 効果を適用
	for effect in effects:
		await _apply_single_effect(effect, target_data)
	
	# カードを捨て札に（復帰[ブック]時はスキップ）
	if card_system and not spell_failed:
		# 手札からカードのインデックスを探す
		var hand = card_system.get_all_cards_for_player(current_player_id)
		for i in range(hand.size()):
			if hand[i].get("id", -1) == spell_card.get("id", -2):
				card_system.discard_card(current_player_id, i, "use")
				break
	elif spell_failed:
		pass  # 復帰[ブック]: カードはデッキに戻される
	
	# 効果発動完了
	spell_used.emit(spell_card)
	
	# カード選択中の場合は、選択完了後に complete_spell_phase を呼ぶ
	if card_selection_handler and card_selection_handler.is_selecting():
		return
	
	# 少し待機してからカメラを戻す
	await get_tree().create_timer(0.5).timeout
	
	# カメラを使用者（現在のプレイヤー）に戻す
	_return_camera_to_player()
	
	# さらに待機してからスペルフェーズ完了
	await get_tree().create_timer(0.5).timeout
	complete_spell_phase()

## 単一の効果を適用
func _apply_single_effect(effect: Dictionary, target_data: Dictionary):
	var effect_type = effect.get("effect_type", "")
	
	match effect_type:
		"drain_magic", "drain_magic_conditional", "drain_magic_by_land_count", "drain_magic_by_lap_diff", \
		"gain_magic", "gain_magic_by_rank", "gain_magic_by_lap", "gain_magic_from_destroyed_count", \
		"gain_magic_from_spell_cost", "balance_all_magic", "gain_magic_from_land_chain":
			# 魔力操作系 - SpellMagicに委譲
			if game_flow_manager and game_flow_manager.spell_magic:
				var context = {
					"rank": _get_player_ranking(current_player_id),
					"from_player_id": target_data.get("player_id", -1),
					"card_system": card_system
				}
				var result = await game_flow_manager.spell_magic.apply_effect(effect, current_player_id, context)
				# フォールバック効果（ロングライン未達成時のドロー等）
				if result.has("next_effect") and not result["next_effect"].is_empty():
					await _apply_single_effect(result["next_effect"], target_data)
		
		"dice_fixed", "dice_range", "dice_multi", "dice_range_magic":
			# ダイス系効果（統合処理）
			if game_flow_manager and game_flow_manager.spell_dice:
				game_flow_manager.spell_dice.apply_effect_from_parsed(effect, target_data, current_player_id)
		
		"stat_boost", "stat_reduce":
			# ステータス呪い系（統合処理）
			if target_data.get("type") == "land":
				var tile_index = target_data.get("tile_index", -1)
				if game_flow_manager and game_flow_manager.spell_curse_stat:
					game_flow_manager.spell_curse_stat.apply_curse_from_effect(effect, tile_index)
		
		"skill_nullify", "battle_disable", "ap_nullify", "stat_reduce", "random_stat_curse", "command_growth_curse", "plague_curse", "creature_curse":
			# 戦闘制限呪い系 - SpellCurseに委譲
			var target_type = target_data.get("type", "")
			if target_type == "land" or target_type == "creature":
				var tile_index = target_data.get("tile_index", -1)
				if game_flow_manager and game_flow_manager.spell_curse:
					game_flow_manager.spell_curse.apply_effect(effect, tile_index)
		
		"bounty_curse":
			# 賞金首呪い（バウンティハント）- SpellCurseに委譲
			if target_data.get("type") == "land":
				var tile_index = target_data.get("tile_index", -1)
				if game_flow_manager and game_flow_manager.spell_curse:
					# caster_idを効果辞書に追加
					var effect_with_caster = effect.duplicate()
					effect_with_caster["caster_id"] = current_player_id
					game_flow_manager.spell_curse.apply_effect(effect_with_caster, tile_index)
		
		"grant_mystic_arts":
			# 秘術付与呪い（シュリンクシジル等）- SpellCurseに委譲
			if target_data.get("type") == "land":
				var tile_index = target_data.get("tile_index", -1)
				if game_flow_manager and game_flow_manager.spell_curse:
					game_flow_manager.spell_curse.apply_effect(effect, tile_index)
		
		"land_curse":
			# 土地呪い（ブラストトラップ等）- SpellCurseに委譲
			if target_data.get("type") == "land":
				var tile_index = target_data.get("tile_index", -1)
				if game_flow_manager and game_flow_manager.spell_curse:
					var effect_with_caster = effect.duplicate()
					effect_with_caster["caster_id"] = current_player_id
					game_flow_manager.spell_curse.apply_effect(effect_with_caster, tile_index)
		
		"toll_share", "toll_disable", "toll_fixed", "toll_multiplier", "peace", "curse_toll_half":
			# 通行料呪い系（統合処理）
			if game_flow_manager and game_flow_manager.spell_curse_toll:
				var tile_index = target_data.get("tile_index", -1)
				var target_player_id = target_data.get("player_id", -1)
				game_flow_manager.spell_curse_toll.apply_curse_from_effect(effect, tile_index, target_player_id, current_player_id)
		
		"draw", "draw_cards", "draw_by_rank", "draw_by_type", "discard_and_draw_plus", "check_hand_elements", \
		"destroy_curse_cards", "destroy_expensive_cards", "destroy_duplicate_cards", \
		"destroy_selected_card", "steal_selected_card", "destroy_from_deck_selection", \
		"draw_from_deck_selection", "steal_item_conditional", \
		"add_specific_card", "destroy_and_draw", "swap_creature":
			# ドロー・手札操作系 - SpellDrawに委譲
			if game_flow_manager and game_flow_manager.spell_draw:
				var context = {
					"rank": _get_player_ranking(current_player_id),
					"target_player_id": target_data.get("player_id", current_player_id),
					"tile_index": target_data.get("tile_index", -1)
				}
				var result = game_flow_manager.spell_draw.apply_effect(effect, current_player_id, context)
				# 条件分岐効果の場合は次の効果を再帰適用
				if result.has("next_effect") and not result["next_effect"].is_empty():
					_apply_single_effect(result["next_effect"], target_data)
		
		"change_element", "change_level", "abandon_land", "destroy_creature", \
		"change_element_bidirectional", "change_element_to_dominant", \
		"find_and_change_highest_level", "conditional_level_change", \
		"align_mismatched_lands":
			# 土地操作系効果はSpellLandに委譲
			if game_flow_manager and game_flow_manager.spell_land:
				var success = game_flow_manager.spell_land.apply_land_effect(effect, target_data, current_player_id)
				
				# 復帰[ブック]判定（条件不成立の場合）
				if not success and effect.get("return_to_deck_on_fail", false):
					if game_flow_manager.spell_land.return_spell_to_deck(current_player_id, selected_spell_card):
						spell_failed = true
		
		"damage", "heal", "full_heal", "clear_down":
			# ダメージ・回復系 - SpellDamageに委譲
			if spell_damage:
				await spell_damage.apply_effect(self, effect, target_data)
		
		"move_to_adjacent_enemy", "move_steps", "move_self", "destroy_and_move":
			# クリーチャー移動系 - SpellCreatureMoveに委譲（戦闘も内部で処理）
			if spell_creature_move:
				await spell_creature_move.apply_effect(effect, target_data, current_player_id)
		
		"swap_with_hand", "swap_board_creatures":
			# クリーチャー交換系 - SpellCreatureSwapに委譲
			if spell_creature_swap:
				var result = await spell_creature_swap.apply_effect(effect, target_data, current_player_id)
				# 復帰[ブック]判定
				if not result.get("success", false) and result.get("return_to_deck", false):
					if game_flow_manager and game_flow_manager.spell_land:
						if game_flow_manager.spell_land.return_spell_to_deck(current_player_id, selected_spell_card):
							spell_failed = true
		
		"return_to_hand":
			# クリーチャー手札戻し系 - SpellCreatureReturnに委譲
			if spell_creature_return:
				await spell_creature_return.apply_effect(effect, target_data, current_player_id)
		
		"permanent_hp_change", "permanent_ap_change", "secret_tiny_army":
			# ステータス増減スペル - SpellCurseStatに委譲
			if game_flow_manager and game_flow_manager.spell_curse_stat:
				await game_flow_manager.spell_curse_stat.apply_effect(self, effect, target_data, current_player_id, selected_spell_card)
		
		"self_destroy":
			# 自壊効果（ゴールドトーテム等）- SpellMagicに委譲
			var tile_index = target_data.get("tile_index", target_data.get("caster_tile_index", -1))
			var clear_land = effect.get("clear_land", true)
			if game_flow_manager and game_flow_manager.spell_magic:
				game_flow_manager.spell_magic.apply_self_destroy(tile_index, clear_land)

## 全クリーチャー対象スペルを実行（ディラニー、全体ダメージ等）
func _execute_spell_on_all_creatures(spell_card: Dictionary, target_info: Dictionary):
	current_state = State.EXECUTING_EFFECT
	
	# 発動通知を表示
	var caster_name = "プレイヤー%d" % (current_player_id + 1)
	if player_system and current_player_id >= 0 and current_player_id < player_system.players.size():
		caster_name = player_system.players[current_player_id].name
	
	var target_data_for_notification = {"type": "all"}
	await _show_spell_cast_notification(caster_name, target_data_for_notification, spell_card, false)
	
	# スペル効果を取得
	var parsed = spell_card.get("effect_parsed", {})
	var effects = parsed.get("effects", [])
	
	# ダメージ/回復効果をSpellDamageに委譲
	var handled = false
	if spell_damage:
		handled = await spell_damage.execute_all_creatures_effects(self, effects, target_info)
	
	# 未処理（呪い効果等）はSpellCurseに委譲
	if not handled:
		if game_flow_manager and game_flow_manager.spell_curse:
			for effect in effects:
				game_flow_manager.spell_curse.apply_to_all_creatures(effect, target_info)
	
	# カードを捨て札に
	if card_system:
		var hand = card_system.get_all_cards_for_player(current_player_id)
		for i in range(hand.size()):
			if hand[i].get("id", -1) == spell_card.get("id", -2):
				card_system.discard_card(current_player_id, i, "use")
				break
	
	# 効果発動完了
	spell_used.emit(spell_card)
	
	# 少し待機してからスペルフェーズ完了
	await get_tree().create_timer(0.5).timeout
	_return_camera_to_player()
	await get_tree().create_timer(0.5).timeout
	complete_spell_phase()

## カメラを使用者に戻す
func _return_camera_to_player():
	if not player_system or not board_system:
		return
	
	# MovementControllerからプレイヤーの実際の位置を取得
	if board_system.movement_controller:
		var player_tile_index = board_system.movement_controller.get_player_tile(current_player_id)
		
		if board_system.camera and board_system.tile_nodes.has(player_tile_index):
			var tile_pos = board_system.tile_nodes[player_tile_index].global_position
			
			# MovementControllerと同じカメラオフセットを使用
			const CAMERA_OFFSET = Vector3(19, 19, 19)
			var new_camera_pos = tile_pos + Vector3(0, 1.0, 0) + CAMERA_OFFSET
			
			board_system.camera.position = new_camera_pos
			board_system.camera.look_at(tile_pos + Vector3(0, 1.0, 0), Vector3.UP)

## スペルをパス
func pass_spell():
	spell_passed.emit()
	complete_spell_phase()

## タイルリストから選択（SpellCreatureMove用）
## 移動先選択などで使用
func select_tile_from_list(tile_indices: Array, message: String) -> int:
	if tile_indices.is_empty():
		return -1
	
	# タイル選択モードを開始（候補が1つでも選択UIを表示）
	is_tile_selection_mode = true
	
	# ターゲットリストを設定
	var targets: Array = []
	for tile_index in tile_indices:
		targets.append({"type": "land", "tile_index": tile_index})
	
	available_targets = targets
	current_target_index = 0
	current_state = State.SELECTING_TARGET
	
	# メッセージ表示
	if ui_manager and ui_manager.phase_label:
		ui_manager.phase_label.text = message
	
	# 最初の対象を表示
	_update_target_selection()
	
	# 選択完了を待機
	var selected_target = await _wait_for_tile_selection()
	
	# タイル選択モードを終了
	is_tile_selection_mode = false
	
	# 選択マーカーをクリア
	TargetSelectionHelper.clear_selection(self)
	
	return selected_target


## タイル選択完了を待機
func _wait_for_tile_selection() -> int:
	# 選択完了シグナルを待つ
	var result = await tile_selection_completed
	return result

## タイル選択完了シグナル
signal tile_selection_completed(tile_index: int)


## スペルフェーズ完了
func complete_spell_phase():
	if current_state == State.INACTIVE:
		return
	
	current_state = State.INACTIVE
	selected_spell_card = {}
	
	# スペルフェーズのフィルターをクリア
	if ui_manager:
		ui_manager.card_selection_filter = ""
		# 手札表示を更新してグレーアウトを解除
		if ui_manager.hand_display and player_system:
			var current_player = player_system.get_current_player()
			if current_player:
				ui_manager.hand_display.update_hand_display(current_player.id)
	
	# スペルフェーズボタンを非表示
	_hide_spell_phase_buttons()
	
	spell_phase_completed.emit()
	
	# 次のフェーズ（ダイスフェーズ）への遷移は GameFlowManager が行う

## CPUプレイヤーかどうか
func is_cpu_player(player_id: int) -> bool:
	if not game_flow_manager:
		return false
	
	var cpu_settings = game_flow_manager.player_is_cpu
	var debug_mode = game_flow_manager.debug_manual_control_all
	
	if debug_mode:
		return false  # デバッグモードでは全員手動
	
	return player_id < cpu_settings.size() and cpu_settings[player_id]

## 使用者のクリーチャー数をカウント
func _count_own_creatures(player_id: int) -> int:
	if not board_system:
		return 0
	
	var count = 0
	for tile_index in board_system.tile_nodes.keys():
		var tile = board_system.tile_nodes[tile_index]
		if tile and tile.owner_id == player_id and not tile.creature_data.is_empty():
			count += 1
	return count

## プレイヤーの順位を取得（UIパネルから）
func _get_player_ranking(player_id: int) -> int:
	if ui_manager and ui_manager.player_info_panel:
		return ui_manager.player_info_panel.get_player_ranking(player_id)
	# フォールバック: 常に1位を返す
	return 1

## アクティブか
func is_spell_phase_active() -> bool:
	return current_state != State.INACTIVE

# ============ 秘術システム対応（新規追加）============

## 秘術が利用可能か確認
func has_available_mystic_arts(player_id: int) -> bool:
	if not has_spell_mystic_arts():
		return false
	
	var available = spell_mystic_arts.get_available_creatures(player_id)
	return available.size() > 0

## SpellMysticArtsクラスが存在するか
func has_spell_mystic_arts() -> bool:
	return spell_mystic_arts != null and spell_mystic_arts is SpellMysticArts

# ============ UIボタン管理 ============

## SpellPhaseUIManager を初期化
func _initialize_spell_phase_ui():
	if not spell_phase_ui_manager:
		spell_phase_ui_manager = SpellPhaseUIManager.new()
		add_child(spell_phase_ui_manager)
		
		# UIレイヤーへの参照を設定
		if ui_manager and ui_manager.card_selection_ui and ui_manager.card_selection_ui.parent_node:
			# CardUIHelper と spell_phase_handler への参照を渡す
			spell_phase_ui_manager.card_ui_helper = load("res://scripts/ui_components/card_ui_helper.gd")
			spell_phase_ui_manager.spell_phase_handler_ref = self
			var ui_parent = ui_manager.card_selection_ui.parent_node
			spell_phase_ui_manager.create_mystic_button(ui_parent)
			spell_phase_ui_manager.create_spell_skip_button(ui_parent)

## スペルフェーズ開始時にボタンを表示
func _show_spell_phase_buttons():
	if spell_phase_ui_manager:
		# 現在の手札枚数を取得
		var hand_count = 6  # デフォルト値
		if card_system and player_system:
			var current_player = player_system.get_current_player()
			if current_player:
				var hand_data = card_system.get_all_cards_for_player(current_player.id)
				hand_count = hand_data.size()
		
		# 秘術ボタンは使用可能なクリーチャーがいる場合のみ表示
		if has_available_mystic_arts(current_player_id):
			spell_phase_ui_manager.show_mystic_button(hand_count)
		spell_phase_ui_manager.show_spell_skip_button(hand_count)

## スペルフェーズ終了時にボタンを非表示
func _hide_spell_phase_buttons():
	if spell_phase_ui_manager:
		spell_phase_ui_manager.hide_mystic_button()
		spell_phase_ui_manager.hide_spell_skip_button()

## 秘術ボタンの表示状態を更新（外部から呼び出し可能）
func update_mystic_button_visibility():
	if not spell_phase_ui_manager or current_state == State.INACTIVE:
		return
	
	var hand_count = 6
	if card_system and player_system:
		var current_player = player_system.get_current_player()
		if current_player:
			var hand_data = card_system.get_all_cards_for_player(current_player.id)
			hand_count = hand_data.size()
	
	if has_available_mystic_arts(current_player_id):
		spell_phase_ui_manager.show_mystic_button(hand_count)
	else:
		spell_phase_ui_manager.hide_mystic_button()

## 秘術使用時にスペルボタンを隠す
func _on_mystic_art_used():
	if spell_phase_ui_manager:
		spell_phase_ui_manager.on_mystic_art_used()


## 秘術フェーズ完了時
func _on_mystic_phase_completed():
	current_state = State.WAITING_FOR_INPUT


## 秘術ターゲット選択要求時
func _on_mystic_target_selection_requested(targets: Array):
	available_targets = targets
	current_target_index = 0
	current_state = State.SELECTING_TARGET
	_update_target_selection()


## 秘術UIメッセージ表示要求時
func _on_mystic_ui_message_requested(message: String):
	if ui_manager and ui_manager.phase_label:
		ui_manager.phase_label.text = message


# ============ 発動通知UI ============

## 発動通知UIを初期化
func _initialize_spell_cast_notification_ui():
	if spell_cast_notification_ui:
		return
	
	spell_cast_notification_ui = SpellCastNotificationUI.new()
	spell_cast_notification_ui.name = "SpellCastNotificationUI"
	
	# UIマネージャーの直下に追加（最前面に表示されるように）
	if ui_manager:
		ui_manager.add_child(spell_cast_notification_ui)
	else:
		add_child(spell_cast_notification_ui)

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
		game_flow_manager.spell_draw if game_flow_manager else null,
		spell_phase_ui_manager
	)
	
	# SpellDrawにもcard_selection_handlerを設定
	if game_flow_manager and game_flow_manager.spell_draw:
		game_flow_manager.spell_draw.set_card_selection_handler(card_selection_handler)
	
	# 選択完了シグナルを接続
	card_selection_handler.selection_completed.connect(_on_card_selection_completed)

## カード選択完了時のコールバック
func _on_card_selection_completed():
	complete_spell_phase()

## スペル/秘術発動通知を表示（クリック待ち）
func _show_spell_cast_notification(caster_name: String, target_data: Dictionary, spell_or_mystic: Dictionary, is_mystic: bool = false) -> void:
	if not spell_cast_notification_ui:
		return
	
	# 効果名を取得
	var effect_name: String
	if is_mystic:
		effect_name = SpellCastNotificationUI.get_mystic_art_display_name(spell_or_mystic)
	else:
		effect_name = SpellCastNotificationUI.get_effect_display_name(spell_or_mystic)
	
	# 対象名を取得
	var target_name = SpellCastNotificationUI.get_target_display_name(target_data, board_system, player_system)
	
	# 通知を表示してクリック待ち
	spell_cast_notification_ui.show_spell_cast_and_wait(caster_name, target_name, effect_name)
	await spell_cast_notification_ui.click_confirmed
