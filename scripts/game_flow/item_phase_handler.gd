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

# 現在のフェーズが攻撃側かどうか
var _is_current_phase_attacker: bool = false

# 手札ユーティリティ（ワーストケースシミュレーション用）
var cpu_hand_utils: CPUHandUtils = null

# CPUBattleAI（共通バトル評価用）
var cpu_battle_ai: CPUBattleAI = null

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

## アイテムフェーズ開始
## defender_tile_info: 攻撃側フェーズ開始時に防御側情報を渡す（防御側CPUの事前選択用）
func start_item_phase(player_id: int, creature_data: Dictionary = {}, defender_tile_info: Dictionary = {}):
	if current_state != State.INACTIVE:
		return
	
	# defender_tile_info が渡された場合 = 攻撃側のアイテムフェーズ開始
	var is_attacker_phase = not defender_tile_info.is_empty()
	
	# 🎯 攻撃側フェーズ開始時に防御側CPUの事前選択を行う
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
	
	# 一時的にデータを設定
	var saved_player_id = current_player_id
	var saved_battle_creature = battle_creature_data
	var saved_opponent_creature = opponent_creature_data
	var saved_defense_tile = defense_tile_info
	
	current_player_id = defender_player_id
	battle_creature_data = defender_creature
	opponent_creature_data = attacker_creature
	defense_tile_info = tile_info
	
	# シミュレーター初期化
	_ensure_battle_simulator()
	
	# CPUBattleAI初期化（共通バトル評価用）
	if not cpu_battle_ai:
		cpu_battle_ai = CPUBattleAI.new()
		var board_system = game_flow_manager.board_system_3d if game_flow_manager else null
		var player_buff_system = game_flow_manager.player_buff_system if game_flow_manager else null
		cpu_battle_ai.setup_systems(card_system, board_system, player_system, player_buff_system, game_flow_manager)
		if cpu_hand_utils:
			cpu_battle_ai.set_hand_utils(cpu_hand_utils)
	
	# CPUHandUtils初期化
	if not cpu_hand_utils:
		cpu_hand_utils = CPUHandUtils.new()
		var board_system = game_flow_manager.board_system_3d if game_flow_manager else null
		var player_buff_system = game_flow_manager.player_buff_system if game_flow_manager else null
		cpu_hand_utils.setup_systems(card_system, board_system, player_system, player_buff_system)
		if cpu_battle_ai:
			cpu_battle_ai.set_hand_utils(cpu_hand_utils)
	
	# 事前選択ロジック（_cpu_decide_itemの簡易版）
	var preselected = _preselect_defender_item_internal()
	
	# データを復元
	current_player_id = saved_player_id
	battle_creature_data = saved_battle_creature
	opponent_creature_data = saved_opponent_creature
	defense_tile_info = saved_defense_tile
	
	_defender_preselection_done = true  # 事前選択が実行された
	
	if not preselected.is_empty():
		_preselected_defender_item = preselected
		print("[CPU防御事前選択] 決定: %s" % preselected.get("name", "?"))
	else:
		print("[CPU防御事前選択] アイテムなし（事前選択完了）")

