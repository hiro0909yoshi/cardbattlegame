class_name SpellLand
extends RefCounted

## SpellLand - 土地操作スペル効果
##
## 土地の属性変更、レベル操作、クリーチャー破壊などを担当

# システム参照
var board_system_ref: BoardSystem3D
var creature_manager_ref: CreatureManager
var player_system_ref: PlayerSystem
var card_system_ref: CardSystem
var game_flow_manager_ref = null  # ソリッドワールド判定用

## 初期化
func setup(board_system: BoardSystem3D, creature_manager: CreatureManager, player_system: PlayerSystem, card_system: CardSystem = null) -> void:
	board_system_ref = board_system
	creature_manager_ref = creature_manager
	player_system_ref = player_system
	card_system_ref = card_system
	
	if not board_system_ref:
		push_error("SpellLand: BoardSystem3Dが設定されていません")
	if not creature_manager_ref:
		push_error("SpellLand: CreatureManagerが設定されていません")
	if not player_system_ref:
		push_error("SpellLand: PlayerSystemが設定されていません")

## game_flow_manager参照を設定
func set_game_flow_manager(gfm) -> void:
	game_flow_manager_ref = gfm

## ソリッドワールド（土地変性無効）チェック（公開メソッド）
## SpellWorldCurseに委譲
func is_land_change_blocked() -> bool:
	if not game_flow_manager_ref or not game_flow_manager_ref.spell_world_curse:
		return false
	return game_flow_manager_ref.spell_world_curse.check_land_change_blocked(false)

## 土地の属性を変更
func change_element(tile_index: int, new_element: String) -> bool:
	
	if not board_system_ref:
		push_error("SpellLand.change_element: BoardSystem3Dが未設定")
		return false
	
	# ソリッドワールドチェック（ポップアップ付き）
	if game_flow_manager_ref and game_flow_manager_ref.spell_world_curse:
		if game_flow_manager_ref.spell_world_curse.check_land_change_blocked(true):
			return false
	
	# バロン等の土地破壊・変性無効チェック
	if _has_land_protection(tile_index):
		print("[土地変性無効] タイル%dは土地破壊・変性無効を持っています" % tile_index)
		return false
	
	if not _validate_tile_index(tile_index):
		return false
	
	if not _validate_element(new_element):
		push_error("SpellLand: 無効な属性 '%s'" % new_element)
		return false
	
	# BoardSystem3Dのchange_tile_terrainメソッドを使用
	var success = board_system_ref.change_tile_terrain(tile_index, new_element)
	
	
	return success

## 相互属性変更（ストームシフト、マグマシフト用）
func change_element_bidirectional(tile_index: int, element_a: String, element_b: String) -> bool:
	if not _validate_tile_index(tile_index):
		return false
	
	if not _validate_element(element_a) or not _validate_element(element_b):
		push_error("SpellLand: 無効な属性 '%s' または '%s'" % [element_a, element_b])
		return false
	
	var tile = board_system_ref.tile_nodes[tile_index]
	var current_element = tile.tile_type
	
	# 相互変換の判定
	if current_element == element_a:
		# element_a → element_b
		return change_element(tile_index, element_b)
	elif current_element == element_b:
		# element_b → element_a
		return change_element(tile_index, element_a)
	else:
		# どちらの属性でもない場合は変換しない
		print("[相互属性変更] タイル%d: 現在の属性%sは対象外" % [tile_index, current_element])
		return false

## 土地のレベルを変更（増減）
func change_level(tile_index: int, delta: int) -> bool:
	if not _validate_tile_index(tile_index):
		return false
	
	# ソリッドワールドチェック（レベルダウンのみブロック、ポップアップ付き）
	if delta < 0 and game_flow_manager_ref and game_flow_manager_ref.spell_world_curse:
		if game_flow_manager_ref.spell_world_curse.check_land_change_blocked(true):
			return false
	
	# バロン等の土地破壊・変性無効チェック（レベルダウンのみ）
	if delta < 0 and _has_land_protection(tile_index):
		print("[土地破壊無効] タイル%dは土地破壊・変性無効を持っています" % tile_index)
		return false
	
	# BoardSystem3DのtilesはNodeの配列なので、tile_nodesを使う
	if not board_system_ref.tile_nodes.has(tile_index):
		push_error("SpellLand: タイル%dが見つかりません" % tile_index)
		return false
	
	var tile = board_system_ref.tile_nodes[tile_index]
	var old_level = tile.level
	var new_level = clamp(old_level + delta, 1, 5)
	
	if new_level == old_level:
		return false
	
	tile.level = new_level
	
	# 表示を更新
	if board_system_ref.tile_data_manager:
		board_system_ref.tile_data_manager.update_all_displays()
	
	print("[土地レベル変更] タイル%d: Lv%d → Lv%d" % [tile_index, old_level, new_level])
	return true

