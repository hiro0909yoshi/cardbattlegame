# SpellPhaseHandler - スペルフェーズの処理を担当
extends Node
class_name SpellPhaseHandler

const GameConstants = preload("res://scripts/game_constants.gd")

## シグナル
signal spell_phase_started()
signal spell_phase_completed()
signal spell_passed()
@warning_ignore("unused_signal")  # spell_effect_executorでemitされる（将来の拡張用）
signal spell_used(spell_card: Dictionary)
signal target_selection_required(spell_card: Dictionary, target_type: String)
signal target_confirmed(target_data: Dictionary)  # ターゲット選択完了時

## 状態
enum State {
	INACTIVE,
	WAITING_FOR_INPUT,  # スペル選択またはダイス待ち
	SELECTING_TARGET,    # 対象選択中
	CONFIRMING_EFFECT,   # 効果確認中（全体対象等）
	EXECUTING_EFFECT     # 効果実行中
}

var current_state: State = State.INACTIVE
var current_player_id: int = -1
var selected_spell_card: Dictionary = {}
var spell_used_this_turn: bool = false  # 1ターン1回制限
var skip_dice_phase: bool = false  # ワープ系スペル使用時はサイコロフェーズをスキップ

## 確認フェーズ用
var confirmation_target_type: String = ""
var confirmation_target_info: Dictionary = {}
var confirmation_target_data: Dictionary = {}

## カード選択ハンドラー（敵手札選択、デッキカード選択）
var card_selection_handler: CardSelectionHandler = null

## スペル失敗フラグ
var spell_failed: bool = false  # 復帰[ブック]フラグ（条件不成立でデッキに戻る）

## 外部スペルモード（魔法タイル等で使用）
## trueの場合、手札からの削除・捨て札処理をスキップ
var is_external_spell_mode: bool = false
var _external_spell_cancelled: bool = false  # キャンセルフラグ
var _external_spell_no_target: bool = false  # 対象不在フラグ
signal external_spell_finished()  # 外部スペル実行完了

## デバッグ設定
## 密命カードのテストを一時的に無効化
## true: 密命カードを通常カードとして扱う（失敗判定・復帰[ブック]をスキップ）
## false: 通常通り密命として動作
## 使い方: GameFlowManagerのセットアップ後に設定
##   spell_phase_handler.debug_disable_secret_cards = true
var debug_disable_secret_cards: bool = false

## カード犠牲・土地条件のデバッグフラグはTileActionProcessorで一元管理
## 参照: board_system.tile_action_processor.debug_disable_card_sacrifice
## 参照: board_system.tile_action_processor.debug_disable_lands_required

