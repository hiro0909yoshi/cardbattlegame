# ItemPhaseHandler - アイテム/巻物選択フェーズの処理を担当
extends Node
class_name ItemPhaseHandler

## シグナル
signal item_phase_started()
signal item_phase_completed()
signal item_passed()  # アイテム未使用
signal item_used(item_card: Dictionary)
signal creature_merged(merged_data: Dictionary)  # 合体発生時

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
var battle_creature_data: Dictionary = {}  # バトル参加クリーチャーのデータ（援護/合体判定用）
var merged_creature_data: Dictionary = {}  # 合体後のクリーチャーデータ
var opponent_creature_data: Dictionary = {}  # 相手クリーチャーのデータ（無効化判定用）

# 無効化判定用・シミュレーション用
const BattleSpecialEffectsScript = preload("res://scripts/battle/battle_special_effects.gd")
const BattleParticipantScript = preload("res://scripts/battle/battle_participant.gd")
const BattleSimulatorScript = preload("res://scripts/cpu_ai/battle_simulator.gd")

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
var ui_manager = null
var game_flow_manager = null
var card_system = null
var player_system = null
var battle_system = null
var tile_action_processor = null  # デバッグフラグ参照用

func _ready():
	pass

## 初期化
func initialize(ui_mgr, flow_mgr, c_system = null, p_system = null, b_system = null):
	ui_manager = ui_mgr
	game_flow_manager = flow_mgr
	card_system = c_system if c_system else (flow_mgr.card_system if flow_mgr else null)
	player_system = p_system if p_system else (flow_mgr.player_system if flow_mgr else null)
	battle_system = b_system if b_system else (flow_mgr.battle_system if flow_mgr else null)
	
	# TileActionProcessor参照を取得（デバッグフラグ用）
	if flow_mgr and flow_mgr.board_system_3d:
		tile_action_processor = flow_mgr.board_system_3d.tile_action_processor
	
	# CPU手札ユーティリティを初期化（ワーストケースシミュレーション用）
	if not cpu_hand_utils:
		cpu_hand_utils = CPUHandUtils.new()
		var board_system = flow_mgr.board_system_3d if flow_mgr else null
		var player_buff_system = flow_mgr.player_buff_system if flow_mgr else null
		cpu_hand_utils.setup_systems(card_system, board_system, player_system, player_buff_system)
	
	# CPUBattleAIを初期化（共通バトル評価用）
	if not cpu_battle_ai:
		cpu_battle_ai = CPUBattleAI.new()
		var board_system = flow_mgr.board_system_3d if flow_mgr else null
		var player_buff_system = flow_mgr.player_buff_system if flow_mgr else null
		cpu_battle_ai.setup_systems(card_system, board_system, player_system, player_buff_system, flow_mgr)
		cpu_battle_ai.set_hand_utils(cpu_hand_utils)
	
	# CPU防御AIを初期化
	if not cpu_defense_ai:
		cpu_defense_ai = CPUDefenseAI.new()
		var board_system = flow_mgr.board_system_3d if flow_mgr else null
		cpu_defense_ai.setup_systems(card_system, player_system, flow_mgr, board_system)
		cpu_defense_ai.set_hand_utils(cpu_hand_utils)

## アイテムフェーズ開始
## defender_tile_info: 攻撃側フェーズ開始時に防御側情報を渡す（防御側CPUの事前選択用）
func start_item_phase(player_id: int, creature_data: Dictionary = {}, defender_tile_info: Dictionary = {}):
	if current_state != State.INACTIVE:
		return
	
	# defender_tile_info が渡された場合 = 攻撃側のアイテムフェーズ開始
	var is_attacker_phase = not defender_tile_info.is_empty()
	
	# 🎯 攻撃側フェーズ開始時に防御側の事前選択をクリア
	# （攻撃側の事前選択はLandCommandHandlerで設定されるので、ここではクリアしない）
	if is_attacker_phase:
		clear_preselected_defender_item()
		
		var defender_owner = defender_tile_info.get("owner", -1)
		if defender_owner >= 0 and is_cpu_player(defender_owner):
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
	
	# 戦闘行動不可呪いチェック（防御側のみ呪いを持つ可能性がある）
	if SpellCurseBattle.has_battle_disable(creature_data):
		print("【戦闘行動不可】", creature_data.get("name", "?"), " はアイテム・援護使用不可 → 強制パス")
		pass_item()
		return
	
	item_phase_started.emit()
	
	# CPUの場合のアイテム判断
	if is_cpu_player(player_id):
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

