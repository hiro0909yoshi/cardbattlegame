# ItemPhaseHandler - アイテム/巻物選択フェーズの処理を担当
extends Node
class_name ItemPhaseHandler

## シグナル
signal item_phase_started()
signal item_phase_completed()
signal item_passed()  # アイテム未使用
signal item_used(item_card: Dictionary)
signal creature_merged(merged_data: Dictionary)  # 合体発生時

## Phase 8-A: UI Signal（ui_manager 直接参照を排除）
@warning_ignore("unused_signal")  # GameSystemManager で接続
signal item_filter_configured(config: Dictionary)
@warning_ignore("unused_signal")  # GameSystemManager で接続
signal item_filter_cleared()
@warning_ignore("unused_signal")  # GameSystemManager で接続
signal item_hand_display_update_requested(player_id: int)
@warning_ignore("unused_signal")  # GameSystemManager で接続
signal item_selection_ui_show_requested(player, mode: String)

## 状態
enum State {
	INACTIVE,
	WAITING_FOR_SELECTION,  # アイテム選択待ち
	ITEM_APPLIED            # アイテム適用済み
}

var current_state: State = State.INACTIVE
var current_player_id: int = -1
var selected_item_card: Dictionary = {}
var item_used_this_battle: bool = false  # 1バトル1回制限
var battle_creature_data: Dictionary = {}  # バトル参加クリーチャーのデータ（加勢/合体判定用）
var merged_creature_data: Dictionary = {}  # 合体後のクリーチャーデータ
var opponent_creature_data: Dictionary = {}  # 相手クリーチャーのデータ（無効化判定用）

# 無効化判定用・シミュレーション用
const BattleSpecialEffectsScript = preload("res://scripts/battle/battle_special_effects.gd")
const BattleParticipantScript = preload("res://scripts/battle/battle_participant.gd")
const BattleSimulatorScript = preload("res://scripts/cpu_ai/battle_simulator.gd")
const CPUBattlePolicyScript = preload("res://scripts/cpu_ai/cpu_battle_policy.gd")

# 防御時のタイル情報（シミュレーション用）
var defense_tile_info: Dictionary = {}

# 現在のフェーズが攻撃側かどうか
var _is_current_phase_attacker: bool = false

# 手札ユーティリティ（ワーストケースシミュレーション用）
var cpu_hand_utils: CPUHandUtils = null

# CPUBattleAI（共通バトル評価用）
var cpu_battle_ai: CPUBattleAI = null

# CPU防御AI
var cpu_defense_ai: CPUDefenseAI = null

## 参照
var game_flow_manager = null
var card_system = null
var player_system = null
var battle_system = null
var tile_action_processor = null  # デバッグフラグ参照用

# === 直接参照（GFM経由を廃止） ===
var spell_cost_modifier = null  # SpellCostModifier: コスト計算
var board_system_3d = null  # BoardSystem3D: ボードシステム

func _ready():
	pass

## 初期化
func initialize(flow_mgr, c_system = null, p_system = null, b_system = null):
	game_flow_manager = flow_mgr
	card_system = c_system if c_system else (flow_mgr.card_system if flow_mgr else null)
	player_system = p_system if p_system else (flow_mgr.player_system if flow_mgr else null)
	battle_system = b_system if b_system else (flow_mgr.battle_system if flow_mgr else null)

	# TileActionProcessor参照を取得（デバッグフラグ用）
	if flow_mgr and flow_mgr.board_system_3d:
		board_system_3d = flow_mgr.board_system_3d
		tile_action_processor = board_system_3d.tile_action_processor

	# CPU AI共有コンテキストをGameSystemManagerから設定（P0統一）
	# game_flow_manager は GameSystemManager の子なので、親を取得
	if flow_mgr and flow_mgr.get_parent():
		var game_system_manager = flow_mgr.get_parent()
		if game_system_manager is GameSystemManager:
			set_cpu_context_references(game_system_manager)

