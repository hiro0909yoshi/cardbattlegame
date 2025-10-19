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
	EXECUTING_EFFECT    # 効果実行中
}

var current_state: State = State.INACTIVE
var current_player_id: int = -1
var selected_spell_card: Dictionary = {}
var spell_used_this_turn: bool = false  # 1ターン1回制限

## 参照
var ui_manager = null
var game_flow_manager = null
var card_system = null
var player_system = null
var board_system = null

func _ready():
	pass

## 初期化
func initialize(ui_mgr, flow_mgr, c_system = null, p_system = null, b_system = null):
	ui_manager = ui_mgr
	game_flow_manager = flow_mgr
	card_system = c_system if c_system else (flow_mgr.card_system if flow_mgr else null)
	player_system = p_system if p_system else (flow_mgr.player_system if flow_mgr else null)
	board_system = b_system if b_system else (flow_mgr.board_system_3d if flow_mgr else null)

## スペルフェーズ開始
func start_spell_phase(player_id: int):
	if current_state != State.INACTIVE:
		print("[SpellPhaseHandler] 既にアクティブです")
		return
	
	current_state = State.WAITING_FOR_INPUT
	current_player_id = player_id
	spell_used_this_turn = false
	selected_spell_card = {}
	
	spell_phase_started.emit()
	
	print("[SpellPhaseHandler] スペルフェーズ開始: プレイヤー ", player_id + 1)
	
	# UIを更新（スペルカードのみ選択可能にする）
	if ui_manager:
		_update_spell_phase_ui()
	
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
		print("[SpellPhaseHandler] 手札にスペルカードがありません")
		return
	
	# 現在のプレイヤー情報を取得
	var current_player = player_system.get_current_player() if player_system else null
	if not current_player:
		print("[SpellPhaseHandler] プレイヤー情報が取得できません")
		return
	
	# CardSelectionUIを使用してスペル選択
	if ui_manager.card_selection_ui.has_method("show_selection"):
		ui_manager.card_selection_ui.show_selection(current_player, "spell")

## CPUのスペル使用判定（簡易版）
func _handle_cpu_spell_turn():
	await get_tree().create_timer(1.0).timeout
	
	# 簡易AI: 30%の確率でスペルを使用
	if randf() < 0.3 and card_system:
		var spells = _get_available_spells(current_player_id)
		if not spells.is_empty():
			# ランダムに1つ選択
			var spell = spells[randi() % spells.size()]
			if _can_afford_spell(spell):
				print("[SpellPhaseHandler] CPU: スペル「%s」を使用" % spell.name)
				use_spell(spell)
				return
	
	# スペルを使わない
	print("[SpellPhaseHandler] CPU: スペルをパス")
	pass_spell()

## 利用可能なスペルカードを取得
func _get_available_spells(player_id: int) -> Array:
	if not card_system:
		return []
	
	var hand = card_system.get_all_cards_for_player(player_id)
	var spells = []
	
	for card in hand:
		if card.get("type", "") == "spell":
			spells.append(card)
	
	return spells

## スペルが使用可能か（コスト的に）
func _can_afford_spell(spell_card: Dictionary) -> bool:
	if not player_system:
		return false
	
	var current_player = player_system.get_current_player()
	if not current_player:
		return false
	
	var cost = spell_card.get("cost", {}).get("mp", 0)
	return current_player.magic_power >= cost

## スペルを使用
func use_spell(spell_card: Dictionary):
	if current_state != State.WAITING_FOR_INPUT:
		print("[SpellPhaseHandler] スペル使用できる状態ではありません")
		return
	
	if spell_used_this_turn:
		print("[SpellPhaseHandler] このターン既にスペルを使用しています")
		return
	
	if not _can_afford_spell(spell_card):
		print("[SpellPhaseHandler] 魔力が不足しています")
		return
	
	selected_spell_card = spell_card
	spell_used_this_turn = true
	
	# コストを支払う
	var cost = spell_card.get("cost", {}).get("mp", 0)
	if player_system:
		player_system.add_magic(current_player_id, -cost)
		print("[SpellPhaseHandler] 魔力消費: %d" % cost)
	
	# 対象選択が必要かチェック
	var parsed = spell_card.get("ability_parsed", {})
	var target_info = parsed.get("target", {})
	
	if target_info.get("required", false):
		# 対象選択が必要
		current_state = State.SELECTING_TARGET
		var target_type = target_info.get("type", "")
		print("[SpellPhaseHandler] 対象選択が必要: %s" % target_type)
		target_selection_required.emit(spell_card, target_type)
		
		# 対象選択UIを表示（次のステップで実装）
		_show_target_selection_ui(target_type, target_info)
	else:
		# 即座に効果発動
		execute_spell_effect(spell_card, {})