## 事前選択の内部ロジック
func _preselect_defender_item_internal() -> Dictionary:
	print("[CPU防御事前選択内部] 開始")
	
	if not _battle_simulator:
		print("[CPU防御事前選択内部] シミュレーターなし → 終了")
		return {}
	
	# 戦闘行動不可呪いチェック
	if SpellCurseBattle.has_battle_disable(battle_creature_data):
		print("[CPU防御事前選択内部] 戦闘行動不可 → 終了")
		return {}
	
	# 無効化判定
	if _should_skip_item_due_to_nullify():
		print("[CPU防御事前選択内部] 無効化で勝てる → 終了")
		return {}
	
	# 合体チェック（合体は事前選択しない、フェーズで処理）
	var merge_result = _check_merge_option()
	if merge_result["can_merge"] and merge_result["wins"]:
		print("[CPU防御事前選択内部] 合体で勝利 → 合体選択")
		return {"_is_merge": true, "merge_data": merge_result}
	
	# 敵のアイテム破壊・盗みスキルチェック
	var enemy_destroy_types = _attacker_has_item_destroy()
	var enemy_has_steal = _attacker_has_item_steal()
	var should_avoid_items = not enemy_destroy_types.is_empty() or enemy_has_steal
	print("[CPU防御事前選択内部] アイテム回避: %s (破壊:%s, 盗み:%s)" % [should_avoid_items, enemy_destroy_types, enemy_has_steal])
	
	# タイル情報（即死判断にも使用）
	var tile_info = _get_defense_tile_info()
	var tile_level = tile_info.get("level", 1)
	print("[CPU防御事前選択内部] タイル: %s Lv%d" % [tile_info.get("element", "?"), tile_level])
	
	# 敵が即死スキルを持っていて、自分に適用される場合の特別処理
	var instant_death_check = _check_instant_death_threat()
	if not should_avoid_items and instant_death_check.is_applicable:
		var probability = instant_death_check.probability
		print("[CPU防御事前選択内部] 敵が即死スキル持ち（%d%%）＆自分に適用される" % probability)
		
		# 100%即死、または確率即死でレベル2以上の土地なら無効化アイテムを優先
		if probability >= 100 or tile_level >= 2:
			print("[CPU防御事前選択内部] → 無効化アイテムを優先検索（100%%即死 or Lv%d土地）" % tile_level)
			var nullify_item = _find_nullify_item_for_defense()
			if not nullify_item.is_empty():
				print("[CPU防御事前選択内部] 通常攻撃100%%無効化アイテムを使用: %s" % nullify_item.get("name", "?"))
				return nullify_item
			# 無効化アイテムがない場合
			if probability >= 100:
				# 100%即死はアイテムを使っても即死されるので使わない
				print("[CPU防御事前選択内部] 無効化アイテムなし → 100%%即死を受けるためアイテム使用しない")
				return {}
			else:
				# 確率即死は通常判断へ（アイテムで生き残れる可能性がある）
				print("[CPU防御事前選択内部] 無効化アイテムなし → 確率即死（%d%%）のため通常判断へ" % probability)
		else:
			# Lv1土地で確率即死 → 通常判断へ
			print("[CPU防御事前選択内部] Lv1土地で確率即死（%d%%）→ 通常判断へ" % probability)
	
	# ワーストケースシミュレーション
	print("[CPU防御事前選択内部] ワーストケースシミュレーション開始（アイテムなし）")
	var worst_case_result = _simulate_defense_worst_case({})
	var worst_case_outcome = worst_case_result.get("result", -1)
	print("[CPU防御事前選択内部] ワーストケース結果: %s" % _result_to_string(worst_case_outcome))
	
	# ワーストケースでも勝てる場合はアイテム不要
	if worst_case_outcome == BattleSimulatorScript.BattleResult.DEFENDER_WIN:
		print("[CPU防御事前選択内部] ワーストケースで勝利 → アイテム不要")
		return {}
	if worst_case_outcome == BattleSimulatorScript.BattleResult.ATTACKER_SURVIVED:
		print("[CPU防御事前選択内部] ワーストケースで両者生存 → アイテム不要")
		return {}
	
	# 手札の防具枚数
	var armor_count = _count_armor_in_hand()
	print("[CPU防御事前選択内部] 手札の防具枚数: %d" % armor_count)
	
	# 勝てるアイテム・援護を探す
	print("[CPU防御事前選択内部] 勝てるアイテム検索開始")
	var item_results = {"normal": [], "reserve": []}
	if not should_avoid_items:
		item_results = _find_winning_items_separated(worst_case_outcome)
	
	var winning_items = item_results["normal"]
	var reserve_items = item_results["reserve"]
	
	var assist_results = _find_winning_assist_separated(worst_case_outcome)
	var winning_assist = assist_results["normal"]
	var reserve_assist = assist_results["reserve"]
	
	# 選択ロジック（防具2枚以下なら援護優先）
	if should_avoid_items or armor_count <= 2:
		if not winning_assist.is_empty():
			return _select_best_assist(winning_assist)
		if not should_avoid_items and not winning_items.is_empty():
			return _select_best_defense_item(winning_items)
	else:
		if not winning_items.is_empty():
			return _select_best_defense_item(winning_items)
		if not winning_assist.is_empty():
			return _select_best_assist(winning_assist)
	
	# 温存対象（レベル2以上）
	if tile_level >= 2:
		if should_avoid_items or armor_count <= 2:
			if not reserve_assist.is_empty():
				return _select_best_assist(reserve_assist)
			if not should_avoid_items and not reserve_items.is_empty():
				return _select_best_defense_item(reserve_items)
		else:
			if not reserve_items.is_empty():
				return _select_best_defense_item(reserve_items)
			if not reserve_assist.is_empty():
				return _select_best_assist(reserve_assist)
	
	return {}

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
	
	# 事前選択が実行されていない場合は従来のロジック（人間攻撃側の場合など）
	print("[CPU防御] 事前選択未実行 → 従来ロジックで判断")
	
	# 無効化判定を行う（防御側として）
	if _should_skip_item_due_to_nullify():
		print("[CPU防御] 無効化スキルで勝てる → アイテム温存")
		pass_item()
		return
	
	# 合体判断（最優先）
	var merge_result = _check_merge_option()
	if merge_result["can_merge"] and merge_result["wins"]:
		print("[CPU防御] 合体で勝利可能 → 合体を選択: %s" % merge_result.get("result_name", "?"))
		_execute_merge_for_cpu(merge_result)
		return
	
	# 敵（攻撃側）がアイテム破壊・盗みスキルを持っているかチェック
	var enemy_destroy_types = _attacker_has_item_destroy()
	var enemy_has_steal = _attacker_has_item_steal()
	var should_avoid_items = not enemy_destroy_types.is_empty() or enemy_has_steal
	
	if should_avoid_items:
		if not enemy_destroy_types.is_empty():
			print("[CPU防御] 警告: 敵がアイテム破壊スキルを所持 (対象: %s)" % str(enemy_destroy_types))
		if enemy_has_steal:
			print("[CPU防御] 警告: 敵がアイテム盗みスキルを所持")
		print("[CPU防御] → アイテム使用を控え、援護のみ検討します")
	
	# タイル情報を取得（即死判断にも使用）
	var tile_info = _get_defense_tile_info()
	if tile_info.is_empty():
		print("[CPU防御] タイル情報取得失敗 → パス")
		pass_item()
		return
	
	var tile_level = tile_info.get("level", 1)
	print("[CPU防御] タイル情報: %s Lv%d" % [
		tile_info.get("element", "?"),
		tile_level
	])
	
	# 敵が即死スキルを持っていて、自分に適用される場合の特別処理
	# ただし、敵がアイテム破壊・盗みを持っている場合はスキップ
	var instant_death_check = _check_instant_death_threat()
	if not should_avoid_items and instant_death_check.is_applicable:
		var probability = instant_death_check.probability
		print("[CPU防御] 敵が即死スキル持ち（%d%%）＆自分に適用される" % probability)
		
		# 100%即死、または確率即死でレベル2以上の土地なら無効化アイテムを優先
		if probability >= 100 or tile_level >= 2:
			print("[CPU防御] → 無効化アイテムを優先検索（100%%即死 or Lv%d土地）" % tile_level)
			var nullify_item = _find_nullify_item_for_defense()
			if not nullify_item.is_empty():
				print("[CPU防御] 通常攻撃100%%無効化アイテムを使用: %s" % nullify_item.get("name", "?"))
				use_item(nullify_item)
				return
			# 無効化アイテムがない場合
			if probability >= 100:
				# 100%即死はアイテムを使っても即死されるので使わない
				print("[CPU防御] 無効化アイテムなし → 100%%即死を受けるためアイテム使用しない")
				pass_item()
				return
			else:
				# 確率即死は通常判断へ（アイテムで生き残れる可能性がある）
				print("[CPU防御] 無効化アイテムなし → 確率即死（%d%%）のため通常判断へ" % probability)
		else:
			# Lv1土地で確率即死 → 通常判断へ
			print("[CPU防御] Lv1土地で確率即死（%d%%）→ 通常判断へ" % probability)
	
	# BattleSimulatorを初期化
	_ensure_battle_simulator()
	if not _battle_simulator:
		print("[CPU防御] シミュレーター初期化失敗 → パス")
		pass_item()
		return
	
	# 1. ワーストケースシミュレーション（敵がアイテムを使った場合も考慮）
	var worst_case_result = _simulate_defense_worst_case({})
	var worst_case_outcome = worst_case_result.get("result", -1)
	
	print("[CPU防御] ワーストケース結果: %s" % _result_to_string(worst_case_outcome))
	
	# ワーストケースでも勝てる/生き残れる場合はアイテム温存
	if worst_case_outcome == BattleSimulatorScript.BattleResult.DEFENDER_WIN:
		print("[CPU防御] ワーストケースでも勝利 → アイテム温存")
		pass_item()
		return
	
	if worst_case_outcome == BattleSimulatorScript.BattleResult.ATTACKER_SURVIVED:
		print("[CPU防御] ワーストケースでも両者生存 → アイテム温存")
		pass_item()
		return
	
	# 2. 手札の防具枚数をカウント
	var armor_count = _count_armor_in_hand()
	print("[CPU防御] 手札の防具枚数: %d" % armor_count)
	
	# 3. 勝てるアイテム・援護を探す（通常と温存対象を分離）
	# 敵がアイテム破壊・盗みを持っている場合はアイテムをスキップ
	var item_results = {"normal": [], "reserve": []}
	if not should_avoid_items:
		item_results = _find_winning_items_separated(worst_case_outcome)
	
	var winning_items = item_results["normal"]
	var reserve_items = item_results["reserve"]
	
	var assist_results = _find_winning_assist_separated(worst_case_outcome)
	var winning_assist = assist_results["normal"]
	var reserve_assist = assist_results["reserve"]
	
	if should_avoid_items:
		print("[CPU防御] 勝てる援護: 通常%d, 温存%d（アイテムは敵スキルにより使用不可）" % [
			winning_assist.size(), reserve_assist.size()
		])
	else:
		print("[CPU防御] 勝てるアイテム: 通常%d, 温存%d / 援護: 通常%d, 温存%d" % [
			winning_items.size(), reserve_items.size(),
			winning_assist.size(), reserve_assist.size()
		])
	
	# 4. 通常アイテム・援護で勝てるか（防具2枚以下なら援護優先）
	# 敵がアイテム破壊・盗みを持っている場合は援護のみ使用
	if should_avoid_items or armor_count <= 2:
		# 援護優先（敵がアイテム破壊・盗みを持っている場合は援護のみ）
		if not winning_assist.is_empty():
			var best_assist = _select_best_assist(winning_assist)
			print("[CPU防御] 援護優先選択（防具温存）: %s" % best_assist.get("name", "?"))
			use_item(best_assist)
			return
		if not should_avoid_items and not winning_items.is_empty():
			var best_item = _select_best_defense_item(winning_items)
			print("[CPU防御] アイテム選択: %s" % best_item.get("name", "?"))
			use_item(best_item)
			return
	else:
		# アイテム優先
		if not winning_items.is_empty():
			var best_item = _select_best_defense_item(winning_items)
			print("[CPU防御] アイテム選択: %s" % best_item.get("name", "?"))
			use_item(best_item)
			return
		if not winning_assist.is_empty():
			var best_assist = _select_best_assist(winning_assist)
			print("[CPU防御] 援護選択: %s" % best_assist.get("name", "?"))
			use_item(best_assist)
			return
	
	# 5. 通常で勝てない場合、温存対象をチェック（レベル2以上のみ）
	if tile_level >= 2:
		# 温存対象でも使用する
		if should_avoid_items or armor_count <= 2:
			if not reserve_assist.is_empty():
				var best_assist = _select_best_assist(reserve_assist)
				print("[CPU防御] 温存援護使用（Lv%d土地防衛）: %s" % [tile_level, best_assist.get("name", "?")])
				use_item(best_assist)
				return
			if not should_avoid_items and not reserve_items.is_empty():
				var best_item = _select_best_defense_item(reserve_items)
				print("[CPU防御] 温存アイテム使用（Lv%d土地防衛）: %s" % [tile_level, best_item.get("name", "?")])
				use_item(best_item)
				return
		else:
			if not reserve_items.is_empty():
				var best_item = _select_best_defense_item(reserve_items)
				print("[CPU防御] 温存アイテム使用（Lv%d土地防衛）: %s" % [tile_level, best_item.get("name", "?")])
				use_item(best_item)
				return
			if not reserve_assist.is_empty():
				var best_assist = _select_best_assist(reserve_assist)
				print("[CPU防御] 温存援護使用（Lv%d土地防衛）: %s" % [tile_level, best_assist.get("name", "?")])
				use_item(best_assist)
				return
	else:
		if not reserve_items.is_empty() or not reserve_assist.is_empty():
			print("[CPU防御] 温存対象あるがLv1土地なので使用せず → パス")
	
	print("[CPU防御] 有効なアイテム・援護なし → パス")
	pass_item()