## ターゲット選択（領地コマンドと同じ構造）
var available_targets: Array = []
var current_target_index: int = 0
var selection_marker: MeshInstance3D = null
var confirmation_markers: Array = []  # 確認フェーズ用複数マーカー
# タイル選択はTargetSelectionHelperに委譲
var is_borrow_spell_mode: bool = false  # 借用スペル実行中（SpellBorrow用）

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
var spell_creature_place: SpellCreaturePlace = null  # クリーチャー配置
var spell_borrow: SpellBorrow = null  # スペル借用
var spell_transform: SpellTransform = null  # クリーチャー変身
var spell_purify: SpellPurify = null  # 呪い除去
var spell_synthesis: SpellSynthesis = null  # スペル合成
var card_sacrifice_helper: CardSacrificeHelper = null  # カード犠牲システム
var cpu_turn_processor: CPUTurnProcessor = null  # CPU処理（旧・バトル用）
var spell_effect_executor: SpellEffectExecutor = null  # 効果実行（分離クラス）
var cpu_spell_ai: CPUSpellAI = null  # CPUスペル判断AI
var cpu_mystic_arts_ai: CPUMysticArtsAI = null  # CPUミスティックアーツ判断AI
var cpu_hand_utils: CPUHandUtils = null  # CPU手札ユーティリティ
var cpu_movement_evaluator: CPUMovementEvaluator = null  # CPU移動評価（ホーリーワード判断用）

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
	
	# SpellCreaturePlace を初期化
	if not spell_creature_place:
		spell_creature_place = SpellCreaturePlace.new()
	
	# SpellDrawにSpellCreaturePlace参照を設定
	if game_flow_manager and game_flow_manager.spell_draw and spell_creature_place:
		game_flow_manager.spell_draw.set_spell_creature_place(spell_creature_place)
	
	# SpellBorrow を初期化
	if not spell_borrow and board_system and player_system and card_system:
		spell_borrow = SpellBorrow.new(board_system, player_system, card_system, self)
	
	# SpellTransform を初期化
	if not spell_transform and board_system and player_system and card_system:
		spell_transform = SpellTransform.new(board_system, player_system, card_system, self)
	
	# SpellPurify を初期化
	if not spell_purify and board_system and creature_manager and player_system and game_flow_manager:
		spell_purify = SpellPurify.new(board_system, creature_manager, player_system, game_flow_manager)
	
	# CardSacrificeHelper を初期化（スペル合成・クリーチャー合成共通）
	if not card_sacrifice_helper and card_system and player_system:
		card_sacrifice_helper = CardSacrificeHelper.new(card_system, player_system, ui_manager)
	
	# SpellSynthesis を初期化
	if not spell_synthesis and card_sacrifice_helper:
		spell_synthesis = SpellSynthesis.new(card_sacrifice_helper)
	
	# SpellPhaseUIManager を初期化
	_initialize_spell_phase_ui()
	
	# hand_displayのシグナルに接続（カードドロー後のボタン位置更新用）
	if ui_manager and ui_manager.hand_display:
		if not ui_manager.hand_display.hand_updated.is_connected(_on_hand_updated_for_buttons):
			ui_manager.hand_display.hand_updated.connect(_on_hand_updated_for_buttons)
	
	# 発動通知UIを初期化
	_initialize_spell_cast_notification_ui()
	
	# SpellDamageに通知UIを設定
	if spell_damage and spell_cast_notification_ui:
		spell_damage.set_notification_ui(spell_cast_notification_ui)
	
	# カード選択ハンドラーを初期化
	_initialize_card_selection_handler()
	
	# CPUTurnProcessorを取得（BoardSystem3Dの子ノードから）
	if board_system and not cpu_turn_processor:
		cpu_turn_processor = board_system.get_node_or_null("CPUTurnProcessor")
	
	# CPU手札ユーティリティを初期化
	if not cpu_hand_utils:
		cpu_hand_utils = CPUHandUtils.new()
		var player_buff_system = game_flow_manager.player_buff_system if game_flow_manager else null
		cpu_hand_utils.setup_systems(card_system, board_system, player_system, player_buff_system)
	
	# CPU バトルAIを初期化（共通バトル評価用）
	var cpu_battle_ai: CPUBattleAI = null
	if not cpu_battle_ai:
		cpu_battle_ai = CPUBattleAI.new()
		var player_buff_system = game_flow_manager.player_buff_system if game_flow_manager else null
		cpu_battle_ai.setup_systems(card_system, board_system, player_system, player_buff_system, game_flow_manager)
		cpu_battle_ai.set_hand_utils(cpu_hand_utils)
	
	# CPU スペル/ミスティックアーツ AI を初期化
	if not cpu_spell_ai:
		cpu_spell_ai = CPUSpellAI.new()
		var l_system = game_flow_manager.lap_system if game_flow_manager else null
		cpu_spell_ai.initialize(board_system, player_system, card_system, creature_manager, l_system, game_flow_manager)
		cpu_spell_ai.set_hand_utils(cpu_hand_utils)
		cpu_spell_ai.set_battle_ai(cpu_battle_ai)
		# CPUMovementEvaluatorを設定（ホーリーワード判断用）
		if cpu_movement_evaluator:
			cpu_spell_ai.set_movement_evaluator(cpu_movement_evaluator)
	
	if not cpu_mystic_arts_ai:
		cpu_mystic_arts_ai = CPUMysticArtsAI.new()
		var l_system = game_flow_manager.lap_system if game_flow_manager else null
		cpu_mystic_arts_ai.initialize(board_system, player_system, card_system, creature_manager, l_system)
		cpu_mystic_arts_ai.set_hand_utils(cpu_hand_utils)
		cpu_mystic_arts_ai.set_battle_ai(cpu_battle_ai)
	
	# SpellEffectExecutor を初期化
	if not spell_effect_executor:
		spell_effect_executor = SpellEffectExecutor.new(self)

## スペルフェーズ開始
func start_spell_phase(player_id: int):
	if current_state != State.INACTIVE:
		return
	
	current_state = State.WAITING_FOR_INPUT
	current_player_id = player_id
	spell_used_this_turn = false
	skip_dice_phase = false  # リセット
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
		# 人間プレイヤーの場合：カメラ手動モード有効化
		if board_system and board_system.camera_controller:
			board_system.camera_controller.enable_manual_mode()
			board_system.camera_controller.set_current_player(player_id)
		
		# グローバルナビゲーション設定（戻るボタンのみ = スペルを使わない）
		_setup_spell_selection_navigation()
		
		# 入力待ち
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
	
	# スペル不可呪いチェック
	var context = _build_spell_context()
	var is_spell_disabled = SpellProtection.is_player_spell_disabled(current_player, context)
	
	# フィルターモードを設定
	if ui_manager:
		if is_spell_disabled:
			ui_manager.card_selection_filter = "spell_disabled"
			if ui_manager.phase_label:
				ui_manager.phase_label.text = "スペル不可の呪いがかかっています"
		else:
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