## 援護スキルを持っているかチェック
func has_assist_skill() -> bool:
	if battle_creature_data.is_empty():
		return false
	
	var ability_parsed = battle_creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	return "援護" in keywords

## 援護対象の属性を取得
func get_assist_target_elements() -> Array:
	if not has_assist_skill():
		return []
	
	var ability_parsed = battle_creature_data.get("ability_parsed", {})
	var keyword_conditions = ability_parsed.get("keyword_conditions", {})
	var assist_condition = keyword_conditions.get("援護", {})
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
	if not ui_manager or not card_system or not player_system:
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
	
	# アイテムカードと援護対象/合体相手クリーチャーカードを収集
	var selectable_cards = []
	var has_assist = has_assist_skill()
	var assist_elements = get_assist_target_elements()
	var has_merge = has_merge_skill()
	var merge_partner_id = get_merge_partner_id()
	
	# metal_form呪いがある場合、防具使用不可
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
			
			# アイテムクリーチャー判定
			var keywords = card.get("ability_parsed", {}).get("keywords", [])
			if "アイテムクリーチャー" in keywords:
				selectable_cards.append(card)
			# 合体相手判定
			elif has_merge and card_id == merge_partner_id:
				selectable_cards.append(card)
			# 援護スキルがある場合、対象クリーチャーも選択可能
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
	
	# フィルター設定（アイテム + 援護対象クリーチャー）
	if ui_manager:
		var blocked_types = []
		
		# metal_form呪いがある場合、防具をブロック
		if has_metal_form:
			blocked_types.append("防具")
		
		# cannot_use制限をチェック（デバッグフラグで無効化可能）
		var disable_cannot_use = tile_action_processor and tile_action_processor.debug_disable_cannot_use
		if not disable_cannot_use:
			var cannot_use_list = ItemUseRestriction.get_cannot_use_list(battle_creature_data)
			if not cannot_use_list.is_empty():
				print("【アイテム使用制限】", battle_creature_data.get("name", "?"), " は使用不可: ", cannot_use_list)
				for item_type in cannot_use_list:
					if item_type not in blocked_types:
						blocked_types.append(item_type)
		
		ui_manager.blocked_item_types = blocked_types
		
		if has_assist:
			# 援護スキルがある場合は特別なフィルターモード
			ui_manager.card_selection_filter = "item_or_assist"
			# 援護対象属性を保存（UI側で使用）
			ui_manager.assist_target_elements = assist_elements
		else:
			ui_manager.card_selection_filter = "item"
	
	# 手札表示を更新（防御側のアイテムフェーズでは防御側の手札を表示）
	if ui_manager and ui_manager.hand_display:
		ui_manager.hand_display.update_hand_display(current_player_id)
		# フレーム待機して手札が描画されるまで待つ
		await ui_manager.get_tree().process_frame
	
	# CardSelectionUIを使用してアイテム選択
	if ui_manager.card_selection_ui and ui_manager.card_selection_ui.has_method("show_selection"):

		ui_manager.card_selection_ui.show_selection(current_player, "item")
	else:
		print("[ItemPhaseHandler] CardSelectionUIが利用不可")

## アイテムまたは援護/合体クリーチャーを使用
func use_item(item_card: Dictionary):
	if current_state != State.WAITING_FOR_SELECTION:
		return
	
	if item_used_this_battle:
		return
	
	# カードタイプを判定
	var card_type = item_card.get("type", "")
	var card_id = item_card.get("id", -1)
	
	# アイテムの場合、cannot_use制限をチェック（デバッグフラグで無効化可能）
	if card_type == "item":
		var disable_cannot_use = tile_action_processor and tile_action_processor.debug_disable_cannot_use
		if not disable_cannot_use:
			var check_result = ItemUseRestriction.check_can_use(battle_creature_data, item_card)
			if not check_result.can_use:
				print("[ItemPhaseHandler] アイテム使用制限: %s" % check_result.reason)
				return
	
	# クリーチャーの場合の追加チェック
	if card_type == "creature":
		# アイテムクリーチャー判定
		var keywords = item_card.get("ability_parsed", {}).get("keywords", [])
		var is_item_creature = "アイテムクリーチャー" in keywords
		
		if not is_item_creature:
			# 合体相手かチェック
			var merge_partner_id = get_merge_partner_id()
			if has_merge_skill() and card_id == merge_partner_id:
				# 合体処理
				_execute_merge(item_card)
				return
			
			# 援護クリーチャーの場合
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
		cost = cost_data.get("mp", 0)  # アイテムはmp値をそのまま使用（等倍）
	else:
		cost = cost_data
	
	# ライフフォース呪いチェック（アイテムコスト0化）
	if game_flow_manager and game_flow_manager.spell_cost_modifier:
		cost = game_flow_manager.spell_cost_modifier.get_modified_cost(current_player_id, item_card)
	
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
	item_used.emit(item_card)
	
	# フェーズ完了
	complete_item_phase()