## 手札の防具枚数をカウント
func _count_armor_in_hand() -> int:
	if not card_system:
		return 0
	
	var hand = card_system.get_all_cards_for_player(current_player_id)
	var count = 0
	for card in hand:
		if card.get("type", "") == "item" and card.get("item_type", "") == "防具":
			count += 1
	return count

## 攻撃側クリーチャーがアイテム破壊スキルを持っているかチェック
## @return: アイテム破壊可能なタイプの配列（空なら持っていない）
func _attacker_has_item_destroy() -> Array:
	var ability_parsed = opponent_creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "destroy_item":
			var triggers = effect.get("triggers", [])
			if "before_battle" in triggers:
				var target_types = effect.get("target_types", [])
				if not target_types.is_empty():
					return target_types
	
	return []

## 攻撃側クリーチャーがアイテム盗みスキルを持っているかチェック
## @return: アイテム盗みを持っているか
func _attacker_has_item_steal() -> bool:
	var ability_parsed = opponent_creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "steal_item":
			var triggers = effect.get("triggers", [])
			if "before_battle" in triggers:
				return true
	
	return false

## 温存対象アイテムか判定（道連れ、死亡時ダメージ等）
## 高レベル土地防衛用に取っておきたいアイテム
func _is_reserve_item(item: Dictionary) -> bool:
	var effect_parsed = item.get("effect_parsed", {})
	var effects = effect_parsed.get("effects", [])
	
	for effect in effects:
		var trigger = effect.get("trigger", "")
		if trigger == "on_death":
			var effect_type = effect.get("effect_type", "")
			# 道連れ（バーニングハート等）
			if effect_type == "instant_death":
				return true
			# 死亡時ダメージ
			if effect_type == "damage_enemy":
				return true
	
	return false