## CPUのスペル使用判定（新AI使用）
func _handle_cpu_spell_turn():
	await get_tree().create_timer(0.5).timeout  # 思考時間
	
	# スペル判断
	var spell_decision = {"use": false}
	if cpu_spell_ai:
		spell_decision = cpu_spell_ai.decide_spell(current_player_id)
	
	# ミスティックアーツ判断
	var mystic_decision = {"use": false}
	if cpu_mystic_arts_ai and has_available_mystic_arts(current_player_id):
		mystic_decision = cpu_mystic_arts_ai.decide_mystic_arts(current_player_id)
	
	# どちらも使わない場合
	if not spell_decision.use and not mystic_decision.use:
		pass_spell(false)
		return
	
	# スコア比較してどちらを使うか決定
	var spell_score = spell_decision.get("score", 0.0)
	var mystic_score = mystic_decision.get("score", 0.0)
	
	if spell_decision.use and spell_score >= mystic_score:
		# スペルを使用
		await _execute_cpu_spell(spell_decision)
	elif mystic_decision.use:
		# ミスティックアーツを使用
		await _execute_cpu_mystic_arts(mystic_decision)
	else:
		pass_spell(false)

## CPUがスペルを実行
func _execute_cpu_spell(decision: Dictionary):
	var spell_card = decision.get("spell", {})
	var target = decision.get("target", {})
	
	if spell_card.is_empty():
		pass_spell(false)
		return
	
	print("[CPU] スペル使用: %s" % spell_card.get("name", "?"))
	
	# コストを支払う（execute_spell_effectでは支払われないため）
	var cost = _get_spell_cost(spell_card)
	if player_system:
		player_system.add_magic(current_player_id, -cost)
	
	# 手札除去はexecute_spell_effect内で行われる
	
	selected_spell_card = spell_card
	spell_used_this_turn = true
	
	# 発動通知表示
	if spell_cast_notification_ui and player_system:
		var caster_name = "CPU"
		if current_player_id >= 0 and current_player_id < player_system.players.size():
			caster_name = player_system.players[current_player_id].name
		await _show_spell_cast_notification(caster_name, target, spell_card, false)
	
	# ターゲットを構築して効果実行
	var target_data = _build_cpu_target_data(spell_card, target)
	
	# 効果実行
	await execute_spell_effect(spell_card, target_data)

## CPUがミスティックアーツを実行
func _execute_cpu_mystic_arts(decision: Dictionary):
	var creature_tile = decision.get("creature_tile", -1)
	var mystic = decision.get("mystic", {})
	var mystic_data = decision.get("mystic_data", {})
	var target = decision.get("target", {})
	
	if creature_tile < 0 or mystic.is_empty():
		pass_spell(false)
		return
	
	print("[CPU] 秘術使用: %s (タイル%d)" % [mystic_data.get("name", "?"), creature_tile])
	
	# コストを支払う
	var cost = mystic.get("cost", 0)
	if player_system:
		player_system.add_magic(current_player_id, -cost)
	
	# 発動通知表示
	if spell_cast_notification_ui and board_system:
		var tile = board_system.get_tile_data(creature_tile)
		var creature = tile.get("placed_creature", {}) if tile else {}
		var caster_name = creature.get("name", "クリーチャー")
		await _show_spell_cast_notification(caster_name, target, mystic_data, true)
	
	# 秘術効果を実行（SpellMysticArtsを使用）
	if spell_mystic_arts and board_system:
		var target_data = _build_cpu_target_data(mystic_data, target)
		
		# creature辞書を構築（execute_mystic_artの形式に合わせる）
		var tile = board_system.get_tile_data(creature_tile)
		var creature_info = {
			"tile_index": creature_tile,
			"creature_data": tile.get("placed_creature", {}) if tile else {}
		}
		
		# player_idを設定
		spell_mystic_arts.current_mystic_player_id = current_player_id
		
		# 秘術実行（complete_spell_phaseはexecute_mystic_art内で呼ばれる）
		await spell_mystic_arts.execute_mystic_art(creature_info, mystic, target_data)
		return
	
	# SpellMysticArtsがない場合は完了
	complete_spell_phase()