## 合体処理を実行
func _execute_merge(partner_card: Dictionary):
	# コストチェック
	if not _can_afford_card(partner_card):
		print("[合体] 魔力不足")
		return
	
	# 合体結果のクリーチャーデータを取得
	var result_id = get_merge_result_id()
	var result_creature = CardLoader.get_card_by_id(result_id)
	
	if result_creature.is_empty():
		print("[合体] 合体結果のクリーチャーが見つかりません: ID=%d" % result_id)
		return
	
	var partner_name = partner_card.get("name", "?")
	var original_name = battle_creature_data.get("name", "?")
	var result_name = result_creature.get("name", "?")
	
	print("[合体] %s + %s → %s" % [original_name, partner_name, result_name])
	
	item_used_this_battle = true
	current_state = State.ITEM_APPLIED
	
	# コストを支払う
	var cost_data = partner_card.get("cost", {})
	var cost = 0
	if typeof(cost_data) == TYPE_DICTIONARY:
		cost = cost_data.get("mp", 0)
	else:
		cost = cost_data
	
	# ライフフォース呪いチェック（コスト0化）
	if game_flow_manager and game_flow_manager.spell_cost_modifier:
		cost = game_flow_manager.spell_cost_modifier.get_modified_cost(current_player_id, partner_card)
	
	if player_system:
		player_system.add_magic(current_player_id, -cost)
		print("[合体] 魔力消費: %dG" % cost)
	
	# 合体相手を捨て札へ
	if card_system:
		var hand = card_system.get_all_cards_for_player(current_player_id)
		for i in range(hand.size()):
			if hand[i].get("id", -1) == partner_card.get("id", -2):
				card_system.discard_card(current_player_id, i, "merge")
				print("[合体] %s を捨て札へ" % partner_name)
				break
	
	# 合体後のクリーチャーデータを準備
	var new_creature_data = result_creature.duplicate(true)
	
	# 永続化フィールドの初期化
	if not new_creature_data.has("base_up_hp"):
		new_creature_data["base_up_hp"] = 0
	if not new_creature_data.has("base_up_ap"):
		new_creature_data["base_up_ap"] = 0
	if not new_creature_data.has("permanent_effects"):
		new_creature_data["permanent_effects"] = []
	if not new_creature_data.has("temporary_effects"):
		new_creature_data["temporary_effects"] = []
	if not new_creature_data.has("map_lap_count"):
		new_creature_data["map_lap_count"] = 0
	
	# current_hpの初期化
	var max_hp = new_creature_data.get("hp", 0) + new_creature_data.get("base_up_hp", 0)
	new_creature_data["current_hp"] = max_hp
	
	# 合体情報を追加（バトル画面表示用）
	new_creature_data["_was_merged"] = true
	new_creature_data["_merged_result_name"] = result_name
	
	# 合体後データを保存
	merged_creature_data = new_creature_data
	
	print("[合体] 完了: %s (HP:%d AP:%d)" % [result_name, max_hp, new_creature_data.get("ap", 0)])
	
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
	
	# フィルターをクリア
	if ui_manager:
		ui_manager.card_selection_filter = ""
		ui_manager.assist_target_elements = []  # 援護対象属性もクリア
		ui_manager.blocked_item_types = []  # ブロックされたアイテムタイプもクリア
		# 手札表示を更新してグレーアウトを解除
		if ui_manager.hand_display and player_system:
			var current_player = player_system.get_current_player()
			if current_player:
				ui_manager.hand_display.update_hand_display(current_player.id)
	
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
		cost = cost_data.get("mp", 0)  # アイテムはmp値をそのまま使用（等倍）
	else:
		cost = cost_data
	
	# ライフフォース呪いチェック（アイテムコスト0化）
	if game_flow_manager and game_flow_manager.spell_cost_modifier:
		cost = game_flow_manager.spell_cost_modifier.get_modified_cost(current_player_id, card_data)
	
	return current_player.magic_power >= cost

## 選択されたアイテムを取得
func get_selected_item() -> Dictionary:
	return selected_item_card

## アイテムが使用されたか
func was_item_used() -> bool:
	return item_used_this_battle

## CPUプレイヤーかどうか
func is_cpu_player(player_id: int) -> bool:
	if not game_flow_manager:
		return false
	
	var cpu_settings = game_flow_manager.player_is_cpu
	var debug_mode = game_flow_manager.debug_manual_control_all
	
	if debug_mode:
		return false  # デバッグモードでは全員手動
	
	return player_id < cpu_settings.size() and cpu_settings[player_id]