## 土地のレベルを固定値に設定
func set_level(tile_index: int, level: int) -> bool:
	if not _validate_tile_index(tile_index):
		return false
	
	level = clamp(level, 1, 5)
	var tile = board_system_ref.tile_nodes[tile_index]
	var old_level = tile.level
	
	if level == old_level:
		return false
	
	tile.level = level
	tile.update_visual()
	
	print("[土地レベル設定] タイル%d: Lv%d → Lv%d" % [tile_index, old_level, level])
	return true

## クリーチャーを破壊
func destroy_creature(tile_index: int) -> bool:
	if not _validate_tile_index(tile_index):
		return false
	
	if not creature_manager_ref.has_creature(tile_index):
		print("[クリーチャー破壊] タイル%d: クリーチャーが存在しません" % tile_index)
		return false
	
	var creature_data = creature_manager_ref.get_data_ref(tile_index)
	var creature_name = creature_data.get("name", "不明")
	
	creature_manager_ref.set_data(tile_index, {})
	board_system_ref.remove_creature(tile_index)
	
	print("[クリーチャー破壊] タイル%d: %sを破壊" % [tile_index, creature_name])
	return true

## 土地を放棄（所有権を失う）
func abandon_land(tile_index: int, return_rate: float = 0.7) -> int:
	if not _validate_tile_index(tile_index):
		return 0
	
	var tile = board_system_ref.tile_nodes[tile_index]
	var player_id = tile.owner_id
	
	if player_id < 0:
		push_error("SpellLand: タイル%dは誰も所有していません" % tile_index)
		return 0
	
	var base_value = 100
	var land_value = int(tile.level * base_value * return_rate)
	
	if creature_manager_ref.has_creature(tile_index):
		destroy_creature(tile_index)
	
	var element = tile.tile_type
	tile.owner_id = -1
	tile.update_visual()
	
	# EPを付与
	player_system_ref.add_magic(player_id, land_value)
	
	print("[土地放棄] タイル%d: P%d Lv%d %s G%d獲得" % [tile_index, player_id, tile.level, element, land_value])
	return land_value

## 条件付き属性変更
func change_element_with_condition(tile_index: int, condition: Dictionary, new_element: String) -> bool:
	if not _validate_tile_index(tile_index):
		return false
	
	var tile = board_system_ref.tile_nodes[tile_index]
	
	if condition.has("max_level"):
		if tile.level > condition["max_level"]:
			return false
	
	if condition.has("required_elements"):
		if tile.tile_type not in condition["required_elements"]:
			return false
	
	return change_element(tile_index, new_element)

## プレイヤーの最多属性を取得
func get_player_dominant_element(player_id: int) -> String:
	if player_id < 0 or player_id >= player_system_ref.players.size():
		return "earth"
	
	# 実際にタイルをカウントして最多属性を取得
	var element_counts = {
		"fire": 0,
		"water": 0,
		"earth": 0,
		"wind": 0,
		"neutral": 0
	}
	
	# プレイヤーが所有する全タイルをカウント
	for tile_index in board_system_ref.tile_nodes.keys():
		var tile = board_system_ref.tile_nodes[tile_index]
		if tile.owner_id == player_id:
			var element = tile.tile_type
			if element_counts.has(element):
				element_counts[element] += 1
	
	# 最多の属性を見つける
	var max_count = 0
	var dominant_element = "earth"
	
	for element in element_counts.keys():
		if element_counts[element] > max_count:
			max_count = element_counts[element]
			dominant_element = element
	
	return dominant_element

## 条件付きレベル変更（複数タイル）
func change_level_multiple_with_condition(player_id: int, condition: Dictionary, delta: int) -> int:
	if player_id < 0 or player_id >= player_system_ref.players.size():
		return 0
	
	var changed_count = 0
	
	for tile_index in board_system_ref.tile_nodes.keys():
		var tile = board_system_ref.tile_nodes[tile_index]
		
		if tile.owner_id != player_id:
			continue
		
		if condition.has("required_level"):
			if tile.level != condition["required_level"]:
				continue
		
		if condition.has("required_elements"):
			if tile.tile_type not in condition["required_elements"]:
				continue
		
		if change_level(tile_index, delta):
			changed_count += 1
	
	return changed_count