## CPUターゲットデータを構築
func _build_cpu_target_data(spell_or_mystic: Dictionary, target: Dictionary) -> Dictionary:
	var effect_parsed = spell_or_mystic.get("effect_parsed", {})
	var target_type = effect_parsed.get("target_type", "")
	
	# ターゲットタイプに応じてデータを構築
	match target.get("type", ""):
		"self":
			return {"type": "player", "player_id": current_player_id}
		"player":
			return {"type": "player", "player_id": target.get("player_id", current_player_id)}
		"gate":
			# リミッション用: ゲートターゲット
			return {
				"type": "gate",
				"tile_index": target.get("tile_index", -1),
				"gate_key": target.get("gate_key", "")
			}
		"land":
			var tile_index = target.get("tile_index", -1)
			if tile_index >= 0 and board_system:
				var tile = board_system.get_tile_data(tile_index)
				if tile:
					return {"type": "land", "tile_index": tile_index, "tile_data": tile}
			return {"type": "none"}
		_:
			# クリーチャーターゲット
			if target.has("tile_index"):
				var tile_index = target.get("tile_index", -1)
				if tile_index >= 0 and board_system:
					var tile = board_system.get_tile_data(tile_index)
					if tile:
						var result = {
							"type": "creature",
							"tile_index": tile_index,
							"creature_data": target.get("creature", tile.get("placed_creature", {}))
						}
						# CPUが選んだ移動先があれば追加（アウトレイジ等用）
						if target.has("enemy_tile_index"):
							result["enemy_tile_index"] = target.get("enemy_tile_index")
						return result
	
	# デフォルト: セルフまたはなし
	if target_type == "self" or target_type.is_empty() or target_type == "none":
		return {"type": "player", "player_id": current_player_id}
	
	return {"type": "none"}

## スペルコストを支払えるか
func _can_afford_spell(spell_card: Dictionary) -> bool:
	if not player_system:
		return false
	
	var magic = player_system.get_magic(current_player_id)
	var cost = _get_spell_cost(spell_card)
	
	return magic >= cost

## スペルコストを取得（ウェイストワールド対応）
func _get_spell_cost(spell_card: Dictionary) -> int:
	var cost_data = spell_card.get("cost", {})
	if cost_data == null:
		cost_data = {}
	
	var base_cost = 0
	if typeof(cost_data) == TYPE_DICTIONARY:
		base_cost = cost_data.get("mp", 0)
	
	# ウェイストワールド（世界呪い）でコスト倍率を適用
	if game_flow_manager and game_flow_manager.spell_cost_modifier:
		return game_flow_manager.spell_cost_modifier.get_modified_cost(current_player_id, spell_card)
	
	return base_cost

## スペルを使用
func use_spell(spell_card: Dictionary):
	# 外部スペルモードでない場合のみ状態チェック
	if not is_external_spell_mode:
		if current_state != State.WAITING_FOR_INPUT:
			return
		
		if spell_used_this_turn:
			return
		
		if not _can_afford_spell(spell_card):
			return
	
	selected_spell_card = spell_card
	spell_used_this_turn = true
	
	# コストを支払う（常に実行）
	var cost = _get_spell_cost(spell_card)
	
	if player_system:
		player_system.add_magic(current_player_id, -cost)
	
	# ライフフォース呪いチェック（スペル無効化）
	if game_flow_manager.spell_cost_modifier:
		var nullify_result = game_flow_manager.spell_cost_modifier.check_spell_nullify(current_player_id)
		if nullify_result.get("nullified", false):
			# スペルは無効化 → カードを捨て札へ
			if ui_manager and ui_manager.phase_label:
				ui_manager.phase_label.text = nullify_result.get("message", "スペル無効化")
			# 手札からカードを除去（捨て札へ）
			if player_system:
				player_system.remove_card_from_hand(current_player_id, selected_spell_card)
			await get_tree().create_timer(1.5).timeout
			selected_spell_card = {}
			current_state = State.WAITING_FOR_INPUT
			return
	
	# カード犠牲処理（スペル合成用）
	var is_synthesized = false
	var disable_sacrifice = _is_card_sacrifice_disabled()
	if spell_synthesis and spell_synthesis.requires_sacrifice(spell_card) and not disable_sacrifice:
		# 手札選択UIを表示
		if card_sacrifice_helper:
			var sacrifice_card = await card_sacrifice_helper.show_hand_selection(
				current_player_id, "", "犠牲にするカードを選択"
			)
			
			if sacrifice_card.is_empty():
				# キャンセル時はコストを返却してスペルキャンセル
				if player_system:
					player_system.add_magic(current_player_id, cost)
				selected_spell_card = {}
				spell_used_this_turn = false
				current_state = State.WAITING_FOR_INPUT
				return
			
			# 合成条件判定
			is_synthesized = spell_synthesis.check_condition(spell_card, sacrifice_card)
			if is_synthesized:
				print("[SpellPhaseHandler] 合成成立: %s" % spell_card.get("name", "?"))
			
			# カードを破棄
			card_sacrifice_helper.consume_card(current_player_id, sacrifice_card)
	
	# 合成成立時はeffect_parsedを書き換え
	var parsed = spell_card.get("effect_parsed", {})
	if is_synthesized and spell_synthesis:
		parsed = spell_synthesis.apply_overrides(spell_card, true)
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
			var own_creature_count = _count_own_creatures(current_player_id)
			if own_creature_count < 2:
				if ui_manager and ui_manager.phase_label:
					ui_manager.phase_label.text = "対象がいません"
				await get_tree().create_timer(1.0).timeout
				cancel_spell()
				return
	
	# target_filter または target_type が "self" の場合 → 確認フェーズへ
	if target_filter == "self" or target_type == "self":
		var target_data = {"type": "player", "player_id": current_player_id}
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
		current_state = State.SELECTING_TARGET
		target_selection_required.emit(spell_card, target_type)
		
		# target_filterをtarget_infoに追加（get_valid_targetsで使用）
		if not target_filter.is_empty():
			target_info["target_filter"] = target_filter
		
		# 対象選択UIを表示
		var has_targets = await _show_target_selection_ui(target_type, target_info)
		if not has_targets:
			# 対象がいない場合
			if is_external_spell_mode:
				_external_spell_no_target = true  # 対象不在フラグ
			cancel_spell()
			return
	else:
		# target_type が空または "none" の場合 → 確認フェーズへ
		var target_data = {"type": "none"}
		_start_confirmation_phase("none", target_info, target_data)