## 温存対象クリーチャーか判定（死亡時効果を持つクリーチャー）
## 援護として使用する場合に温存したいクリーチャー
## 注意: HP閾値トリガー（リビングボム等）は対象外（on_deathのみ対象）
func _is_reserve_creature(creature: Dictionary) -> bool:
	var ability_parsed = creature.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		var trigger = effect.get("trigger", "")
		# on_death トリガーのみ対象（on_hp_threshold等は除外）
		if trigger == "on_death":
			var effect_type = effect.get("effect_type", "")
			# 死亡時ダメージ（サルファバルーン等）
			if effect_type == "damage_enemy":
				return true
			# 道連れ（バーニングハート等をクリーチャーとして持つ場合）
			if effect_type == "instant_death":
				return true
	
	return false

## 勝てるアイテムを探す（通常と温存対象を分離）
func _find_winning_items_separated(current_outcome: int) -> Dictionary:
	var result = {"normal": [], "reserve": []}
	
	if not card_system:
		print("[_find_winning_items_separated] card_systemなし")
		return result
	
	var hand = card_system.get_all_cards_for_player(current_player_id)
	var current_player = player_system.players[current_player_id] if player_system else null
	if not current_player:
		print("[_find_winning_items_separated] current_playerなし")
		return result
	
	print("[_find_winning_items_separated] current_player_id=%d 手札%d枚 魔力%d" % [current_player_id, hand.size(), current_player.magic_power])
	var item_count = 0
	for c in hand:
		if c.get("type", "") == "item":
			item_count += 1
			print("[_find_winning_items_separated]   アイテム: %s (%s)" % [c.get("name", "?"), c.get("item_type", "?")])
	
	for i in range(hand.size()):
		var card = hand[i]
		if card.get("type", "") != "item":
			continue
		
		var item_type = card.get("item_type", "")
		# 巻物は防御時使用しない
		if item_type == "巻物":
			continue
		
		# コストチェック
		var cost = _get_item_cost(card)
		if cost > current_player.magic_power:
			continue
		
		# ワーストケースシミュレーション（攻撃側もアイテムを使った場合）
		var sim_result = _simulate_defense_worst_case(card)
		var outcome = sim_result.get("result", -1)
		
		var is_reserve = _is_reserve_item(card)
		var reserve_mark = " [温存]" if is_reserve else ""
		
		print("  [アイテムシミュ(WC)] %s[%s]%s: %s" % [
			card.get("name", "?"),
			item_type,
			reserve_mark,
			_result_to_string(outcome)
		])
		
		var item_entry = {"index": i, "data": card, "cost": cost}
		
		if outcome == BattleSimulatorScript.BattleResult.DEFENDER_WIN:
			if is_reserve:
				result["reserve"].append(item_entry)
			else:
				result["normal"].append(item_entry)
		elif outcome == BattleSimulatorScript.BattleResult.ATTACKER_SURVIVED:
			# 死ぬより生き残る方がマシ
			if current_outcome == BattleSimulatorScript.BattleResult.ATTACKER_WIN or \
			   current_outcome == BattleSimulatorScript.BattleResult.BOTH_DEFEATED:
				if is_reserve:
					result["reserve"].append(item_entry)
				else:
					result["normal"].append(item_entry)
	
	return result