## 最高レベルドミニオを検索
func find_highest_level_land(player_id: int) -> int:
	if player_id < 0 or player_id >= player_system_ref.players.size():
		return -1
	
	var highest_level = 0
	var highest_tile = -1
	
	for tile_index in board_system_ref.tile_nodes.keys():
		var tile = board_system_ref.tile_nodes[tile_index]
		if tile.owner_id == player_id:
			if tile.level > highest_level:
				highest_level = tile.level
				highest_tile = tile_index
	
	return highest_tile

## 最低レベルドミニオを検索
func find_lowest_level_land(player_id: int) -> int:
	if player_id < 0 or player_id >= player_system_ref.players.size():
		return -1
	
	var lowest_level = 999
	var lowest_tile = -1
	
	for tile_index in board_system_ref.tile_nodes.keys():
		var tile = board_system_ref.tile_nodes[tile_index]
		if tile.owner_id == player_id:
			if tile.level < lowest_level:
				lowest_level = tile.level
				lowest_tile = tile_index
	
	return lowest_tile

## クリーチャーと土地の属性が違う土地を検索（ホームグラウンド用）
func find_mismatched_element_lands(player_id: int) -> Array:
	if player_id < 0 or player_id >= player_system_ref.players.size():
		print("[属性不一致検索] 無効なプレイヤーID: %d" % player_id)
		return []
	
	var mismatched_tiles = []
	
	for tile_index in board_system_ref.tile_nodes.keys():
		var tile = board_system_ref.tile_nodes[tile_index]
		
		# 自分の土地でクリーチャーがいる場合のみ
		if tile.owner_id != player_id:
			continue
		
		if not creature_manager_ref.has_creature(tile_index):
			continue
		
		# クリーチャーの属性を取得
		var creature_data = creature_manager_ref.get_data_ref(tile_index)
		var creature_element = creature_data.get("element", "neutral")
		var land_element = tile.tile_type
		
		# 属性が違う場合（無属性も含む）
		if creature_element != land_element:
			mismatched_tiles.append(tile_index)
	
	
	return mismatched_tiles

## クリーチャーの属性に土地を合わせる（複数）
func align_lands_to_creature_elements(tile_indices: Array) -> int:
	var changed_count = 0
	
	for tile_index in tile_indices:
		if not _validate_tile_index(tile_index):
			continue
		
		if not creature_manager_ref.has_creature(tile_index):
			continue
		
		# クリーチャーの属性を取得
		var creature_data = creature_manager_ref.get_data_ref(tile_index)
		var creature_element = creature_data.get("element", "neutral")
		
		# 土地をクリーチャーの属性に変更
		if change_element(tile_index, creature_element):
			changed_count += 1
	
	return changed_count

## スペルカードをデッキに戻す（復帰[ブック]）
func return_spell_to_deck(player_id: int, spell_card: Dictionary) -> bool:
	if not card_system_ref:
		push_error("SpellLand: CardSystemの参照が設定されていません")
		return false
	
	var card_id = spell_card.get("id", -1)
	if card_id < 0:
		return false
	
	print("[復帰[ブック]] スペルカードID %d をデッキに戻します" % card_id)
	
	# 手札から削除（既に使用済みとしてマークされている可能性がある）
	var hand_data = card_system_ref.get_all_cards_for_player(player_id)
	for i in range(hand_data.size()):
		if hand_data[i].get("id", -1) == card_id:
			# player_hands[player_id]["data"]から直接削除
			if card_system_ref.player_hands.has(player_id):
				card_system_ref.player_hands[player_id]["data"].remove_at(i)
				print("[復帰[ブック]] 手札からカードID %d を削除" % card_id)
			break
	
	# 捨て札から削除（既に捨て札に入っている場合）
	if card_system_ref.player_discards and card_system_ref.player_discards.has(player_id):
		if card_id in card_system_ref.player_discards[player_id]:
			card_system_ref.player_discards[player_id].erase(card_id)
	
	# デッキのランダムな位置に戻す（item_returnスキルと同じ方式）
	if not card_system_ref.player_decks.has(player_id):
		push_error("SpellLand: プレイヤー%dのデッキが存在しません" % player_id)
		return false
	
	var deck = card_system_ref.player_decks[player_id]
	if deck.size() == 0:
		# デッキが空の場合は単純に追加
		deck.append(card_id)
		print("[復帰[ブック]] デッキ（空）に追加")
	else:
		# ランダムな位置に挿入
		var insert_pos = randi() % (deck.size() + 1)
		deck.insert(insert_pos, card_id)
		print("[復帰[ブック]] デッキの位置%dに挿入（全%d枚）" % [insert_pos, deck.size()])
	return true