## GameSystemManager から CPU AI 参照を設定（P0統一）
func set_cpu_context_references(game_system_manager: Node) -> void:
	if not game_system_manager:
		return

	cpu_hand_utils = game_system_manager.cpu_hand_utils
	cpu_battle_ai = game_system_manager.cpu_battle_ai
	cpu_defense_ai = game_system_manager.cpu_defense_ai

	# バトルポリシーを設定
	if cpu_defense_ai and game_system_manager.has_method("_get_cpu_battle_policy"):
		var policy = game_system_manager._get_cpu_battle_policy()
		if policy:
			cpu_defense_ai.set_battle_policy(policy)

## 直接参照を設定（GFM経由を廃止）
func set_spell_cost_modifier(cost_modifier) -> void:
	spell_cost_modifier = cost_modifier
	print("[ItemPhaseHandler] spell_cost_modifier 直接参照を設定")

## アイテムフェーズ開始
## defender_tile_info: 攻撃側フェーズ開始時に防御側情報を渡す（防御側CPUの事前選択用）
func start_item_phase(player_id: int, creature_data: Dictionary = {}, defender_tile_info: Dictionary = {}):
	if current_state != State.INACTIVE:
		return
	
	# defender_tile_info が渡された場合 = 攻撃側のアイテムフェーズ開始
	var is_attacker_phase = not defender_tile_info.is_empty()
	
	# 🎯 攻撃側フェーズ開始時に防御側の事前選択をクリア
	# （攻撃側の事前選択はDominioCommandHandlerで設定されるので、ここではクリアしない）
	if is_attacker_phase:
		clear_preselected_defender_item()
		
		var defender_owner = defender_tile_info.get("owner", -1)
		if defender_owner >= 0 and game_flow_manager and game_flow_manager.is_cpu_player(defender_owner):
			var defender_creature = defender_tile_info.get("creature", {})
			preselect_defender_item(
				defender_owner,
				defender_creature,
				creature_data,  # 攻撃側クリーチャー
				defender_tile_info
			)
	
	current_state = State.WAITING_FOR_SELECTION
	current_player_id = player_id
	item_used_this_battle = false
	selected_item_card = {}
	battle_creature_data = creature_data
	_is_current_phase_attacker = is_attacker_phase  # 攻撃側か防御側かを記録
	merged_creature_data = {}  # 合体データをリセット
	
	# 消沈刻印チェック（防御側のみ刻印を持つ可能性がある）
	if SpellCurseBattle.has_battle_disable(creature_data):
		print("【消沈】", creature_data.get("name", "?"), " はアイテム・加勢使用不可 → 強制パス")
		pass_item()
		return
	
	item_phase_started.emit()
	
	# CPUの場合のアイテム判断
	if game_flow_manager and game_flow_manager.is_cpu_player(player_id):
		if _is_current_phase_attacker:
			# 攻撃側CPU
			if not _preselected_attacker_item.is_empty():
				print("[CPU攻撃] 事前選択アイテムを使用: %s" % _preselected_attacker_item.get("name", "?"))
				use_item(_preselected_attacker_item)
				_preselected_attacker_item = {}  # 使用後クリア
				return
			else:
				# 攻撃側で事前選択がない場合はパス
				# （侵略判断時にアイテムなしで勝てると判断している）
				print("[CPU攻撃] 事前選択なし → パス")
				pass_item()
				return
		else:
			# 防御側CPU
			_cpu_decide_item()
			return
	
	# 人間プレイヤーの場合はUI表示
	await _show_item_selection_ui()

## 加勢スキルを持っているかチェック
func has_assist_skill() -> bool:
	if battle_creature_data.is_empty():
		return false
	
	var ability_parsed = battle_creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	return "加勢" in keywords

## 加勢対象の属性を取得
func get_assist_target_elements() -> Array:
	if not has_assist_skill():
		return []
	
	var ability_parsed = battle_creature_data.get("ability_parsed", {})
	var keyword_conditions = ability_parsed.get("keyword_conditions", {})
	var assist_condition = keyword_conditions.get("加勢", {})
	return assist_condition.get("target_elements", [])

## 合体スキルを持っているかチェック
func has_merge_skill() -> bool:
	return SkillMerge.has_merge_skill(battle_creature_data)