## 勝てる援護クリーチャーを探す（通常と温存対象を分離）
func _find_winning_assist_separated(current_outcome: int) -> Dictionary:
	var result = {"normal": [], "reserve": []}
	
	# 援護スキルを持っているかチェック
	if not has_assist_skill():
		return result
	
	if not card_system:
		return result
	
	var hand = card_system.get_all_cards_for_player(current_player_id)
	var current_player = player_system.players[current_player_id] if player_system else null
	if not current_player:
		return result
	
	# 援護対象属性を取得
	var target_elements = get_assist_target_elements()
	
	for i in range(hand.size()):
		var card = hand[i]
		if card.get("type", "") != "creature":
			continue
		
		# 援護対象属性チェック
		var element = card.get("element", "")
		if not target_elements.is_empty() and not "all" in target_elements:
			if not element in target_elements:
				continue
		
		# コストチェック
		var cost = _get_creature_cost(card)
		if cost > current_player.magic_power:
			continue
		
		# ワーストケースシミュレーション（援護 + 攻撃側もアイテムを使った場合）
		var sim_result = _simulate_defense_with_assist_worst_case(card)
		var outcome = sim_result.get("result", -1)
		
		var is_reserve = _is_reserve_creature(card)
		var reserve_mark = " [温存]" if is_reserve else ""
		
		print("  [援護シミュ(WC)] %s[%s]%s: %s" % [
			card.get("name", "?"),
			element,
			reserve_mark,
			_result_to_string(outcome)
		])
		
		var assist_entry = {"index": i, "data": card, "cost": cost}
		
		if outcome == BattleSimulatorScript.BattleResult.DEFENDER_WIN:
			if is_reserve:
				result["reserve"].append(assist_entry)
			else:
				result["normal"].append(assist_entry)
		elif outcome == BattleSimulatorScript.BattleResult.ATTACKER_SURVIVED:
			if current_outcome == BattleSimulatorScript.BattleResult.ATTACKER_WIN or \
			   current_outcome == BattleSimulatorScript.BattleResult.BOTH_DEFEATED:
				if is_reserve:
					result["reserve"].append(assist_entry)
				else:
					result["normal"].append(assist_entry)
	
	return result

## 援護クリーチャーを使った防御シミュレーション
func _simulate_defense_with_assist(assist_creature: Dictionary) -> Dictionary:
	var tile_info = _get_defense_tile_info()
	
	# 防御側データに援護効果を適用したコピーを作成
	var defender_with_assist = battle_creature_data.duplicate(true)
	defender_with_assist["ap"] = defender_with_assist.get("ap", 0) + assist_creature.get("ap", 0)
	defender_with_assist["hp"] = defender_with_assist.get("hp", 0) + assist_creature.get("hp", 0)
	
	var sim_tile_info = {
		"element": tile_info.get("element", ""),
		"level": tile_info.get("level", 1),
		"owner": current_player_id,
		"tile_index": tile_info.get("index", -1)
	}
	
	var attacker_player_id = -1
	if game_flow_manager and game_flow_manager.board_system_3d:
		attacker_player_id = game_flow_manager.board_system_3d.current_player_index
	
	return _battle_simulator.simulate_battle(
		opponent_creature_data,
		defender_with_assist,
		sim_tile_info,
		attacker_player_id,
		{},
		{}
	)