## 検証：タイルインデックス
func _validate_tile_index(tile_index: int) -> bool:
	if not board_system_ref or not board_system_ref.tile_nodes.has(tile_index):
		push_error("SpellLand: 無効なタイルインデックス %d" % tile_index)
		return false
	return true

## 検証：属性
func _validate_element(element: String) -> bool:
	var valid_elements = ["fire", "water", "earth", "wind", "neutral"]
	return element in valid_elements

## ========================================
## SpellPhaseHandler統合用：統一効果適用メソッド
## ========================================

## 土地効果を適用（SpellPhaseHandlerから呼ばれる）
func apply_land_effect(effect: Dictionary, target_data: Dictionary, player_id: int) -> bool:
	var effect_type = effect.get("effect_type", "")
	
	# 条件付きスペルの場合、player_idをtarget_dataに追加
	var land_target_data = target_data.duplicate()
	if effect_type in ["conditional_level_change", "align_mismatched_lands"]:
		land_target_data["player_id"] = player_id
	
	match effect_type:
		"change_element":
			return _apply_effect_change_element(effect, land_target_data)
		
		"change_level":
			return _apply_effect_change_level(effect, land_target_data)
		
		"set_level":
			return _apply_effect_set_level(effect, land_target_data)
		
		"abandon_land":
			return _apply_effect_abandon_land(effect, land_target_data)
		
		"destroy_creature":
			return _apply_effect_destroy_creature(effect, land_target_data)
		
		"change_element_bidirectional":
			return _apply_effect_change_element_bidirectional(effect, land_target_data)
		
		"change_element_to_dominant":
			return _apply_effect_change_element_to_dominant(effect, land_target_data)
		
		"find_and_change_highest_level":
			return _apply_effect_find_and_change_highest_level(effect, land_target_data)
		
		"conditional_level_change":
			return _apply_effect_conditional_level_change(effect, land_target_data)
		
		"align_mismatched_lands":
			return _apply_effect_align_mismatched_lands(effect, land_target_data)
		
		"self_destruct":
			return _apply_effect_self_destruct(effect, land_target_data)
		
		"change_caster_tile_element":
			return _apply_effect_change_caster_tile_element(effect, land_target_data)
		
		_:
			push_error("SpellLand.apply_land_effect: 未対応のeffect_type '%s'" % effect_type)
			return false

## ========================================
## 内部：effect_type別の適用メソッド
## （既存メソッドを呼び出すラッパー）
## ========================================

func _apply_effect_change_element(effect: Dictionary, target_data: Dictionary) -> bool:
	var tile_index = target_data.get("tile_index", -1)
	var new_element = effect.get("element", "")
	
	if tile_index >= 0 and not new_element.is_empty():
		return change_element(tile_index, new_element)
	return false

func _apply_effect_change_level(effect: Dictionary, target_data: Dictionary) -> bool:
	var tile_index = target_data.get("tile_index", -1)
	var level_change = effect.get("value", 0)
	
	if tile_index >= 0:
		return change_level(tile_index, level_change)
	return false

func _apply_effect_set_level(effect: Dictionary, target_data: Dictionary) -> bool:
	var tile_index = target_data.get("tile_index", -1)
	var new_level = effect.get("value", 1)
	
	if tile_index >= 0:
		return set_level(tile_index, new_level)
	return false

func _apply_effect_abandon_land(effect: Dictionary, target_data: Dictionary) -> bool:
	var tile_index = target_data.get("tile_index", -1)
	var return_rate = effect.get("return_rate", 0.7)
	
	if tile_index >= 0:
		abandon_land(tile_index, return_rate)
		return true
	return false

func _apply_effect_destroy_creature(_effect: Dictionary, _target_data: Dictionary) -> bool:
	var tile_index = _target_data.get("tile_index", -1)
	
	if tile_index >= 0:
		return destroy_creature(tile_index)
	return false