## 合体相手のIDを取得
func get_merge_partner_id() -> int:
	return SkillMerge.get_merge_partner_id(battle_creature_data)

## 合体結果のIDを取得
func get_merge_result_id() -> int:
	return SkillMerge.get_merge_result_id(battle_creature_data)

## 合体が発生したかどうか
func was_merged() -> bool:
	return not merged_creature_data.is_empty()

## 合体後のクリーチャーデータを取得
func get_merged_creature() -> Dictionary:
	return merged_creature_data

## アイテム選択UIを表示
func _show_item_selection_ui():
	# カメラを手動モードに設定（マップ確認可能にする）
	if board_system_3d:
		board_system_3d.enable_manual_camera()

	if not card_system or not player_system:
		complete_item_phase()
		return

	# current_player_idを使用（防御側のアイテムフェーズでは防御側のプレイヤー情報が必要）
	if current_player_id < 0 or current_player_id >= player_system.players.size():
		complete_item_phase()
		return

	var current_player = player_system.players[current_player_id]
	if not current_player:
		complete_item_phase()
		return

	# 手札を取得
	var hand_data = card_system.get_all_cards_for_player(current_player_id)

	# アイテムカードと加勢対象/合体相手クリーチャーカードを収集
	var selectable_cards = []
	var has_assist = has_assist_skill()
	var assist_elements = get_assist_target_elements()
	var has_merge = has_merge_skill()
	var merge_partner_id = get_merge_partner_id()

	# metal_form刻印がある場合、防具使用不可
	var has_metal_form = SpellCurseBattle.has_metal_form(battle_creature_data)
	if has_metal_form:
		print("【メタルフォーム】", battle_creature_data.get("name", "?"), " は防具使用不可")

	for card in hand_data:
		var card_type = card.get("type", "")

		# アイテムカードは常に選択可能（metal_formの場合は防具がUIでグレーアウトされる）
		if card_type == "item":
			selectable_cards.append(card)
		elif card_type == "creature":
			var card_id = card.get("id", -1)

			# レリック判定
			var keywords = card.get("ability_parsed", {}).get("keywords", [])
			if "レリック" in keywords:
				selectable_cards.append(card)
			# 合体相手判定
			elif has_merge and card_id == merge_partner_id:
				selectable_cards.append(card)
			# 加勢スキルがある場合、対象クリーチャーも選択可能
			elif has_assist:
				var card_element = card.get("element", "")
				# 全属性対象の場合
				if "all" in assist_elements:
					selectable_cards.append(card)
				# 特定属性のみ対象
				elif card_element in assist_elements:
					selectable_cards.append(card)

	if selectable_cards.is_empty():
		complete_item_phase()
		return

	# フィルター設定（Signal駆動）
	var blocked_types: Array = []

	# metal_form刻印がある場合、防具をブロック
	if has_metal_form:
		blocked_types.append("防具")

	# cannot_use制限をチェック（デバッグフラグまたはリリース刻印で無効化可能）
	var disable_cannot_use = tile_action_processor and tile_action_processor.debug_disable_cannot_use
	# リリース刻印チェック
	if not disable_cannot_use and player_system and current_player_id < player_system.players.size():
		var player = player_system.players[current_player_id]
		var player_dict = {"curse": player.curse}
		if SpellRestriction.is_item_restriction_released(player_dict):
			disable_cannot_use = true
			print("【リリース刻印】アイテム制限を無視")
	if not disable_cannot_use:
		var cannot_use_list = ItemUseRestriction.get_cannot_use_list(battle_creature_data)
		if not cannot_use_list.is_empty():
			print("【アイテム使用制限】", battle_creature_data.get("name", "?"), " は使用不可: ", cannot_use_list)
			for item_type in cannot_use_list:
				if item_type not in blocked_types:
					blocked_types.append(item_type)

	var filter_config = {
		"blocked_item_types": blocked_types,
		"card_selection_filter": "item_or_assist" if has_assist else "item",
		"assist_target_elements": assist_elements if has_assist else []
	}
	item_filter_configured.emit(filter_config)

	# 手札表示を更新（Signal駆動）
	item_hand_display_update_requested.emit(current_player_id)

	# フレーム待機して手札が描画されるまで待つ
	await get_tree().process_frame

	# カード選択UI表示（Signal駆動）
	item_selection_ui_show_requested.emit(current_player, "item")