## アクティブか
func is_item_phase_active() -> bool:
	return current_state != State.INACTIVE

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
	
	# 戦闘行動不可呪いチェック
	if SpellCurseBattle.has_battle_disable(defender_creature):
		print("[CPU防御事前選択] 戦闘行動不可 → 終了")
		_defender_preselection_done = true
		return
	
	# CPUDefenseAI初期化
	if not cpu_defense_ai:
		cpu_defense_ai = CPUDefenseAI.new()
		var board_system = game_flow_manager.board_system_3d if game_flow_manager else null
		cpu_defense_ai.setup_systems(card_system, player_system, game_flow_manager, board_system)
		if cpu_hand_utils:
			cpu_defense_ai.set_hand_utils(cpu_hand_utils)
	
	# CPUHandUtils初期化
	if not cpu_hand_utils:
		cpu_hand_utils = CPUHandUtils.new()
		var board_system = game_flow_manager.board_system_3d if game_flow_manager else null
		var player_buff_system = game_flow_manager.player_buff_system if game_flow_manager else null
		cpu_hand_utils.setup_systems(card_system, board_system, player_system, player_buff_system)
		cpu_defense_ai.set_hand_utils(cpu_hand_utils)
	
	# 攻撃側プレイヤーID取得
	var attacker_player_id = -1
	if game_flow_manager and game_flow_manager.board_system_3d:
		attacker_player_id = game_flow_manager.board_system_3d.current_player_index
	
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
			print("[CPU防御事前選択] 援護決定: %s" % decision.creature.get("name", "?"))
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
	if game_flow_manager and game_flow_manager.board_system_3d:
		attacker_player_id = game_flow_manager.board_system_3d.current_player_index
	
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
			print("[CPU防御] 援護使用: %s" % decision.creature.get("name", "?"))
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
	if game_flow_manager and game_flow_manager.board_system_3d:
		var board = game_flow_manager.board_system_3d
		if board.movement_controller:
			var tile_index = board.movement_controller.get_player_tile(current_player_id)
			if tile_index >= 0:
				return board.get_tile_info(tile_index)
	
	return {}


## CPUが合体を実行
func _execute_merge_for_cpu(merge_result: Dictionary):
	var partner_index = merge_result["partner_index"]
	var partner_data = merge_result["partner_data"]
	var result_id = merge_result["result_id"]
	var cost = merge_result["cost"]
	
	# 合体結果のクリーチャーを取得
	var result_creature = CardLoader.get_card_by_id(result_id)
	if result_creature.is_empty():
		print("[CPU合体] 合体結果のクリーチャーが見つかりません")
		pass_item()
		return
	
	# 魔力消費
	if player_system:
		player_system.add_magic(current_player_id, -cost)
		print("[CPU合体] 魔力消費: %dG" % cost)
	
	# 合体相手を捨て札へ
	if card_system:
		card_system.discard_card(current_player_id, partner_index, "merge")
		print("[CPU合体] %s を捨て札へ" % partner_data.get("name", "?"))
	
	# 合体後のクリーチャーデータを準備
	var new_creature_data = result_creature.duplicate(true)
	
	# 永続化フィールドの初期化
	if not new_creature_data.has("base_up_hp"):
		new_creature_data["base_up_hp"] = 0
	if not new_creature_data.has("base_up_ap"):
		new_creature_data["base_up_ap"] = 0
	if not new_creature_data.has("permanent_effects"):
		new_creature_data["permanent_effects"] = []
	if not new_creature_data.has("temporary_effects"):
		new_creature_data["temporary_effects"] = []
	
	# current_hpの初期化
	var max_hp = new_creature_data.get("hp", 0) + new_creature_data.get("base_up_hp", 0)
	new_creature_data["current_hp"] = max_hp
	
	# タイルインデックスを保持
	var tile_index = battle_creature_data.get("tile_index", -1)
	new_creature_data["tile_index"] = tile_index
	
	# 合体後のデータを保存
	merged_creature_data = new_creature_data
	battle_creature_data = new_creature_data
	
	print("[CPU合体] 完了: %s (HP:%d AP:%d)" % [
		new_creature_data.get("name", "?"),
		max_hp,
		new_creature_data.get("ap", 0)
	])
	
	# 合体シグナルを発行
	creature_merged.emit(merged_creature_data)
	
	# アイテムフェーズ完了
	current_state = State.ITEM_APPLIED
	item_phase_completed.emit()