func _apply_effect_change_element_bidirectional(effect: Dictionary, target_data: Dictionary) -> bool:
	var tile_index = target_data.get("tile_index", -1)
	var element_a = effect.get("element_a", "")
	var element_b = effect.get("element_b", "")
	
	if tile_index >= 0 and not element_a.is_empty() and not element_b.is_empty():
		return change_element_bidirectional(tile_index, element_a, element_b)
	return false

func _apply_effect_change_element_to_dominant(_effect: Dictionary, target_data: Dictionary) -> bool:
	var tile_index = target_data.get("tile_index", -1)
	
	if tile_index >= 0 and board_system_ref and board_system_ref.tile_nodes.has(tile_index):
		var tile = board_system_ref.tile_nodes[tile_index]
		var owner_id = tile.owner_id
		
		if owner_id >= 0:
			var dominant_element = get_player_dominant_element(owner_id)
			var success = change_element(tile_index, dominant_element)
			if success:
				print("[インフルエンス] タイル%d: プレイヤー%dの最多属性'%s'に変更" % [tile_index, owner_id, dominant_element])
			return success
	return false

func _apply_effect_find_and_change_highest_level(effect: Dictionary, target_data: Dictionary) -> bool:
	var all_players = effect.get("all_players", false)
	var level_change = effect.get("value", -1)
	
	# 合成時: 全敵プレイヤー対象
	if all_players:
		var _owner_filter = effect.get("owner_filter", "enemy")  # TODO: フィルタリングに使用予定
		var success_count = 0
		
		for player_id in range(player_system_ref.players.size()):
			# 敵プレイヤーのみ（owner_filter: enemy の場合）
			# ※ caster_idが必要だが、ここでは取得できないので全プレイヤー対象にする
			var highest_tile = find_highest_level_land(player_id)
			if highest_tile >= 0:
				var success = change_level(highest_tile, level_change)
				if success:
					print("[サブサイド合成] プレイヤー%dの最高レベルドミニオ（タイル%d）のレベルを変更" % [player_id + 1, highest_tile])
					success_count += 1
		
		return success_count > 0
	
	# 通常: 単一プレイヤー対象
	var target_player_id = target_data.get("player_id", -1)
	
	if target_player_id >= 0:
		var highest_tile = find_highest_level_land(target_player_id)
		if highest_tile >= 0:
			var success = change_level(highest_tile, level_change)
			if success:
				print("[サブサイド] プレイヤー%dの最高レベルドミニオ（タイル%d）のレベルを変更" % [target_player_id + 1, highest_tile])
			return success
	return false

func _apply_effect_conditional_level_change(effect: Dictionary, _target_data: Dictionary) -> bool:
	var required_level = effect.get("required_level", 2)
	var required_count = effect.get("required_count", 5)
	var level_change = effect.get("value", 1)
	var player_id = _target_data.get("player_id", -1)
	
	if player_id < 0:
		push_error("SpellLand: conditional_level_changeにplayer_idが必要です")
		return false
	
	var condition = {"required_level": required_level}
	var matching_tiles = []
	
	# 条件を満たす土地を数える
	for tile_index in board_system_ref.tile_nodes.keys():
		var tile = board_system_ref.tile_nodes[tile_index]
		if tile.owner_id == player_id and tile.level == required_level:
			matching_tiles.append(tile_index)
	
	# 条件判定（復帰[ブック]判定）
	if matching_tiles.size() < required_count:
		print("[条件不成立] レベル%dの土地が%d個（必要: %d個以上）" % [required_level, matching_tiles.size(), required_count])
		return false  # 失敗 = デッキに戻る
	
	# 条件を満たす場合、全ての該当土地をレベルアップ
	var changed_count = change_level_multiple_with_condition(player_id, condition, level_change)
	print("[条件成立] %d個の土地をレベル%d→%d" % [changed_count, required_level, required_level + level_change])
	return true

func _apply_effect_align_mismatched_lands(effect: Dictionary, _target_data: Dictionary) -> bool:
	var required_count = effect.get("required_count", 4)
	var player_id = _target_data.get("player_id", -1)
	
	if player_id < 0:
		push_error("SpellLand: align_mismatched_landsにplayer_idが必要です")
		return false
	
	var mismatched_tiles = find_mismatched_element_lands(player_id)
	
	# 条件判定（復帰[ブック]判定）
	if mismatched_tiles.size() < required_count:
		print("[条件不成立] 属性不一致の土地が%d個（必要: %d個以上）" % [mismatched_tiles.size(), required_count])
		return false  # 失敗 = デッキに戻る
	
	# 条件を満たす場合、指定数の土地を属性変更
	var tiles_to_change = mismatched_tiles.slice(0, required_count - 1)
	var changed_count = align_lands_to_creature_elements(tiles_to_change)
	
	print("[条件成立] %d個の土地をクリーチャーの属性に変更" % changed_count)
	return true


