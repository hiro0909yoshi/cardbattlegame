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
var mission_failed: bool = false  # 密命失敗フラグ

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

## 参照
var ui_manager = null
var game_flow_manager = null
var card_system = null
var player_system = null
var board_system = null
var creature_manager = null

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
				use_spell(spell)
				return
	
	# スペルを使わない
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
	
	# costがnullの場合は空のDictionaryとして扱う
	var cost_data = spell_card.get("cost", {})
	if cost_data == null:
		cost_data = {}
	
	var cost = 0
	if typeof(cost_data) == TYPE_DICTIONARY:
		cost = cost_data.get("mp", 0)
	
	return current_player.magic_power >= cost

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
	var target_info = parsed.get("target_info", {})
	
	if not target_type.is_empty() and target_type != "none":
		# 対象選択が必要
		current_state = State.SELECTING_TARGET
		target_selection_required.emit(spell_card, target_type)
		
		# 対象選択UIを表示
		_show_target_selection_ui(target_type, target_info)
	else:
		# 即座に効果発動（target_type が空または "none" の場合）
		execute_spell_effect(spell_card, {})

## 対象選択UIを表示（領地コマンドと同じ方式）
func _show_target_selection_ui(target_type: String, target_info: Dictionary):
	# 有効な対象を取得
	var targets = _get_valid_targets(target_type, target_info)
	
	if targets.is_empty():
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
	var text = "対象を選択: [↑↓で切替]
"
	text += "対象 %d/%d: " % [current_target_index + 1, available_targets.size()]
	
	# ターゲット情報表示
	match target.get("type", ""):
		"land":
			var tile_idx = target.get("tile_index", -1)
			var element = target.get("element", "neutral")
			var level = target.get("level", 1)
			var owner_id = target.get("owner", -1)
			
			# 属性名を日本語に変換
			var element_name = element
			match element:
				"fire": element_name = "火"
				"water": element_name = "水"
				"earth": element_name = "地"
				"wind": element_name = "風"
				"neutral": element_name = "無"
			
			var owner_id_text = ""
			if owner_id >= 0:
				owner_id_text = " (P%d)" % (owner_id + 1)
			
			text += "タイル%d %s Lv%d%s" % [tile_idx, element_name, level, owner_id_text]
		
		"creature":
			var tile_idx = target.get("tile_index", -1)
			var creature_name = target.get("creature", {}).get("name", "???")
			text += "タイル%d %s" % [tile_idx, creature_name]
		
		"player":
			var player_id = target.get("player_id", -1)
			text += "プレイヤー%d" % (player_id + 1)
	
	text += "
[Enter: 次へ] [C: 閉じる]"
	ui_manager.phase_label.text = text



## 有効な対象を取得（仮実装）
func _get_valid_targets(target_type: String, target_info: Dictionary) -> Array:
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
		
		"land", "own_land", "enemy_land":
			# 土地を対象とする
			if board_system:
				var owner_filter = target_info.get("owner_filter", "any")  # "own", "enemy", "any"
				
				for tile_index in board_system.tile_nodes.keys():
					var tile_info = board_system.get_tile_info(tile_index)
					var tile_owner = tile_info.get("owner", -1)
					
					# 所有者フィルター
					var matches_owner = false
					if owner_filter == "own":
						matches_owner = (tile_owner == current_player_id)
					elif owner_filter == "enemy":
						matches_owner = (tile_owner >= 0 and tile_owner != current_player_id)
					else:  # "any"
						matches_owner = (tile_owner >= 0)
					
					if matches_owner:
						var tile_level = tile_info.get("level", 1)
						var tile_element = tile_info.get("element", "")
						
						# レベル制限チェック
						var max_level = target_info.get("max_level", 999)
						var min_level = target_info.get("min_level", 1)
						var required_level = target_info.get("required_level", -1)
						
						# required_levelが指定されている場合は、そのレベルのみ対象
						if required_level > 0:
							if tile_level != required_level:
								continue
						elif tile_level < min_level or tile_level > max_level:
							continue
						
						# 属性制限チェック
						var required_elements = target_info.get("required_elements", [])
						if not required_elements.is_empty():
							if tile_element not in required_elements:
								continue
						
						# 条件を満たす土地を追加
						var land_target = {
							"type": "land",
							"tile_index": tile_index,
							"element": tile_element,
							"level": tile_level,
							"owner": tile_owner
						}
						targets.append(land_target)
	
	return targets