## 対象選択UIを表示
func _show_target_selection_ui(target_type: String, target_info: Dictionary):
	print("[SpellPhaseHandler] 対象選択UI表示: %s" % target_type)
	
	# 有効な対象を取得
	var targets = _get_valid_targets(target_type, target_info)
	
	if targets.is_empty():
		print("[SpellPhaseHandler] 有効な対象がありません")
		cancel_spell()
		return
	
	# TargetSelectionUIを作成
	var TargetSelectionUIClass = load("res://scripts/ui_components/target_selection_ui.gd")
	if not TargetSelectionUIClass:
		print("[SpellPhaseHandler] TargetSelectionUIが読み込めません")
		# フォールバック：最初の対象を自動選択
		on_target_selected(targets[0])
		return
	
	var target_ui = TargetSelectionUIClass.new()
	target_ui.initialize(board_system, player_system)
	
	# UIを画面に追加
	if ui_manager:
		ui_manager.add_child(target_ui)
	else:
		get_tree().root.add_child(target_ui)
	
	# シグナル接続
	target_ui.target_selected.connect(_on_target_ui_selected.bind(target_ui), CONNECT_ONE_SHOT)
	target_ui.selection_cancelled.connect(_on_target_ui_cancelled.bind(target_ui), CONNECT_ONE_SHOT)
	
	# 選択開始
	target_ui.show_target_selection(target_type, targets)

## 対象選択UIから選択された
func _on_target_ui_selected(target_data: Dictionary, target_ui):
	target_ui.queue_free()
	on_target_selected(target_data)

## 対象選択UIがキャンセルされた
func _on_target_ui_cancelled(target_ui):
	target_ui.queue_free()
	cancel_spell()

## 有効な対象を取得（仮実装）
func _get_valid_targets(target_type: String, _target_info: Dictionary) -> Array:
	var targets = []
	
	match target_type:
		"creature":
			# 敵クリーチャーを探す
			if board_system:
				for tile_index in board_system.tile_nodes.keys():
					var tile_info = board_system.get_tile_info(tile_index)
					var creature = tile_info.get("creature", {})
					if not creature.is_empty():
						var tile_owner = tile_info.get("owner", -1)
						if tile_owner != current_player_id and tile_owner >= 0:
							targets.append({
								"type": "creature",
								"tile_index": tile_index,
								"creature": creature,
								"owner": tile_owner
							})
		
		"player":
			# 敵プレイヤーを探す
			if player_system:
				for player in player_system.players:
					if player.id != current_player_id:
						targets.append({
							"type": "player",
							"player_id": player.id,
							"player": {
								"name": player.name,
								"magic_power": player.magic_power,
								"id": player.id
							}
						})
	
	return targets

## 対象が選択された
func on_target_selected(target_data: Dictionary):
	if current_state != State.SELECTING_TARGET:
		return
	
	print("[SpellPhaseHandler] 対象選択完了: ", target_data)
	execute_spell_effect(selected_spell_card, target_data)

## スペルをキャンセル
func cancel_spell():
	# コストを返却
	var cost = selected_spell_card.get("cost", {}).get("mp", 0)
	if player_system and cost > 0:
		player_system.add_magic(current_player_id, cost)
		print("[SpellPhaseHandler] スペルキャンセル、魔力返却: %d" % cost)
	
	selected_spell_card = {}
	spell_used_this_turn = false
	current_state = State.WAITING_FOR_INPUT