## 対象選択UIを表示（領地コマンドと同じ方式）
## 戻り値: true=対象選択開始, false=対象なしでキャンセル
func _show_target_selection_ui(target_type: String, target_info: Dictionary) -> bool:
	# 有効な対象を取得（ヘルパー使用）
	var targets = TargetSelectionHelper.get_valid_targets(self, target_type, target_info)
	
	if targets.is_empty():
		# 対象がいない場合はメッセージ表示
		if ui_manager and ui_manager.phase_label:
			ui_manager.phase_label.text = "対象がいません"
		await get_tree().create_timer(1.0).timeout
		# キャンセル処理は呼び出し元に任せる
		return false
	
	# 領地コマンドと同じ方式で選択開始
	available_targets = targets
	current_target_index = 0
	current_state = State.SELECTING_TARGET
	
	# グローバルナビゲーション設定（対象選択用）
	_setup_target_selection_navigation()
	
	# 最初の対象を表示
	_update_target_selection()
	return true

## 選択を更新
func _update_target_selection():
	if available_targets.is_empty():
		return
	
	var target = available_targets[current_target_index]
	
	# 汎用ヘルパーを使用して視覚的に選択（クリーチャー情報パネルも自動表示）
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
	
	# 選択をクリア（クリーチャー情報パネルも自動で閉じる）
	TargetSelectionHelper.clear_selection(self)
	
	# 借用スペル実行中の場合（SpellBorrow用）
	if is_borrow_spell_mode:
		target_confirmed.emit(selected_target)
		is_borrow_spell_mode = false
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
	# 選択をクリア（クリーチャー情報パネルも自動で閉じる）
	TargetSelectionHelper.clear_selection(self)
	
	# 借用スペル実行中の場合（SpellBorrow用）
	if is_borrow_spell_mode:
		target_confirmed.emit({"cancelled": true})
		is_borrow_spell_mode = false
		return
	
	# 外部スペルモードの場合（魔法タイル等）
	if is_external_spell_mode:
		cancel_spell()
		return
	
	# 秘術かスペルかで分岐
	if spell_mystic_arts and spell_mystic_arts.is_active():
		# 秘術キャンセル
		spell_mystic_arts.clear_selection()
		spell_mystic_arts._end_mystic_phase()
		current_state = State.WAITING_FOR_INPUT
		# スペル選択画面に戻る
		_return_to_spell_selection()
	else:
		# スペルキャンセル
		cancel_spell()

## スペルをキャンセル（対象選択からスペル選択に戻る）
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
	
	# 確認フェーズ変数をクリア
	confirmation_target_type = ""
	confirmation_target_info = {}
	confirmation_target_data = {}
	
	# 外部スペルモードの場合
	if is_external_spell_mode:
		_external_spell_cancelled = true  # キャンセルフラグを立てる
		
		# 対象選択フェーズを抜ける共通処理
		_exit_target_selection_phase()
		
		current_state = State.INACTIVE
		# シグナルを遅延発火（use_spell()が完了してからawaitで受け取れるようにする）
		call_deferred("emit_signal", "external_spell_finished")
		return
	
	current_state = State.WAITING_FOR_INPUT
	
	# スペル選択UIを再表示
	_return_to_spell_selection()