## 入力処理
func _input(event):
	if current_state != State.SELECTING_TARGET:
		return
	
	if event is InputEventKey and event.pressed:
		
		# ↑キーまたは←キー: 前の対象
		if event.keycode == KEY_UP or event.keycode == KEY_LEFT:
			if current_target_index > 0:
				current_target_index -= 1
				_update_target_selection()
			get_viewport().set_input_as_handled()
		
		# ↓キーまたは→キー: 次の対象
		elif event.keycode == KEY_DOWN or event.keycode == KEY_RIGHT:
			if current_target_index < available_targets.size() - 1:
				current_target_index += 1
				_update_target_selection()
			get_viewport().set_input_as_handled()
		
		# Enterキー: 確定
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_confirm_target_selection()
			get_viewport().set_input_as_handled()
		
		# 数字キー1-9, 0: 直接選択して即確定
		elif TargetSelectionHelper.is_number_key(event.keycode):
			var index = TargetSelectionHelper.get_number_from_key(event.keycode)
			if index < available_targets.size():
				current_target_index = index
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
	
	execute_spell_effect(selected_spell_card, selected_target)

## 対象選択をキャンセル
func _cancel_target_selection():
	# 選択をクリア
	TargetSelectionHelper.clear_selection(self)
	
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
	
	print("[execute_spell_effect] カード名='%s', ID=%d" % [spell_card.get("name", "???"), spell_card.get("id", -1)])
	
	# 密命失敗フラグをリセット
	mission_failed = false
	
	# 密命カード使用時のログ出力
	var is_secret = spell_card.get("is_secret", false)
	
	print("[execute_spell_effect] is_secret=%s, mission_failed=%s, debug_disable=%s" % [is_secret, mission_failed, debug_disable_secret_cards])
	
	# デバッグモード: 密命カードを通常カードとして扱う
	if debug_disable_secret_cards and is_secret:
		is_secret = false
		print("[デバッグ] 密命カードを通常カードとして実行します")
	
	if is_secret:
		print("[密命発動] プレイヤー%d が密命カード「%s」を使用" % [current_player_id, spell_card.get("name", "???")])
	
	var parsed = spell_card.get("effect_parsed", {})
	var effects = parsed.get("effects", [])
	
	print("[execute_spell_effect] effects配列: ", effects)
	
	for effect in effects:
		_apply_single_effect(effect, target_data)
	
	# カードを捨て札に（密命失敗時はスキップ）
	if card_system and not mission_failed:
		# 手札からカードのインデックスを探す
		var hand = card_system.get_all_cards_for_player(current_player_id)
		for i in range(hand.size()):
			if hand[i].get("id", -1) == spell_card.get("id", -2):
				card_system.discard_card(current_player_id, i, "use")
				break
	elif mission_failed:
		print("[密命失敗] カードは捨て札に送られず、デッキに戻されました")
	
	# 効果発動完了
	spell_used.emit(spell_card)
	
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
	var value = effect.get("value", 0)
	
	print("[_apply_single_effect] effect_type='%s'" % effect_type)
	
	match effect_type:
		"damage":
			# クリーチャーにダメージ
			_apply_damage_effect(effect, target_data)
		
		"drain_magic":
			# 魔力を奪う
			_apply_drain_magic_effect(effect, target_data)
		
		"change_element":
			# 土地属性変更（直接SpellLandを呼ぶ）
			var tile_index = target_data.get("tile_index", -1)
			var new_element = effect.get("element", "")
			if tile_index >= 0 and not new_element.is_empty():
				if game_flow_manager and game_flow_manager.spell_land:
					game_flow_manager.spell_land.change_element(tile_index, new_element)
		
		"change_level":
			# 土地レベル変更（直接SpellLandを呼ぶ）
			var tile_index = target_data.get("tile_index", -1)
			var level_change = effect.get("value", 0)
			if tile_index >= 0:
				if game_flow_manager and game_flow_manager.spell_land:
					game_flow_manager.spell_land.change_level(tile_index, level_change)
		
		"abandon_land":
			# 土地放棄（直接SpellLandを呼ぶ）
			var tile_index = target_data.get("tile_index", -1)
			var return_rate = effect.get("return_rate", 0.7)
			if tile_index >= 0:
				if game_flow_manager and game_flow_manager.spell_land:
					game_flow_manager.spell_land.abandon_land(tile_index, return_rate)
		
		"destroy_creature":
			# クリーチャー破壊（直接SpellLandを呼ぶ）
			var tile_index = target_data.get("tile_index", -1)
			if tile_index >= 0:
				if game_flow_manager and game_flow_manager.spell_land:
					game_flow_manager.spell_land.destroy_creature(tile_index)
		
		"change_element_bidirectional":
			# 相互属性変更（直接SpellLandを呼ぶ）
			var tile_index = target_data.get("tile_index", -1)
			var element_a = effect.get("element_a", "")
			var element_b = effect.get("element_b", "")
			if tile_index >= 0 and not element_a.is_empty() and not element_b.is_empty():
				if game_flow_manager and game_flow_manager.spell_land:
					game_flow_manager.spell_land.change_element_bidirectional(tile_index, element_a, element_b)
		
		"change_element_to_dominant":
			# 最多属性への変更（インフルエンス）（直接SpellLandを呼ぶ）
			var tile_index = target_data.get("tile_index", -1)
			if tile_index >= 0 and board_system and board_system.tile_nodes.has(tile_index):
				var tile = board_system.tile_nodes[tile_index]
				var owner_id = tile.owner_id
				if owner_id >= 0 and game_flow_manager and game_flow_manager.spell_land:
					var dominant_element = game_flow_manager.spell_land.get_player_dominant_element(owner_id)
					game_flow_manager.spell_land.change_element(tile_index, dominant_element)
					print("[インフルエンス] タイル%d: プレイヤー%dの最多属性'%s'に変更" % [tile_index, owner_id, dominant_element])
		
		"find_and_change_highest_level":
			# 最高レベル領地のレベル変更（サブサイド）（直接SpellLandを呼ぶ）
			var target_player_id = target_data.get("player_id", -1)
			if target_player_id >= 0 and game_flow_manager and game_flow_manager.spell_land:
				var highest_tile = game_flow_manager.spell_land.find_highest_level_land(target_player_id)
				if highest_tile >= 0:
					var level_change = effect.get("value", -1)
					game_flow_manager.spell_land.change_level(highest_tile, level_change)
					print("[サブサイド] プレイヤー%dの最高レベル領地（タイル%d）のレベルを変更" % [target_player_id, highest_tile])
		
		"mission_level_up_multiple":
			# 密命：複数レベルアップ（フラットランド）（直接SpellLandを呼ぶ）
			var required_level = effect.get("required_level", 2)
			var required_count = effect.get("required_count", 5)
			var level_change = effect.get("value", 1)
			if game_flow_manager and game_flow_manager.spell_land:
				print("[フラットランド] 必要レベル=%d, 必要数=%d, レベル変化=%d" % [required_level, required_count, level_change])
				var condition = {"required_level": required_level}
				var changed_count = game_flow_manager.spell_land.change_level_multiple_with_condition(
					current_player_id, condition, level_change
				)
				if changed_count >= required_count:
					print("[フラットランド成功] %d個の土地をレベルアップ" % changed_count)
				else:
					print("[フラットランド失敗] %d個しか条件を満たさなかった（必要: %d）" % [changed_count, required_count])
					if game_flow_manager.spell_land.return_spell_to_deck(current_player_id, selected_spell_card):
						mission_failed = true
		
		"mission_align_mismatched_lands":
			# 密命：属性不一致土地の整合（ホームグラウンド）（直接SpellLandを呼ぶ）
			var required_count = effect.get("required_count", 4)
			if game_flow_manager and game_flow_manager.spell_land:
				var mismatched_tiles = game_flow_manager.spell_land.find_mismatched_element_lands(current_player_id)
				if mismatched_tiles.size() >= required_count:
					var tiles_to_change = mismatched_tiles.slice(0, required_count)
					game_flow_manager.spell_land.align_lands_to_creature_elements(tiles_to_change)
				else:
					if game_flow_manager.spell_land.return_spell_to_deck(current_player_id, selected_spell_card):
						mission_failed = true