## アイテムまたは加勢/合体クリーチャーを使用
func use_item(item_card: Dictionary):
	if current_state != State.WAITING_FOR_SELECTION:
		return
	
	if item_used_this_battle:
		return
	
	# カードタイプを判定
	var card_type = item_card.get("type", "")
	var card_id = item_card.get("id", -1)
	
	# アイテムの場合、cannot_use制限をチェック（デバッグフラグまたはリリース刻印で無効化可能）
	if card_type == "item":
		var disable_cannot_use = tile_action_processor and tile_action_processor.debug_disable_cannot_use
		# リリース刻印チェック
		if not disable_cannot_use and player_system and current_player_id < player_system.players.size():
			var player = player_system.players[current_player_id]
			var player_dict = {"curse": player.curse}
			if SpellRestriction.is_item_restriction_released(player_dict):
				disable_cannot_use = true
		if not disable_cannot_use:
			var check_result = ItemUseRestriction.check_can_use(battle_creature_data, item_card)
			if not check_result.can_use:
				print("[ItemPhaseHandler] アイテム使用制限: %s" % check_result.reason)
				return
	
	# クリーチャーの場合の追加チェック
	if card_type == "creature":
		# レリック判定
		var keywords = item_card.get("ability_parsed", {}).get("keywords", [])
		var is_item_creature = "レリック" in keywords
		
		if not is_item_creature:
			# 合体相手かチェック
			var merge_partner_id = get_merge_partner_id()
			if has_merge_skill() and card_id == merge_partner_id:
				# 合体処理
				_execute_merge(item_card)
				return
			
			# 加勢クリーチャーの場合
			if not has_assist_skill():
				return
			
			var card_element = item_card.get("element", "")
			var assist_elements = get_assist_target_elements()
			
			# 属性チェック
			if not ("all" in assist_elements or card_element in assist_elements):
				return
	
	# コストチェック
	if not _can_afford_card(item_card):
		return
	
	selected_item_card = item_card
	item_used_this_battle = true
	current_state = State.ITEM_APPLIED
	
	# コストを支払う（アイテムカードのコストはmp値そのまま = 等倍）
	var cost_data = item_card.get("cost", {})
	var cost = 0
	if typeof(cost_data) == TYPE_DICTIONARY:
		cost = cost_data.get("ep", 0)  # アイテムはmp値をそのまま使用（等倍）
	else:
		cost = cost_data
	
	# エンジェルギフト刻印チェック（アイテムコスト0化）
	if spell_cost_modifier:
		cost = spell_cost_modifier.get_modified_cost(current_player_id, item_card)
	
	if player_system:
		player_system.add_magic(current_player_id, -cost)
	
	
	# アイテムをカード使用（捨て札に）
	if card_system:
		var hand = card_system.get_all_cards_for_player(current_player_id)
		for i in range(hand.size()):
			if hand[i].get("id", -1) == item_card.get("id", -2):
				card_system.discard_card(current_player_id, i, "use")
				break
	
	# カード使用シグナル
	var _item_name = item_card.get("name", "?")
	var _item_id = item_card.get("id", -1)
	var _phase_side = "攻撃側" if _is_current_phase_attacker else "防御側"
	GameLogger.info("Battle", "アイテム使用: P%d %s %s(id:%d)" % [current_player_id + 1, _phase_side, _item_name, _item_id])
	item_used.emit(item_card)

	# フェーズ完了
	complete_item_phase()

