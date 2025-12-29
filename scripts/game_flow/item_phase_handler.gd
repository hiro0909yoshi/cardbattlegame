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
var _special_effects: BattleSpecialEffects = null
var _battle_simulator = null

# 防御時のタイル情報（シミュレーション用）
var defense_tile_info: Dictionary = {}

## 参照
var ui_manager = null
var game_flow_manager = null
var card_system = null
var player_system = null
var battle_system = null

func _ready():
	pass

## 初期化
func initialize(ui_mgr, flow_mgr, c_system = null, p_system = null, b_system = null):
	ui_manager = ui_mgr
	game_flow_manager = flow_mgr
	card_system = c_system if c_system else (flow_mgr.card_system if flow_mgr else null)
	player_system = p_system if p_system else (flow_mgr.player_system if flow_mgr else null)
	battle_system = b_system if b_system else (flow_mgr.battle_system if flow_mgr else null)

## アイテムフェーズ開始
func start_item_phase(player_id: int, creature_data: Dictionary = {}):
	if current_state != State.INACTIVE:
		return
	
	current_state = State.WAITING_FOR_SELECTION
	current_player_id = player_id
	item_used_this_battle = false
	selected_item_card = {}
	battle_creature_data = creature_data
	merged_creature_data = {}  # 合体データをリセット
	
	# 戦闘行動不可呪いチェック（防御側のみ呪いを持つ可能性がある）
	if SpellCurseBattle.has_battle_disable(creature_data):
		print("【戦闘行動不可】", creature_data.get("name", "?"), " はアイテム・援護使用不可 → 強制パス")
		pass_item()
		return
	
	item_phase_started.emit()
	
	# CPUの場合のアイテム判断
	if is_cpu_player(player_id):
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
		# metal_form呪いがある場合、防具をブロック
		if has_metal_form:
			ui_manager.blocked_item_types = ["防具"]
		else:
			ui_manager.blocked_item_types = []
		
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

## アイテムまたは援護/合体クリーチャーを使用
func use_item(item_card: Dictionary):
	if current_state != State.WAITING_FOR_SELECTION:
		return
	
	if item_used_this_battle:
		return
	
	# カードタイプを判定
	var card_type = item_card.get("type", "")
	var card_id = item_card.get("id", -1)
	
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

## CPU防御時のアイテム判断
## 無効化スキルで勝てる場合はアイテムを温存
## 負ける場合、防具・アクセサリで勝てるならアイテム使用
func _cpu_decide_item():
	print("[CPU防御] アイテム判断開始: %s vs %s" % [
		battle_creature_data.get("name", "?"),
		opponent_creature_data.get("name", "?")
	])
	
	# 無効化判定を行う（防御側として）
	if _should_skip_item_due_to_nullify():
		print("[CPU防御] 無効化スキルで勝てる → アイテム温存")
		pass_item()
		return
	
	# タイル情報を取得
	var tile_info = _get_defense_tile_info()
	if tile_info.is_empty():
		print("[CPU防御] タイル情報取得失敗 → パス")
		pass_item()
		return
	
	# BattleSimulatorを初期化
	_ensure_battle_simulator()
	if not _battle_simulator:
		print("[CPU防御] シミュレーター初期化失敗 → パス")
		pass_item()
		return
	
	# 1. アイテムなしでシミュレーション
	var no_item_result = _simulate_defense_battle({})
	var no_item_outcome = no_item_result.get("result", -1)
	
	print("[CPU防御] アイテムなし結果: %s" % _result_to_string(no_item_outcome))
	
	# 勝てる/生き残れる場合はアイテム温存
	if no_item_outcome == BattleSimulatorScript.BattleResult.DEFENDER_WIN:
		print("[CPU防御] アイテムなしで勝利 → アイテム温存")
		pass_item()
		return
	
	if no_item_outcome == BattleSimulatorScript.BattleResult.ATTACKER_SURVIVED:
		print("[CPU防御] アイテムなしで両者生存 → アイテム温存")
		pass_item()
		return
	
	# 2. 負ける場合、防具・アクセサリでシミュレーション
	var best_item = _find_best_defense_item(no_item_outcome)
	
	if not best_item.is_empty():
		print("[CPU防御] 最適アイテム選択: %s" % best_item.get("name", "?"))
		use_item(best_item)
	else:
		print("[CPU防御] 有効なアイテムなし → パス")
		pass_item()