## 援護クリーチャーを使った防御シミュレーション（ワーストケース対応）
## 攻撃側もアイテムを使った場合を考慮
func _simulate_defense_with_assist_worst_case(assist_creature: Dictionary) -> Dictionary:
	var tile_info = _get_defense_tile_info()
	
	# 防御側データに援護効果を適用したコピーを作成
	var defender_with_assist = battle_creature_data.duplicate(true)
	defender_with_assist["ap"] = defender_with_assist.get("ap", 0) + assist_creature.get("ap", 0)
	defender_with_assist["hp"] = defender_with_assist.get("hp", 0) + assist_creature.get("hp", 0)
	
	var sim_tile_info = {
		"element": tile_info.get("element", ""),
		"level": tile_info.get("level", 1),
		"owner": current_player_id,
		"tile_index": tile_info.get("index", -1)
	}
	
	var attacker_player_id = -1
	if game_flow_manager and game_flow_manager.board_system_3d:
		attacker_player_id = game_flow_manager.board_system_3d.current_player_index
	
	# 攻撃側の手札からアイテムを取得
	if not cpu_hand_utils or attacker_player_id < 0:
		# hand_utilsがない場合は通常シミュレーション
		return _battle_simulator.simulate_battle(
			opponent_creature_data,
			defender_with_assist,
			sim_tile_info,
			attacker_player_id,
			{},
			{}
		)
	
	var attacker_items = cpu_hand_utils.get_enemy_items(attacker_player_id)
	
	# 対抗手段がない場合は通常シミュレーション
	if attacker_items.is_empty():
		return _battle_simulator.simulate_battle(
			opponent_creature_data,
			defender_with_assist,
			sim_tile_info,
			attacker_player_id,
			{},
			{}
		)
	
	# ワーストケースを探す
	var worst_result = _battle_simulator.simulate_battle(
		opponent_creature_data,
		defender_with_assist,
		sim_tile_info,
		attacker_player_id,
		{},
		{}
	)
	
	for attacker_item in attacker_items:
		var result = _battle_simulator.simulate_battle(
			opponent_creature_data,
			defender_with_assist,
			sim_tile_info,
			attacker_player_id,
			attacker_item,
			{}
		)
		
		if _is_worse_for_defender(result, worst_result):
			worst_result = result
	
	return worst_result

## クリーチャーコスト取得
func _get_creature_cost(creature: Dictionary) -> int:
	var cost_data = creature.get("cost", 0)
	if typeof(cost_data) == TYPE_DICTIONARY:
		return cost_data.get("mp", 0)
	return cost_data

## 最適な援護クリーチャーを選択
## コストが低い方優先
func _select_best_assist(assists: Array) -> Dictionary:
	if assists.is_empty():
		return {}
	
	# コスト昇順でソート
	assists.sort_custom(func(a, b):
		return a["cost"] < b["cost"]
	)
	
	return assists[0]["data"]

## 防御用の最適アイテムを探す
## 防御用アイテムの優先順位で選択
## 防具 > アクセサリ > 武器、コストが低い方優先
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
## 防具 > アクセサリ > 武器
func _get_defense_item_priority(item_type: String) -> int:
	match item_type:
		"防具": return 0
		"アクセサリ": return 1
		"武器": return 2
		_: return 99  # 巻物は使わない

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

## 攻撃側がアイテムを使った場合のワーストケースシミュレーション
## CPUBattleAI.simulate_worst_case_common を使用（共通ロジック）
func _simulate_defense_worst_case(defender_item: Dictionary) -> Dictionary:
	var tile_info = _get_defense_tile_info()
	
	var worst_tile_info = {
		"index": tile_info.get("index", -1),
		"element": tile_info.get("element", ""),
		"level": tile_info.get("level", 1),
		"owner": current_player_id
	}
	
	# CPUBattleAIの共通メソッドを使用
	if cpu_battle_ai != null:
		var worst_case = cpu_battle_ai.simulate_worst_case_common(
			battle_creature_data,      # 自分（防御側）
			opponent_creature_data,    # 相手（攻撃側）
			worst_tile_info,
			current_player_id,
			defender_item,
			false  # is_attacker = false（防御側）
		)
		
		# 結果を従来の形式に変換
		if worst_case.is_win:
			return {"result": BattleSimulatorScript.BattleResult.DEFENDER_WIN}
		else:
			return worst_case.get("sim_result", {"result": BattleSimulatorScript.BattleResult.ATTACKER_WIN})
	
	# フォールバック: cpu_battle_aiがない場合は従来のロジック
	var attacker_player_id = -1
	if game_flow_manager and game_flow_manager.board_system_3d:
		attacker_player_id = game_flow_manager.board_system_3d.current_player_index
	
	if not cpu_hand_utils or attacker_player_id < 0:
		return _simulate_defense_battle(defender_item)
	
	var attacker_items = cpu_hand_utils.get_enemy_items(attacker_player_id)
	
	if attacker_items.is_empty():
		return _simulate_defense_battle(defender_item)
	
	var worst_result = _simulate_defense_battle(defender_item)
	
	for attacker_item in attacker_items:
		var result = _battle_simulator.simulate_battle(
			opponent_creature_data,
			battle_creature_data,
			worst_tile_info,
			attacker_player_id,
			attacker_item,
			defender_item
		)
		
		if _is_worse_for_defender(result, worst_result):
			worst_result = result
	
	return worst_result


## 結果Aが結果Bより防御側にとって不利か
func _is_worse_for_defender(result_a: Dictionary, result_b: Dictionary) -> bool:
	var outcome_a = result_a.get("result", -1)
	var outcome_b = result_b.get("result", -1)
	
	# 防御側勝利 → 攻撃側勝利 は悪化
	if outcome_b == BattleSimulatorScript.BattleResult.DEFENDER_WIN:
		if outcome_a != BattleSimulatorScript.BattleResult.DEFENDER_WIN:
			return true
	
	# 両者生存 → 攻撃側勝利 は悪化
	if outcome_b == BattleSimulatorScript.BattleResult.ATTACKER_SURVIVED:
		if outcome_a == BattleSimulatorScript.BattleResult.ATTACKER_WIN:
			return true
	
	return false

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
		_battle_simulator.enable_log = true  # デバッグ用にログ有効

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