## スペル効果を実行
func execute_spell_effect(spell_card: Dictionary, target_data: Dictionary):
	current_state = State.EXECUTING_EFFECT
	
	print("[SpellPhaseHandler] スペル効果実行: %s" % spell_card.get("name", ""))
	
	var parsed = spell_card.get("ability_parsed", {})
	var effects = parsed.get("effects", [])
	
	for effect in effects:
		_apply_single_effect(effect, target_data)
	
	# カードを捨て札に
	if card_system:
		# 手札からカードのインデックスを探す
		var hand = card_system.get_all_cards_for_player(current_player_id)
		for i in range(hand.size()):
			if hand[i].get("id", -1) == spell_card.get("id", -2):
				card_system.discard_card(current_player_id, i, "use")
				break
	
	# 効果発動完了
	spell_used.emit(spell_card)
	
	# スペルフェーズ完了
	await get_tree().create_timer(1.0).timeout
	complete_spell_phase()

## 単一の効果を適用
func _apply_single_effect(effect: Dictionary, target_data: Dictionary):
	var effect_type = effect.get("effect_type", "")
	var value = effect.get("value", 0)
	
	print("[SpellPhaseHandler] 効果適用: %s (値: %d)" % [effect_type, value])
	
	match effect_type:
		"damage":
			# クリーチャーにダメージ
			if target_data.get("type", "") == "creature":
				var tile_index = target_data.get("tile_index", -1)
				if board_system and tile_index >= 0 and board_system.tile_nodes.has(tile_index):
					var tile = board_system.tile_nodes[tile_index]
					if tile and "creature_data" in tile:
						var creature = tile.creature_data
						if not creature.is_empty():
							var current_hp = creature.get("hp", 0)
							var land_bonus_hp = creature.get("land_bonus_hp", 0)
							var total_hp = current_hp + land_bonus_hp
							
							# ダメージを基本HPから優先的に減らす
							var damage_to_base = min(value, current_hp)
							creature["hp"] = current_hp - damage_to_base
							var remaining_damage = value - damage_to_base
							
							# 残りダメージを土地ボーナスHPから減らす
							if remaining_damage > 0:
								creature["land_bonus_hp"] = max(0, land_bonus_hp - remaining_damage)
							
							print("[SpellPhaseHandler] ダメージ適用: 合計HP %d → %d" % [total_hp, creature["hp"] + creature.get("land_bonus_hp", 0)])
							
							# クリーチャーが倒れた場合
							if creature["hp"] <= 0 and creature.get("land_bonus_hp", 0) <= 0:
								print("[SpellPhaseHandler] クリーチャー撃破！土地を空き地に")
								# タイルを空き地にする
								tile.creature_data = {}
								tile.owner_id = -1
								tile.level = 1
								tile.update_visual()
		
		"drain_magic":
			# 魔力を奪う
			if target_data.get("type", "") == "player" and player_system:
				var target_player_id = target_data.get("player_id", -1)
				
				if target_player_id >= 0:
					# PlayerSystemから実際の魔力を取得
					var current_magic = player_system.get_magic(target_player_id)
					var value_type = effect.get("value_type", "fixed")
					
					var drain_amount = 0
					if value_type == "percentage":
						drain_amount = int(current_magic * value / 100.0)
					else:
						drain_amount = value
					
					drain_amount = min(drain_amount, current_magic)  # 所持魔力以上は奪えない
					
					# 魔力を移動
					player_system.add_magic(target_player_id, -drain_amount)
					player_system.add_magic(current_player_id, drain_amount)
					
					print("[SpellPhaseHandler] 魔力吸収: %dG (対象P%d: %d → %d)" % [
						drain_amount,
						target_player_id + 1,
						current_magic,
						current_magic - drain_amount
					])

## スペルをパス
func pass_spell():
	spell_passed.emit()
	complete_spell_phase()

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
	
	spell_phase_completed.emit()
	
	print("[SpellPhaseHandler] スペルフェーズ完了")
	
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

## アクティブか
func is_spell_phase_active() -> bool:
	return current_state != State.INACTIVE