## クリーチャーダメージ効果
func _apply_damage_effect(effect: Dictionary, target_data: Dictionary):
	if target_data.get("type", "") != "creature":
		return
	
	var tile_index = target_data.get("tile_index", -1)
	var value = effect.get("value", 0)
	
	if not board_system or tile_index < 0 or not board_system.tile_nodes.has(tile_index):
		return
	
	var tile = board_system.tile_nodes[tile_index]
	if not tile or not "creature_data" in tile:
		return
	
	var creature = tile.creature_data
	if creature.is_empty():
		return
	
	var current_hp = creature.get("hp", 0)
	var land_bonus_hp = creature.get("land_bonus_hp", 0)
	
	# ダメージを基本HPから優先的に減らす
	var damage_to_base = min(value, current_hp)
	creature["hp"] = current_hp - damage_to_base
	var remaining_damage = value - damage_to_base
	
	# 残りダメージを土地ボーナスHPから減らす
	if remaining_damage > 0:
		creature["land_bonus_hp"] = max(0, land_bonus_hp - remaining_damage)
	
	# クリーチャーが倒れた場合
	if creature["hp"] <= 0 and creature.get("land_bonus_hp", 0) <= 0:
		tile.creature_data = {}
		tile.owner_id = -1
		tile.level = 1
		tile.update_visual()

## 魔力奪取効果
func _apply_drain_magic_effect(effect: Dictionary, target_data: Dictionary):
	if target_data.get("type", "") != "player" or not player_system:
		return
	
	var target_player_id = target_data.get("player_id", -1)
	if target_player_id < 0:
		return
	
	var value = effect.get("value", 0)
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