## 合体オプションをチェック
## 合体スキルを持ち、手札に合体相手がいて、コストを支払えて、合体で勝てるかを判定
func _check_merge_option() -> Dictionary:
	var result = {
		"can_merge": false,
		"wins": false,
		"partner_index": -1,
		"partner_data": {},
		"result_id": -1,
		"result_name": "",
		"cost": 0
	}
	
	# 合体スキルを持っているかチェック
	if not SkillMerge.has_merge_skill(battle_creature_data):
		return result
	
	# 手札を取得
	if not card_system:
		return result
	var hand = card_system.get_all_cards_for_player(current_player_id)
	
	# 手札に合体相手がいるかチェック
	var partner_index = SkillMerge.find_merge_partner_in_hand(battle_creature_data, hand)
	if partner_index == -1:
		return result
	
	# プレイヤーの魔力をチェック
	var current_player = player_system.players[current_player_id] if player_system else null
	if not current_player:
		return result
	
	var partner_data = hand[partner_index]
	var cost = SkillMerge.get_merge_cost(hand, partner_index)
	
	if cost > current_player.magic_power:
		print("[CPU合体] 魔力不足: 必要%dG, 現在%dG" % [cost, current_player.magic_power])
		return result
	
	# 合体結果のクリーチャーを取得
	var result_id = SkillMerge.get_merge_result_id(battle_creature_data)
	var result_creature = CardLoader.get_card_by_id(result_id)
	
	if result_creature.is_empty():
		return result
	
	result["can_merge"] = true
	result["partner_index"] = partner_index
	result["partner_data"] = partner_data
	result["result_id"] = result_id
	result["result_name"] = result_creature.get("name", "?")
	result["cost"] = cost
	
	print("[CPU合体] 合体可能: %s + %s → %s (コスト: %dG)" % [
		battle_creature_data.get("name", "?"),
		partner_data.get("name", "?"),
		result["result_name"],
		cost
	])
	
	# 合体後のクリーチャーでシミュレーション
	var sim_result = _simulate_defense_with_merge(result_creature)
	var outcome = sim_result.get("result", -1)
	
	print("[CPU合体] シミュレーション結果: %s" % _result_to_string(outcome))
	
	if outcome == BattleSimulatorScript.BattleResult.DEFENDER_WIN:
		result["wins"] = true
	elif outcome == BattleSimulatorScript.BattleResult.ATTACKER_SURVIVED:
		# 両者生存も勝利扱い（土地は守れる）
		result["wins"] = true
	
	return result

## 合体後のクリーチャーで防御シミュレーション
func _simulate_defense_with_merge(merged_creature: Dictionary) -> Dictionary:
	_ensure_battle_simulator()
	if not _battle_simulator:
		return {}
	
	var tile_info = _get_defense_tile_info()
	
	var sim_tile_info = {
		"element": tile_info.get("element", ""),
		"level": tile_info.get("level", 1),
		"owner": current_player_id,
		"tile_index": tile_info.get("index", -1)
	}
	
	# 攻撃側プレイヤーIDを取得
	var attacker_player_id = -1
	if game_flow_manager and game_flow_manager.board_system_3d:
		attacker_player_id = game_flow_manager.board_system_3d.current_player_index
	
	return _battle_simulator.simulate_battle(
		opponent_creature_data,  # 攻撃側
		merged_creature,         # 防御側（合体後）
		sim_tile_info,
		attacker_player_id,
		{},                      # 攻撃側アイテム（不明）
		{}                       # 防御側アイテム（合体のみ）
	)

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
		var reduction_rate = result.get("reduction_rate", 0.0)
		
		# 完全無効化（reduction_rate == 0.0）の場合のみアイテムスキップ
		if reduction_rate == 0.0:
			print("[CPU無効化判定] %s の完全無効化が %s に対して有効" % [
				battle_creature_data.get("name", "?"),
				opponent_creature_data.get("name", "?")
			])
			return true
		else:
			# 軽減（reduction_rate > 0）の場合はシミュレーションで計算
			print("[CPU無効化判定] %s のダメージ軽減(%.0f%%)が %s に対して有効 → シミュレーションで判断" % [
				battle_creature_data.get("name", "?"),
				(1.0 - reduction_rate) * 100,
				opponent_creature_data.get("name", "?")
			])
			return false
	
	return false

## 敵（攻撃側）が即死スキルを持っているかチェック
func _enemy_has_instant_death_skill() -> bool:
	var info = _get_enemy_instant_death_info()
	return not info.is_empty()

## 敵（攻撃側）の即死スキル情報を取得
## 返り値: { probability: int, condition: Dictionary } または空Dictionary
func _get_enemy_instant_death_info() -> Dictionary:
	if opponent_creature_data.is_empty():
		return {}
	
	var ability_parsed = opponent_creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	if "即死" not in keywords:
		return {}
	
	var keyword_conditions = ability_parsed.get("keyword_conditions", {})
	var instant_death_condition = keyword_conditions.get("即死", {})
	
	var probability = instant_death_condition.get("probability", 0)
	
	return {
		"probability": probability,
		"condition": instant_death_condition
	}