## 合体処理を実行（SkillMerge.execute_merge()に委譲）
func _execute_merge(partner_card: Dictionary):
	# 手札からパートナーのインデックスを検索
	var partner_index = -1
	if card_system:
		var hand = card_system.get_all_cards_for_player(current_player_id)
		for i in range(hand.size()):
			if hand[i].get("id", -1) == partner_card.get("id", -2):
				partner_index = i
				break
	
	if partner_index < 0:
		print("[ItemPhaseHandler] 合体相手が手札に見つかりません")
		return
	
	# SkillMergeに委譲
	var merge_result = SkillMerge.execute_merge(
		battle_creature_data,
		partner_index,
		current_player_id,
		card_system,
		player_system,
		spell_cost_modifier
	)
	
	if not merge_result.get("success", false):
		print("[ItemPhaseHandler] 合体失敗")
		return
	
	item_used_this_battle = true
	current_state = State.ITEM_APPLIED
	
	# 合体後データを保存
	merged_creature_data = merge_result.get("result_creature", {})
	var _merge_name = merged_creature_data.get("name", "?")
	var _merge_id = merged_creature_data.get("id", -1)
	GameLogger.info("Battle", "合体: P%d %s(id:%d) → %s(id:%d)" % [current_player_id + 1, battle_creature_data.get("name", "?"), battle_creature_data.get("id", -1), _merge_name, _merge_id])

	# シグナル発信
	creature_merged.emit(merged_creature_data)
	
	# フェーズ完了
	complete_item_phase()

## アイテムをパス（使用しない）
func pass_item():
	if current_state != State.WAITING_FOR_SELECTION:
		return
	

	item_passed.emit()
	complete_item_phase()

## アイテムフェーズ完了
func complete_item_phase():
	if current_state == State.INACTIVE:
		return
	
	current_state = State.INACTIVE
	
	# バトルクリーチャーデータをクリア（次のバトルに引き継がないため）
	battle_creature_data = {}
	
	# 攻撃側の事前選択アイテムをクリア（次のバトルに引き継がないため）
	# ※使用後は既にuse_item内でクリアされるが、パスした場合などに備えてここでもクリア
	clear_preselected_attacker_item()

	# フィルターをクリア（Signal駆動）
	item_filter_cleared.emit()
	# 手札表示を更新してグレーアウトを解除
	if player_system:
		var current_player = player_system.get_current_player()
		if current_player:
			item_hand_display_update_requested.emit(current_player.id)

	item_phase_completed.emit()
	


## カードが使用可能か（コスト的に）
func _can_afford_card(card_data: Dictionary) -> bool:
	if not player_system:
		return false
	
	var current_player = player_system.get_current_player()
	if not current_player:
		return false
	
	var cost_data = card_data.get("cost", {})
	var cost = 0
	if typeof(cost_data) == TYPE_DICTIONARY:
		cost = cost_data.get("ep", 0)  # アイテムはmp値をそのまま使用（等倍）
	else:
		cost = cost_data
	
	# エンジェルギフト刻印チェック（アイテムコスト0化）
	if spell_cost_modifier:
		cost = spell_cost_modifier.get_modified_cost(current_player_id, card_data)
	
	return current_player.magic_power >= cost

## 選択されたアイテムを取得
func get_selected_item() -> Dictionary:
	return selected_item_card

## アイテムが使用されたか
func was_item_used() -> bool:
	return item_used_this_battle

## アクティブか
func is_item_phase_active() -> bool:
	return current_state != State.INACTIVE

## カード選択を処理（GFMのルーティング用）
## 戻り値: true=処理済み, false=処理不要
func try_handle_card_selection(card_index: int) -> bool:
	# アイテムフェーズがアクティブでない場合は処理しない
	if not is_item_phase_active():
		return false

	# 手札を取得
	if not card_system:
		return true

	var hand = card_system.get_all_cards_for_player(current_player_id)

	if card_index >= hand.size():
		return true

	var card = hand[card_index]
	var card_type = card.get("type", "")

	# アイテムカードまたは加勢対象クリーチャーが使用可能
	if card_type == "item":
		use_item(card)
		return true
	elif card_type == "creature":
		# レリック判定
		var keywords = card.get("ability_parsed", {}).get("keywords", [])
		if "レリック" in keywords:
			use_item(card)
			return true
		# 加勢スキルがある場合のみクリーチャーを使用可能
		elif has_assist_skill():
			var assist_elements = get_assist_target_elements()
			var card_element = card.get("element", "")
			# 対象属性かチェック
			if "all" in assist_elements or card_element in assist_elements:
				use_item(card)
				return true
		return true
	else:
		return true