## 防御用の最適アイテムを探す
## 武器は使用しない、防具・アクセサリのみ
func _find_best_defense_item(current_outcome: int) -> Dictionary:
	if not card_system:
		return {}
	
	var hand = card_system.get_all_cards_for_player(current_player_id)
	var current_player = player_system.players[current_player_id] if player_system else null
	if not current_player:
		return {}
	
	# 防御用アイテムを収集（防具・アクセサリのみ、武器・巻物は除外）
	var defense_items: Array = []
	for i in range(hand.size()):
		var card = hand[i]
		if card.get("type", "") != "item":
			continue
		
		var item_type = card.get("item_type", "")
		# 武器と巻物は防御時使用しない
		if item_type == "武器" or item_type == "巻物":
			continue
		
		# コストチェック
		var cost = _get_item_cost(card)
		if cost > current_player.magic_power:
			continue
		
		defense_items.append({"index": i, "data": card, "cost": cost})
	
	if defense_items.is_empty():
		return {}
	
	# 各アイテムでシミュレーション
	var winning_items: Array = []
	var surviving_items: Array = []
	
	for item_entry in defense_items:
		var item = item_entry["data"]
		var result = _simulate_defense_battle(item)
		var outcome = result.get("result", -1)
		
		print("  [防御シミュ] %s[%s]: %s" % [
			item.get("name", "?"),
			item.get("item_type", "?"),
			_result_to_string(outcome)
		])
		
		if outcome == BattleSimulatorScript.BattleResult.DEFENDER_WIN:
			winning_items.append(item_entry)
		elif outcome == BattleSimulatorScript.BattleResult.ATTACKER_SURVIVED:
			# 両者生存も改善として扱う（死ぬよりマシ）
			if current_outcome == BattleSimulatorScript.BattleResult.ATTACKER_WIN or \
			   current_outcome == BattleSimulatorScript.BattleResult.BOTH_DEFEATED:
				surviving_items.append(item_entry)
	
	# 優先順位: 勝てるアイテム > 生き残れるアイテム
	# 同じカテゴリ内では防具 > アクセサリ、コストが低い方優先
	if not winning_items.is_empty():
		return _select_best_defense_item(winning_items)
	
	if not surviving_items.is_empty():
		return _select_best_defense_item(surviving_items)
	
	return {}

## 防御用アイテムの優先順位で選択
## 防具 > アクセサリ、コストが低い方優先
func _select_best_defense_item(items: Array) -> Dictionary:
	if items.is_empty():
		return {}
	
	# ソート: 防具優先、次にコスト
	items.sort_custom(func(a, b):
		var type_a = a["data"].get("item_type", "")
		var type_b = b["data"].get("item_type", "")
		var priority_a = _get_defense_item_priority(type_a)
		var priority_b = _get_defense_item_priority(type_b)
		
		if priority_a != priority_b:
			return priority_a < priority_b  # 小さい方が優先
		
		return a["cost"] < b["cost"]  # コストが低い方優先
	)
	
	return items[0]["data"]

## 防御アイテムの優先度（小さいほど優先）
func _get_defense_item_priority(item_type: String) -> int:
	match item_type:
		"防具": return 0
		"アクセサリ": return 1
		_: return 99  # 武器・巻物は使わない