## 地形変化コストを計算
##
## @param tile_index タイルインデックス
## @return 地形変化コスト
func calculate_terrain_change_cost(tile_index: int) -> int:
	if not board_system_ref or not board_system_ref.tile_nodes.has(tile_index):
		return -1
	
	var tile = board_system_ref.tile_nodes[tile_index]
	var level = tile.level
	var tile_type = tile.tile_type
	
	# 1. アーキミミックがいる土地 → 50EP固定
	if _has_land_cost_modifier(tile_index):
		return 50
	
	# 2. 無属性タイル → 100 + ((レベル-1)×100)
	if tile_type == "neutral" or tile_type == "":
		return 100 + ((level - 1) * 100)
	
	# 3. その他 → 300 + ((レベル-1)×100)
	return 300 + ((level - 1) * 100)


## 地形変化コスト変化スキルを持つクリーチャーがいるかチェック
##
## @param tile_index タイルインデックス
## @return アーキミミック等がいるか
func _has_land_cost_modifier(tile_index: int) -> bool:
	if not creature_manager_ref:
		return false
	
	# タイルにいるクリーチャーを取得
	var creature_data = creature_manager_ref.get_data_ref(tile_index)
	if creature_data.is_empty():
		return false
	var creature_id = creature_data.get("id", 0)
	
	# アーキミミック（ID:402）チェック
	if creature_id == 402:
		return true
	
	# 将来的な拡張：ability_parsedで判定
	var ability_parsed = creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	for effect in effects:
		if effect.get("effect_type") == "terrain_change_cost_modifier":
			return true
	
	return false


## アルカナアーツ使用者のいるタイルの属性を変更（マカラ等）
func _apply_effect_change_caster_tile_element(effect: Dictionary, target_data: Dictionary) -> bool:
	var caster_tile_index = target_data.get("caster_tile_index", -1)
	if caster_tile_index < 0:
		push_error("SpellLand._apply_effect_change_caster_tile_element: caster_tile_indexが未設定")
		return false
	
	var new_element = effect.get("element", "")
	if new_element.is_empty():
		push_error("SpellLand._apply_effect_change_caster_tile_element: elementが未設定")
		return false
	
	return change_element(caster_tile_index, new_element)


## アルカナアーツ使用後に自壊
func _apply_effect_self_destruct(_effect: Dictionary, target_data: Dictionary) -> bool:
	# アルカナアーツを使用したクリーチャーのタイルを取得
	var caster_tile_index = target_data.get("caster_tile_index", -1)
	if caster_tile_index < 0:
		push_error("SpellLand._apply_effect_self_destruct: caster_tile_indexが未設定")
		return false
	
	if not board_system_ref or not board_system_ref.tile_nodes.has(caster_tile_index):
		push_error("SpellLand._apply_effect_self_destruct: タイルが見つかりません")
		return false
	
	var tile = board_system_ref.tile_nodes[caster_tile_index]
	var creature_data = tile.creature_data
	if creature_data.is_empty():
		print("[アルカナアーツ自壊] タイル%dにクリーチャーがいません" % caster_tile_index)
		return false
	
	var creature_name = creature_data.get("name", "?")
	var saved_level = tile.level
	
	# クリーチャーを削除（3Dカードも削除される）
	tile.remove_creature()
	
	# 所有者をリセット（空き地に戻す）
	tile.owner_id = -1
	tile.level = saved_level  # レベル維持
	
	# ビジュアル更新
	if tile.has_method("update_visual"):
		tile.update_visual()
	
	# タイル情報ラベル（通行料等）を更新
	if board_system_ref.tile_data_manager:
		board_system_ref.tile_data_manager.update_all_displays()
	
	print("[アルカナアーツ自壊] %s (タイル%d) が自壊しました" % [creature_name, caster_tile_index])
	return true


## タイルのクリーチャーが土地破壊・変性無効を持っているかチェック
func _has_land_protection(tile_index: int) -> bool:
	if not creature_manager_ref:
		return false
	
	var creature_data = creature_manager_ref.get_data_ref(tile_index)
	if creature_data.is_empty():
		return false
	
	var ability_parsed = creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	return "土地破壊・変性無効" in keywords