## 相手クリーチャーデータを設定（防御側アイテムフェーズ用）
func set_opponent_creature(creature_data: Dictionary):
	opponent_creature_data = creature_data

## 防御時のタイル情報を設定
func set_defense_tile_info(tile_info: Dictionary):
	defense_tile_info = tile_info

## CPU攻撃側の事前選択アイテムを設定
## バトルAIで決定したアイテムをセットし、アイテムフェーズで自動使用
var _preselected_attacker_item: Dictionary = {}

func set_preselected_attacker_item(item_data: Dictionary):
	_preselected_attacker_item = item_data
	if not item_data.is_empty():
		print("[ItemPhaseHandler] CPU攻撃側事前選択アイテム: %s" % item_data.get("name", "?"))

func clear_preselected_attacker_item():
	_preselected_attacker_item = {}

## CPU防御側の事前選択アイテム（攻撃側アイテムフェーズ前に決定）
var _preselected_defender_item: Dictionary = {}
var _defender_preselection_done: bool = false  # 事前選択が実行されたかどうか

## CPU防御側のアイテムを事前選択
## 攻撃側がアイテムを選ぶ前に呼び出すことで、攻撃側の手札を正しく参照できる
func preselect_defender_item(defender_player_id: int, defender_creature: Dictionary, attacker_creature: Dictionary, tile_info: Dictionary):
	# 事前選択状態をリセット
	_preselected_defender_item = {}
	_defender_preselection_done = false
	
	print("[CPU防御事前選択] 開始: %s vs %s" % [defender_creature.get("name", "?"), attacker_creature.get("name", "?")])
	
	# 消沈刻印チェック
	if SpellCurseBattle.has_battle_disable(defender_creature):
		print("[CPU防御事前選択] 消沈 → 終了")
		_defender_preselection_done = true
		return
	
	# CPU AI参照を確認（initialize()で既に設定済み）
	# バトルポリシーは initialize() で設定済みなので、追加設定は不要
	if not cpu_defense_ai:
		print("[CPU防御事前選択] WARNING: cpu_defense_ai が初期化されていません")
		_defender_preselection_done = true
		return
	
	# 攻撃側プレイヤーID取得
	var attacker_player_id = -1
	if board_system_3d:
		attacker_player_id = board_system_3d.current_player_index
	
	# コンテキスト構築
	var context = {
		"player_id": defender_player_id,
		"defender_creature": defender_creature,
		"attacker_creature": attacker_creature,
		"tile_info": tile_info,
		"attacker_player_id": attacker_player_id
	}
	
	# CPU防御AIに判断を委譲
	var decision = cpu_defense_ai.decide_defense_action(context)
	
	_defender_preselection_done = true
	
	match decision.get("action", "pass"):
		"item":
			_preselected_defender_item = decision.item
			print("[CPU防御事前選択] アイテム決定: %s" % decision.item.get("name", "?"))
		"support":
			_preselected_defender_item = decision.creature
			print("[CPU防御事前選択] 加勢決定: %s" % decision.creature.get("name", "?"))
		"merge":
			_preselected_defender_item = {"_is_merge": true, "merge_data": decision.merge_data}
			print("[CPU防御事前選択] 合体決定: %s" % decision.merge_data.get("result_name", "?"))
		_:
			print("[CPU防御事前選択] アイテムなし")

func clear_preselected_defender_item():
	_preselected_defender_item = {}
	_defender_preselection_done = false