## 対象選択フェーズを抜けるときの共通処理
func _exit_target_selection_phase():
	# 選択マーカーをクリア
	TargetSelectionHelper.clear_selection(self)
	
	# ナビゲーションをクリア
	_clear_spell_navigation()
	
	# カメラをプレイヤーに戻す
	_return_camera_to_player()
	
	# フェーズラベルをクリア
	if ui_manager and ui_manager.phase_label:
		ui_manager.phase_label.text = ""
	
	# UI更新
	if ui_manager and ui_manager.has_method("update_player_info_panels"):
		ui_manager.update_player_info_panels()

## スペル選択画面に戻る（UI再表示 + ナビゲーション再設定）
func _return_to_spell_selection():
	# 対象選択フェーズを抜ける共通処理
	_exit_target_selection_phase()
	
	# UIを更新してスペル選択モードに戻す
	if ui_manager:
		_update_spell_phase_ui()
		
		# フェーズラベル更新
		if ui_manager.phase_label:
			ui_manager.phase_label.text = "スペルを使用するか、ダイスを振ってください"
	
	# グローバルナビゲーションをスペル選択用に再設定
	_setup_spell_selection_navigation()
	
	# 秘術ボタンを再表示
	_show_spell_phase_buttons()

## スペル効果を実行（SpellEffectExecutorに委譲）
func execute_spell_effect(spell_card: Dictionary, target_data: Dictionary):
	if spell_effect_executor:
		await spell_effect_executor.execute_spell_effect(spell_card, target_data)

## 単一の効果を適用（SpellEffectExecutorに委譲）
func _apply_single_effect(effect: Dictionary, target_data: Dictionary):
	if spell_effect_executor:
		await spell_effect_executor.apply_single_effect(effect, target_data)


## 全クリーチャー対象スペルを実行（SpellEffectExecutorに委譲）
func _execute_spell_on_all_creatures(spell_card: Dictionary, target_info: Dictionary):
	if spell_effect_executor:
		await spell_effect_executor.execute_spell_on_all_creatures(spell_card, target_info)


# ============================================
# 確認フェーズ（全体対象/セルフ/世界呪い等）
# ============================================

## 確認フェーズを開始
func _start_confirmation_phase(target_type: String, target_info: Dictionary, target_data: Dictionary):
	current_state = State.CONFIRMING_EFFECT
	confirmation_target_type = target_type
	confirmation_target_info = target_info
	confirmation_target_data = target_data
	
	# 対象をハイライト表示
	var target_count = TargetSelectionHelper.show_confirmation_highlights(self, target_type, target_info)
	
	# 対象がいない場合（all_creaturesで防魔等で0体）
	if target_type == "all_creatures" and target_count == 0:
		if ui_manager and ui_manager.phase_label:
			ui_manager.phase_label.text = "対象となるクリーチャーがいません"
		await get_tree().create_timer(1.0).timeout
		cancel_spell()
		return
	
	# 説明テキストを表示
	var confirmation_text = TargetSelectionHelper.get_confirmation_text(target_type, target_count)
	if ui_manager and ui_manager.phase_label:
		ui_manager.phase_label.text = confirmation_text
	
	# ナビゲーションボタン設定（決定/戻る）
	if ui_manager:
		ui_manager.enable_navigation(
			func(): _confirm_spell_effect(),  # 決定
			func(): _cancel_confirmation()    # 戻る
		)


## 確認フェーズ: 効果発動を確定
func _confirm_spell_effect():
	if current_state != State.CONFIRMING_EFFECT:
		return
	
	# ハイライトとマーカーをクリア
	TargetSelectionHelper.clear_all_highlights(self)
	TargetSelectionHelper.hide_selection_marker(self)
	TargetSelectionHelper.clear_confirmation_markers(self)
	
	# ナビゲーションを無効化
	if ui_manager:
		ui_manager.disable_navigation()
	
	# 効果を実行
	var target_type = confirmation_target_type
	var target_info = confirmation_target_info
	var target_data = confirmation_target_data
	
	# 確認フェーズ変数をクリア
	confirmation_target_type = ""
	confirmation_target_info = {}
	confirmation_target_data = {}
	
	# 対象タイプに応じて実行
	match target_type:
		"self":
			execute_spell_effect(selected_spell_card, target_data)
		"all_creatures":
			_execute_spell_on_all_creatures(selected_spell_card, target_info)
		"all_players":
			execute_spell_effect(selected_spell_card, target_data)
		"world":
			execute_spell_effect(selected_spell_card, target_data)
		"none", _:
			execute_spell_effect(selected_spell_card, target_data)