## 敵の即死が防御側（自分）に適用されるかチェック
func _is_instant_death_applicable_to_defender() -> bool:
	var info = _get_enemy_instant_death_info()
	if info.is_empty():
		return false
	
	# 100%即死でなければ、通常判断でOK
	if info.get("probability", 0) < 100:
		return false
	
	var condition = info.get("condition", {})
	var condition_type = condition.get("condition_type", "")
	
	# 無条件
	if condition_type == "" or condition_type == "none":
		return true
	
	var defender_element = battle_creature_data.get("element", "")
	var defender_ap = battle_creature_data.get("ap", 0)
	
	match condition_type:
		"enemy_is_element", "enemy_element":
			# 敵が特定属性（攻撃側から見て敵=防御側）
			# 単一属性
			if condition.has("element"):
				var required_element = condition.get("element", "")
				if required_element == "全":
					return true
				return defender_element == required_element
			
			# 複数属性
			var required_elements = condition.get("elements", [])
			if typeof(required_elements) == TYPE_STRING:
				if required_elements == "全":
					return true
				required_elements = [required_elements]
			
			return defender_element in required_elements
		
		"defender_ap_check":
			# 防御側のAPが一定以上
			var operator = condition.get("operator", ">=")
			var value = condition.get("value", 0)
			
			match operator:
				">=": return defender_ap >= value
				">": return defender_ap > value
				"==": return defender_ap == value
				_: return false
		
		"defender_role":
			# 攻撃側クリーチャーが「防御側なら即死」を持つ場合
			# 攻撃側として使っているので、この条件は適用されない
			return false
		
		_:
			# 未知の条件タイプは安全側に倒して適用とみなす
			return true

## 敵の即死スキルが自分に適用されるかチェック（確率も含めて返す）
## 返り値: { is_applicable: bool, probability: int }
func _check_instant_death_threat() -> Dictionary:
	var result = { "is_applicable": false, "probability": 0 }
	
	var info = _get_enemy_instant_death_info()
	if info.is_empty():
		return result
	
	var probability = info.get("probability", 0)
	var condition = info.get("condition", {})
	var condition_type = condition.get("condition_type", "")
	
	# 無条件
	if condition_type == "" or condition_type == "none":
		result.is_applicable = true
		result.probability = probability
		return result
	
	var defender_element = battle_creature_data.get("element", "")
	var defender_ap = battle_creature_data.get("ap", 0)
	var is_applicable = false
	
	match condition_type:
		"enemy_is_element", "enemy_element":
			# 敵が特定属性（攻撃側から見て敵=防御側）
			if condition.has("element"):
				var required_element = condition.get("element", "")
				if required_element == "全":
					is_applicable = true
				else:
					is_applicable = (defender_element == required_element)
			else:
				var required_elements = condition.get("elements", [])
				if typeof(required_elements) == TYPE_STRING:
					if required_elements == "全":
						is_applicable = true
					else:
						required_elements = [required_elements]
				if not is_applicable:
					is_applicable = (defender_element in required_elements)
		
		"defender_ap_check":
			# 防御側のAPが一定以上
			var operator = condition.get("operator", ">=")
			var value = condition.get("value", 0)
			match operator:
				">=": is_applicable = (defender_ap >= value)
				">": is_applicable = (defender_ap > value)
				"==": is_applicable = (defender_ap == value)
		
		"defender_role":
			# 攻撃側として使っているので、この条件は適用されない
			is_applicable = false
		
		_:
			# 未知の条件タイプは安全側に倒して適用とみなす
			is_applicable = true
	
	result.is_applicable = is_applicable
	result.probability = probability
	return result

## 防御用の無効化アイテムを探す（即死対策用）
## 通常攻撃を100%無効化するアイテムのみを検索
## 敵が即死スキルを持っている場合に呼ばれる
func _find_nullify_item_for_defense() -> Dictionary:
	if not card_system:
		return {}
	
	var hand = card_system.get_all_cards_for_player(current_player_id)
	var current_player = player_system.players[current_player_id] if player_system else null
	if not current_player:
		return {}
	
	var best_nullify_item = {}
	var best_cost = 999999
	
	for card in hand:
		if card.get("type", "") != "item":
			continue
		
		# 防具タイプをチェック
		var item_type = card.get("item_type", "")
		if item_type != "防具":
			continue
		
		# コストチェック
		var cost = _get_item_cost(card)
		if cost > current_player.magic_power:
			continue
		
		# 通常攻撃100%無効化をチェック
		if _is_full_normal_attack_nullify_item(card):
			# コストが低いものを優先
			if cost < best_cost:
				best_cost = cost
				best_nullify_item = card
				print("  [即死対策アイテム候補] %s (コスト: %d)" % [card.get("name", "?"), cost])
	
	return best_nullify_item

## アイテムが通常攻撃を100%無効化するかチェック
## nullify_type: "normal_attack" かつ reduction_rate がない（または0.0）
func _is_full_normal_attack_nullify_item(item: Dictionary) -> bool:
	var effect_parsed = item.get("effect_parsed", {})
	var effects = effect_parsed.get("effects", [])
	
	for effect in effects:
		# grant_skill で無効化を付与するタイプ
		if effect.get("effect_type", "") == "grant_skill" and effect.get("skill", "") == "無効化":
			var skill_params = effect.get("skill_params", {})
			var nullify_type = skill_params.get("nullify_type", "")
			var reduction_rate = skill_params.get("reduction_rate", 0.0)
			
			# 通常攻撃100%無効化
			if nullify_type == "normal_attack" and reduction_rate == 0.0:
				return true
	
	return false