## CPU防御時のアイテム判断
## 事前選択されたアイテムがあればそれを使用
## なければ従来のロジックで判断
func _cpu_decide_item():
	print("[CPU防御] アイテム判断開始: %s vs %s" % [
		battle_creature_data.get("name", "?"),
		opponent_creature_data.get("name", "?")
	])
	
	# 事前選択が実行済みの場合
	if _defender_preselection_done:
		if not _preselected_defender_item.is_empty():
			# 合体の場合
			if _preselected_defender_item.get("_is_merge", false):
				var merge_data = _preselected_defender_item.get("merge_data", {})
				print("[CPU防御] 事前選択: 合体を実行 → %s" % merge_data.get("result_name", "?"))
				_execute_merge_for_cpu(merge_data)
				clear_preselected_defender_item()
				return
			
			print("[CPU防御] 事前選択アイテム使用: %s" % _preselected_defender_item.get("name", "?"))
			var item_to_use = _preselected_defender_item
			clear_preselected_defender_item()
			use_item(item_to_use)
			return
		else:
			# 事前選択でアイテムなしと判断された場合はパス
			print("[CPU防御] 事前選択済み: アイテムなし → パス")
			clear_preselected_defender_item()
			pass_item()
			return
	
	# 事前選択が実行されていない場合はCPUDefenseAIに委譲
	print("[CPU防御] 事前選択未実行 → CPUDefenseAIで判断")
	
	if not cpu_defense_ai:
		print("[CPU防御] cpu_defense_ai未初期化 → パス")
		pass_item()
		return
	
	# コンテキストを構築
	var tile_info = _get_defense_tile_info()
	var attacker_player_id = -1
	if board_system_3d:
		attacker_player_id = board_system_3d.current_player_index
	
	var context = {
		"player_id": current_player_id,
		"defender_creature": battle_creature_data,
		"attacker_creature": opponent_creature_data,
		"tile_info": tile_info,
		"attacker_player_id": attacker_player_id
	}
	
	# 判断を委譲
	var decision = cpu_defense_ai.decide_defense_action(context)
	
	# 結果に応じて実行
	match decision.get("action", "pass"):
		"item":
			print("[CPU防御] アイテム使用: %s" % decision.item.get("name", "?"))
			use_item(decision.item)
		"support":
			print("[CPU防御] 加勢使用: %s" % decision.creature.get("name", "?"))
			use_item(decision.creature)
		"merge":
			print("[CPU防御] 合体実行: %s" % decision.merge_data.get("result_name", "?"))
			_execute_merge_for_cpu(decision.merge_data)
		_:
			print("[CPU防御] パス")
			pass_item()


## 防御時のタイル情報を取得
func _get_defense_tile_info() -> Dictionary:
	if not defense_tile_info.is_empty():
		return defense_tile_info
	
	# フォールバック: 現在のプレイヤー位置から取得
	if board_system_3d:
		var board = board_system_3d
		if board.movement_controller:
			var tile_index = board.get_player_tile(current_player_id)
			if tile_index >= 0:
				return board.get_tile_info(tile_index)
	
	return {}


## CPUが合体を実行（SkillMerge.execute_merge()に委譲）
func _execute_merge_for_cpu(merge_result: Dictionary):
	var partner_index = merge_result.get("partner_index", -1)
	
	if partner_index < 0:
		print("[CPU合体] 無効なパートナーインデックス")
		pass_item()
		return
	
	# SkillMergeに委譲
	var skill_merge_result = SkillMerge.execute_merge(
		battle_creature_data,
		partner_index,
		current_player_id,
		card_system,
		player_system,
		spell_cost_modifier
	)
	
	if not skill_merge_result.get("success", false):
		print("[CPU合体] 合体失敗")
		pass_item()
		return
	
	# 合体後のデータを保存
	merged_creature_data = skill_merge_result.get("result_creature", {})
	battle_creature_data = merged_creature_data
	
	print("[CPU合体] 完了: %s" % merged_creature_data.get("name", "?"))
	
	# 合体シグナルを発行
	creature_merged.emit(merged_creature_data)
	
	# アイテムフェーズ完了
	current_state = State.ITEM_APPLIED
	item_phase_completed.emit()

# =============================================================================
# CPU AI コンテキスト初期化（GameSystemManagerで管理されているため削除）
# =============================================================================
# 代わりに set_cpu_context_references() を使用して GameSystemManager から参照を取得