## 防御側としてバトルシミュレーション
func _simulate_defense_battle(defender_item: Dictionary) -> Dictionary:
	var tile_info = _get_defense_tile_info()
	
	# 攻撃側 = opponent_creature_data
	# 防御側 = battle_creature_data（自分）
	var sim_tile_info = {
		"element": tile_info.get("element", ""),
		"level": tile_info.get("level", 1),
		"owner": current_player_id,
		"tile_index": tile_info.get("index", -1)
	}
	
	# 攻撃側プレイヤーIDを取得（相手）
	var attacker_player_id = -1
	if game_flow_manager and game_flow_manager.board_system_3d:
		attacker_player_id = game_flow_manager.board_system_3d.current_player_index
	
	return _battle_simulator.simulate_battle(
		opponent_creature_data,  # 攻撃側
		battle_creature_data,    # 防御側（自分）
		sim_tile_info,
		attacker_player_id,
		{},                      # 攻撃側アイテム（不明なので空）
		defender_item            # 防御側アイテム
	)

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

## BattleSimulatorを初期化
func _ensure_battle_simulator():
	if _battle_simulator:
		return
	
	_battle_simulator = BattleSimulatorScript.new()
	
	if game_flow_manager and game_flow_manager.board_system_3d:
		var board = game_flow_manager.board_system_3d
		_battle_simulator.setup_systems(board, card_system, player_system, game_flow_manager)
		_battle_simulator.enable_log = false  # ログは抑制

## アイテムコスト取得
func _get_item_cost(item: Dictionary) -> int:
	var cost_data = item.get("cost", 0)
	if typeof(cost_data) == TYPE_DICTIONARY:
		return cost_data.get("mp", 0)
	return cost_data

## 結果を文字列に変換
func _result_to_string(result: int) -> String:
	match result:
		BattleSimulatorScript.BattleResult.ATTACKER_WIN:
			return "攻撃側勝利"
		BattleSimulatorScript.BattleResult.DEFENDER_WIN:
			return "防御側勝利"
		BattleSimulatorScript.BattleResult.ATTACKER_SURVIVED:
			return "両者生存"
		BattleSimulatorScript.BattleResult.BOTH_DEFEATED:
			return "相打ち"
		_:
			return "不明"

## 無効化スキルでアイテムをスキップすべきか判定
## 防御側（battle_creature_data）が無効化を持っていて、
## 攻撃側（opponent_creature_data）が無効化の範囲内の場合はtrue
func _should_skip_item_due_to_nullify() -> bool:
	# 相手クリーチャーデータがない場合はスキップしない
	if opponent_creature_data.is_empty():
		return false
	
	# 自分のクリーチャーが無効化スキルを持っているかチェック
	var ability_parsed = battle_creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	if not "無効化" in keywords:
		return false
	
	# 無効化判定を実行
	if not _special_effects:
		_special_effects = BattleSpecialEffectsScript.new()
	
	# BattleParticipantを作成（簡易版）
	var attacker_hp = opponent_creature_data.get("hp", 0)
	var attacker_ap = opponent_creature_data.get("ap", 0)
	var attacker = BattleParticipantScript.new(opponent_creature_data, attacker_hp, 0, attacker_ap, true, -1)
	
	var defender_hp = battle_creature_data.get("hp", 0)
	var defender_ap = battle_creature_data.get("ap", 0)
	var defender = BattleParticipantScript.new(battle_creature_data, defender_hp, 0, defender_ap, false, current_player_id)
	
	# 無効化判定用のコンテキスト
	var context = {
		"tile_level": 1,  # タイルレベルは後で取得
		"tile_element": "",
		"battle_tile_index": -1
	}
	
	# タイル情報を取得（可能であれば）
	if game_flow_manager and game_flow_manager.board_system_3d:
		var board = game_flow_manager.board_system_3d
		if board.movement_controller:
			var tile_index = board.movement_controller.get_player_tile(current_player_id)
			if tile_index >= 0:
				var tile_info = board.get_tile_info(tile_index)
				context["tile_level"] = tile_info.get("level", 1)
				context["tile_element"] = tile_info.get("element", "")
				context["battle_tile_index"] = tile_index
	
	var result = _special_effects.check_nullify(attacker, defender, context)
	
	if result.get("is_nullified", false):
		print("[CPU無効化判定] %s の無効化が %s に対して有効" % [
			battle_creature_data.get("name", "?"),
			opponent_creature_data.get("name", "?")
		])
		return true
	
	return false