## 確認フェーズ: キャンセル
func _cancel_confirmation():
	if current_state != State.CONFIRMING_EFFECT:
		return
	
	# ハイライトとマーカーをクリア
	TargetSelectionHelper.clear_all_highlights(self)
	TargetSelectionHelper.hide_selection_marker(self)
	TargetSelectionHelper.clear_confirmation_markers(self)
	
	# 確認フェーズ変数をクリア
	confirmation_target_type = ""
	confirmation_target_info = {}
	confirmation_target_data = {}
	
	# スペルをキャンセル
	cancel_spell()

## カメラを使用者に戻す
func _return_camera_to_player():
	if not player_system or not board_system:
		return
	
	# MovementControllerからプレイヤーの実際の位置を取得
	if board_system.movement_controller:
		var player_tile_index = board_system.movement_controller.get_player_tile(current_player_id)
		
		if board_system.camera and board_system.tile_nodes.has(player_tile_index):
			var tile_pos = board_system.tile_nodes[player_tile_index].global_position
			
			var new_camera_pos = tile_pos + Vector3(0, 1.0, 0) + GameConstants.CAMERA_OFFSET
			
			board_system.camera.position = new_camera_pos
			board_system.camera.look_at(tile_pos + Vector3(0, 1.0, 0), Vector3.UP)

## スペルをパス（×ボタンで呼ばれる）
## auto_roll: trueの場合、サイコロを自動で振る
func pass_spell(auto_roll: bool = true):
	spell_passed.emit()
	complete_spell_phase()
	
	# サイコロを自動で振る（×ボタン押下時）
	if auto_roll and game_flow_manager:
		# フェーズ遷移後に呼ぶ必要があるためcall_deferred使用
		game_flow_manager.roll_dice.call_deferred()

## タイルリストから選択（SpellCreatureMove用など）
## TargetSelectionHelperに委譲
func select_tile_from_list(tile_indices: Array, message: String) -> int:
	if tile_indices.is_empty():
		return -1
	
	# CPUの場合は自動選択（最初の候補を使用）
	if is_cpu_player(current_player_id):
		return tile_indices[0]
	
	# TargetSelectionHelperを取得して委譲
	if game_flow_manager and game_flow_manager.target_selection_helper:
		return await game_flow_manager.target_selection_helper.select_tile_from_list(tile_indices, message)
	
	# フォールバック：TargetSelectionHelperがない場合は最初のタイルを返す
	print("[SpellPhaseHandler] WARNING: TargetSelectionHelperが見つかりません、最初のタイルを選択")
	return tile_indices[0]



func execute_external_spell(spell_card: Dictionary, player_id: int) -> String:
	print("[SpellPhaseHandler] 外部スペル実行: %s (Player%d)" % [spell_card.get("name", "?"), player_id + 1])
	
	# 外部スペルモードを有効化
	is_external_spell_mode = true
	_external_spell_cancelled = false
	_external_spell_no_target = false
	
	# 現在のプレイヤーIDを保存して設定
	var original_player_id = current_player_id
	var original_state = current_state
	current_player_id = player_id
	current_state = State.WAITING_FOR_INPUT
	
	# use_spellを呼び出す（通常のスペルフェーズと同じ処理）
	await use_spell(spell_card)
	
	# 完了を待つ（対象選択がある場合はUIが表示され、選択後に進む）
	await external_spell_finished
	
	# 結果を保存
	var was_cancelled = _external_spell_cancelled
	var was_no_target = _external_spell_no_target
	
	# 外部スペルモードを無効化
	is_external_spell_mode = false
	_external_spell_cancelled = false
	_external_spell_no_target = false
	current_player_id = original_player_id
	current_state = original_state
	selected_spell_card = {}
	spell_used_this_turn = false  # 外部スペルはターン制限に影響しない
	
	print("[SpellPhaseHandler] 外部スペル完了 (cancelled: %s, no_target: %s)" % [was_cancelled, was_no_target])
	
	# 全て文字列で返す
	if was_no_target:
		return "no_target"
	elif was_cancelled:
		return "cancelled"
	else:
		return "success"

## スペルフェーズ完了
func complete_spell_phase():
	if current_state == State.INACTIVE:
		return
	
	# 外部スペルモードの場合
	if is_external_spell_mode:
		current_state = State.INACTIVE
		external_spell_finished.emit()
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
	
	# グローバルナビゲーションをクリア
	_clear_spell_navigation()
	
	# カメラを追従モードに戻す（位置は移動処理で自然に戻る）
	if board_system and board_system.camera_controller:
		board_system.camera_controller.enable_follow_mode()
	
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

