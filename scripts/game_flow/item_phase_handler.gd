# ItemPhaseHandler - アイテム/巻物選択フェーズの処理を担当
extends Node
class_name ItemPhaseHandler

## シグナル
signal item_phase_started()
signal item_phase_completed()
signal item_passed()  # アイテム未使用
signal item_used(item_card: Dictionary)

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
var battle_creature_data: Dictionary = {}  # バトル参加クリーチャーのデータ（援護判定用）

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
	
	# 戦闘行動不可呪いチェック（防御側のみ呪いを持つ可能性がある）
	if SpellCurseBattle.has_battle_disable(creature_data):
		print("【戦闘行動不可】", creature_data.get("name", "?"), " はアイテム・援護使用不可 → 強制パス")
		pass_item()
		return
	
	item_phase_started.emit()
	

	
	# CPUの場合は簡易AI（現在は実装しない）
	if is_cpu_player(player_id):

		pass_item()
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
	
	# アイテムカードと援護対象クリーチャーカードを収集
	var selectable_cards = []
	var has_assist = has_assist_skill()
	var assist_elements = get_assist_target_elements()
	
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
			# アイテムクリーチャー判定
			var keywords = card.get("ability_parsed", {}).get("keywords", [])
			if "アイテムクリーチャー" in keywords:
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

## アイテムまたは援護クリーチャーを使用
func use_item(item_card: Dictionary):
	if current_state != State.WAITING_FOR_SELECTION:
		return
	
	if item_used_this_battle:
		return
	
	# カードタイプを判定
	var card_type = item_card.get("type", "")
	
	# クリーチャーの場合の追加チェック
	if card_type == "creature":
		# アイテムクリーチャー判定
		var keywords = item_card.get("ability_parsed", {}).get("keywords", [])
		var is_item_creature = "アイテムクリーチャー" in keywords
		
		if not is_item_creature:
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