## スペル関連のコンテキストを構築（世界呪い等）
func _build_spell_context() -> Dictionary:
	var context = {}
	
	if game_flow_manager and "game_stats" in game_flow_manager:
		context["world_curse"] = game_flow_manager.game_stats.get("world_curse", {})
	
	return context

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
		
		# 参照を設定（spell_phase_ui_managerはSpellAndMysticUI等に使用）
		spell_phase_ui_manager.spell_phase_handler_ref = self
		# 秘術ボタン/スペルスキップボタンはグローバルボタンに移行済み

## スペルフェーズ開始時にボタンを表示
func _show_spell_phase_buttons():
	# 秘術ボタンは使用可能なクリーチャーがいる場合のみ表示（特殊ボタン使用）
	if ui_manager and has_available_mystic_arts(current_player_id):
		ui_manager.show_mystic_button(func(): start_mystic_arts_phase())
	# 「スペルを使わない」ボタンは✓ボタンに置き換えたため表示しない

## スペルフェーズ終了時にボタンを非表示
func _hide_spell_phase_buttons():
	# 特殊ボタンをクリア
	if ui_manager:
		ui_manager.hide_mystic_button()


# ============ グローバルナビゲーション設定 ============

## スペル選択時のナビゲーション設定（決定 = スペルを使わない → サイコロ）
func _setup_spell_selection_navigation():
	if ui_manager:
		ui_manager.enable_navigation(
			func(): pass_spell(),  # 決定 = スペルを使わない → サイコロを振る
			Callable()             # 戻るなし
		)

## 対象選択時のナビゲーション設定
func _setup_target_selection_navigation():
	if ui_manager:
		ui_manager.enable_navigation(
			func(): _on_target_confirm(),   # 決定
			func(): _on_target_cancel(),    # 戻る
			func(): _on_target_prev(),      # 上
			func(): _on_target_next()       # 下
		)

## ナビゲーションをクリア
func _clear_spell_navigation():
	if ui_manager:
		ui_manager.disable_navigation()

## 対象選択：決定
func _on_target_confirm():
	if current_state != State.SELECTING_TARGET:
		return
	_confirm_target_selection()

## 対象選択：キャンセル
func _on_target_cancel():
	if current_state != State.SELECTING_TARGET:
		return
	_cancel_target_selection()

## 対象選択：前の対象へ
func _on_target_prev():
	if current_state != State.SELECTING_TARGET:
		return
	if available_targets.size() <= 1:
		return
	
	current_target_index = (current_target_index - 1 + available_targets.size()) % available_targets.size()
	_update_target_selection()

## 対象選択：次の対象へ
func _on_target_next():
	if current_state != State.SELECTING_TARGET:
		return
	if available_targets.size() <= 1:
		return
	
	current_target_index = (current_target_index + 1) % available_targets.size()
	_update_target_selection()


## 秘術ボタンの表示状態を更新（外部から呼び出し可能）
func update_mystic_button_visibility():
	if not ui_manager or current_state == State.INACTIVE:
		return
	
	if has_available_mystic_arts(current_player_id):
		ui_manager.show_mystic_button(func(): start_mystic_arts_phase())
	else:
		ui_manager.hide_mystic_button()

## 秘術使用時にスペルボタンを隠す
func _on_mystic_art_used():
	# 秘術使用時は秘術ボタンを非表示
	if ui_manager:
		ui_manager.hide_mystic_button()


## 秘術フェーズ完了時
func _on_mystic_phase_completed():
	current_state = State.WAITING_FOR_INPUT


## 秘術ターゲット選択要求時
func _on_mystic_target_selection_requested(targets: Array):
	available_targets = targets
	current_target_index = 0
	current_state = State.SELECTING_TARGET
	
	# グローバルナビゲーション設定（対象選択用 - 秘術でも戻るボタンを表示）
	_setup_target_selection_navigation()
	
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
	
	# 選択完了シグナルを接続（重複接続防止）
	if not card_selection_handler.selection_completed.is_connected(_on_card_selection_completed):
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


## カード犠牲が無効化されているか（TileActionProcessorから取得）
func _is_card_sacrifice_disabled() -> bool:
	if board_system and board_system.tile_action_processor:
		return board_system.tile_action_processor.debug_disable_card_sacrifice
	return false


## 土地条件が無効化されているか（TileActionProcessorから取得）
func _is_lands_required_disabled() -> bool:
	if board_system and board_system.tile_action_processor:
		return board_system.tile_action_processor.debug_disable_lands_required
	return false


## 手札更新時にボタン位置を再計算（グローバルボタンは自動配置のため空実装）
func _on_hand_updated_for_buttons():
	# グローバルボタンに移行したため、手動での位置更新は不要
	pass
