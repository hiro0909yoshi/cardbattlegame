# TargetFinder - ターゲット検索システム
#
# スペル・アルカナアーツ・ドミニオコマンドで使用するターゲットの検索・フィルタリングを担当
# - クリーチャー検索（属性、呪い、MHP、ダウン状態など）
# - プレイヤー検索（自分/敵/全員）
# - 土地検索（レベル、属性、距離）
# - ゲート検索（未訪問ゲート）
# - 防魔フィルタ自動適用
#
# 使用例:
#   # handler経由
#   var targets = TargetFinder.get_valid_targets(handler, "creature", {"owner_filter": "enemy"})
#   
#   # systems辞書経由（CPU用）
#   var targets = TargetFinder.get_valid_targets_core(systems, "creature", target_info)
extends RefCounted
class_name TargetFinder

# ============================================
# メイン検索関数
# ============================================

## 条件付きで全クリーチャーを取得（handlerなしで使用可能）
## 
## board_sys: BoardSystem3Dの参照
## condition: 条件辞書（condition_type, operator, value等）
## 戻り値: [{tile_index: int, creature: Dictionary}, ...]
static func get_all_creatures(board_sys, condition: Dictionary = {}) -> Array:
	var results = []
	
	if not board_sys:
		return results
	
	var condition_type = condition.get("condition_type", "")
	var operator = condition.get("operator", "")
	var check_value = condition.get("value", 0)
	
	for tile_index in board_sys.tile_nodes.keys():
		var tile = board_sys.tile_nodes[tile_index]
		if not tile or tile.creature_data.is_empty():
			continue
		
		var creature = tile.creature_data
		
		# 条件チェック
		var matches = true
		if condition_type == "mhp_check":
			var mhp = creature.get("hp", 0) + creature.get("base_up_hp", 0)
			match operator:
				"<=":
					matches = (mhp <= check_value)
				"<":
					matches = (mhp < check_value)
				">=":
					matches = (mhp >= check_value)
				">":
					matches = (mhp > check_value)
				"==":
					matches = (mhp == check_value)
		
		if matches:
			results.append({
				"tile_index": tile_index,
				"creature": creature
			})
	
	return results


## 有効なターゲットを取得
## 
## handler: board_system, player_system, current_player_id を持つオブジェクト
## target_type: "land", "creature", "player" など
## target_info: フィルター条件（owner_filter, max_level, required_elements など）
## 戻り値: ターゲット情報の配列
static func get_valid_targets(handler, target_type: String, target_info: Dictionary) -> Array:
	# ハンドラーから必要な情報を抽出してコア関数を呼び出す
	var gfm = handler.game_flow_manager if handler and "game_flow_manager" in handler else null
	var systems = {
		"board_system": handler.board_system if handler else null,
		"player_system": handler.player_system if handler else null,
		"current_player_id": handler.spell_state.current_player_id if (handler and handler.spell_state) else 0,
		"game_flow_manager": gfm,
		"spell_player_move": gfm.spell_container.spell_player_move if (gfm and gfm.spell_container) else null
	}
	return get_valid_targets_core(systems, target_type, target_info)


## CPU等からhandlerなしで呼び出せるコア関数
## systems: { board_system, player_system, current_player_id, game_flow_manager, spell_player_move }
## target_type: "land", "creature", "player" など
## target_info: フィルター条件
## 戻り値: ターゲット情報の配列
static func get_valid_targets_core(systems: Dictionary, target_type: String, target_info: Dictionary) -> Array:
	var sys_board = systems.get("board_system")
	var sys_player = systems.get("player_system")
	var current_player_id = systems.get("current_player_id", 0)
	var sys_flow = systems.get("game_flow_manager")
	var spell_player_move = systems.get("spell_player_move")
	var targets = []
	
	match target_type:
		"creature":
			targets = _find_creature_targets(sys_board, current_player_id, target_info)
		
		"player":
			targets = _find_player_targets(sys_player, current_player_id, target_info)
		
		"land", "own_land", "enemy_land":
			targets = _find_land_targets(sys_board, sys_player, sys_flow, spell_player_move, current_player_id, target_type, target_info)
		
		"unvisited_gate":
			targets = _find_gate_targets(spell_player_move, current_player_id)
	
	# most_common_element 後処理（クリーチャーターゲットのみ）
	if target_info.get("most_common_element", false) and not targets.is_empty():
		targets = _filter_by_most_common_element(targets)
	
	# 防魔フィルター（ignore_protection: true でスキップ可能）
	if not target_info.get("ignore_protection", false):
		var before_count = targets.size()
		var dummy_handler = DummyHandler.new(systems)
		targets = SpellProtection.filter_protected_targets(targets, dummy_handler)
		if before_count != targets.size():
			print("[TargetFinder] 防魔フィルタ適用: %d → %d 件" % [before_count, targets.size()])
	
	return targets


# ============================================
# ターゲットタイプ別検索
# ============================================

## クリーチャーターゲット検索
static func _find_creature_targets(sys_board, current_player_id: int, target_info: Dictionary) -> Array:
	var targets = []

	if not sys_board:
		return targets

	# タイル番号順にソート
	var tile_indices = sys_board.tile_nodes.keys()
	tile_indices.sort()

	for tile_index in tile_indices:
		var tile_info = sys_board.get_tile_info(tile_index)
		var creature = tile_info.get("creature", {})
		if creature.is_empty():
			continue

		var tile_owner = tile_info.get("owner", -1)
		var tile_element = tile_info.get("element", "")
		var tile = sys_board.tile_nodes[tile_index]

		# owner_filter チェック
		var owner_filter = target_info.get("owner_filter", "enemy")
		if owner_filter == "own":
			# チーム対応: is_same_team() を使用（FFA時は a == b）
			if tile_owner >= 0 and sys_board.player_system:
				if not sys_board.player_system.is_same_team(current_player_id, tile_owner):
					continue
			else:
				if tile_owner != current_player_id:
					continue
		elif owner_filter == "enemy":
			# チーム対応: 敵チームメンバーのみターゲット
			if tile_owner < 0:
				continue
			if sys_board.player_system:
				if sys_board.player_system.is_same_team(current_player_id, tile_owner):
					continue
			else:
				if tile_owner == current_player_id:
					continue
		elif owner_filter == "any" and tile_owner < 0:
			continue
		
		# creature_elements チェック（クリーチャー属性制限）
		var creature_elements = target_info.get("creature_elements", [])
		if not creature_elements.is_empty():
			var creature_element = creature.get("element", "")
			if creature_element not in creature_elements:
				continue
		
		# has_curse チェック
		if target_info.get("has_curse", false):
			if creature.get("curse", {}).is_empty():
				continue
		
		# has_no_curse チェック
		if target_info.get("has_no_curse", false):
			if not creature.get("curse", {}).is_empty():
				continue
		
		# has_no_mystic_arts チェック
		if target_info.get("has_no_mystic_arts", false):
			var mystic_arts = creature.get("ability_parsed", {}).get("mystic_arts", [])
			if not mystic_arts.is_empty():
				continue
		
		# has_summon_condition チェック
		if target_info.get("has_summon_condition", false):
			var has_lands = creature.has("cost_lands_required")
			var has_sacrifice = creature.has("cost_cards_sacrifice")
			if not has_lands and not has_sacrifice:
				continue
		
		# no_summon_condition チェック
		if target_info.get("no_summon_condition", false):
			var has_lands = creature.has("cost_lands_required") and creature.cost_lands_required > 0
			var has_sacrifice = creature.has("cost_cards_sacrifice") and creature.cost_cards_sacrifice > 0
			if has_lands or has_sacrifice:
				continue
		
		# hp_reduced チェック
		if target_info.get("hp_reduced", false):
			var base_hp = creature.get("hp", 0)
			var base_up_hp = creature.get("base_up_hp", 0)
			var max_hp = base_hp + base_up_hp
			var current_hp = creature.get("current_hp", max_hp)
			if current_hp >= max_hp:
				continue
		
		# is_down チェック
		if target_info.get("is_down", false):
			var is_down = tile.is_down() if tile.has_method("is_down") else false
			if not is_down:
				continue
		
		# has_adjacent_enemy チェック（アウトレイジ用）
		if target_info.get("has_adjacent_enemy", false):
			var has_adjacent = _check_has_adjacent_enemy(sys_board, tile_index, current_player_id)
			if not has_adjacent:
				continue
		
		# mhp_check チェック
		var mhp_check = target_info.get("mhp_check", {})
		if not mhp_check.is_empty():
			var base_hp = creature.get("hp", 0)
			var base_up_hp = creature.get("base_up_hp", 0)
			var mhp = base_hp + base_up_hp
			var op = mhp_check.get("operator", "")
			var val = mhp_check.get("value", 0)
			match op:
				">=":
					if mhp < val: continue
				"<=":
					if mhp > val: continue
				">":
					if mhp <= val: continue
				"<":
					if mhp >= val: continue
		
		# element_mismatch チェック
		if target_info.get("element_mismatch", false):
			var creature_element = creature.get("element", "")
			if creature_element == tile_element or creature_element == "neutral":
				continue
		
		# can_move チェック
		if target_info.get("can_move", false):
			var curse = creature.get("curse", {})
			if curse.get("curse_type", "") == "move_disable":
				continue
		
		# require_mystic_arts チェック
		if target_info.get("require_mystic_arts", false):
			var mystic_arts = creature.get("ability_parsed", {}).get("mystic_arts", [])
			var usable_arts = mystic_arts.filter(func(art):
				var effects = art.get("effects", [])
				for effect in effects:
					if effect.get("effect_type", "") == "use_hand_spell":
						return false
				return true
			)
			if usable_arts.is_empty():
				continue
		
		# require_not_down チェック
		if target_info.get("require_not_down", false):
			var is_down = tile.is_down() if tile.has_method("is_down") else false
			if is_down:
				continue
		
		# HP効果無効チェック
		if target_info.get("affects_hp", false):
			if SpellProtection.has_hp_effect_immune(creature):
				continue
		
		# 全条件を満たしたターゲットを追加
		targets.append({
			"type": "creature",
			"tile_index": tile_index,
			"creature": creature,
			"owner": tile_owner
		})
	
	return targets


## プレイヤーターゲット検索
static func _find_player_targets(sys_player, current_player_id: int, target_info: Dictionary) -> Array:
	var targets = []

	if not sys_player:
		return targets

	var target_filter = target_info.get("target_filter", "any")

	for player in sys_player.players:
		var is_current = (player.id == current_player_id)

		var matches = false
		if target_filter == "own":
			# チーム対応: is_same_team() を使用（FFA時は a == b）
			matches = sys_player.is_same_team(current_player_id, player.id)
		elif target_filter == "enemy":
			# チーム対応: 敵チームメンバーのみターゲット
			matches = not sys_player.is_same_team(current_player_id, player.id)
		elif target_filter == "any":
			matches = true

		if matches:
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


## 土地ターゲット検索
static func _find_land_targets(sys_board, sys_player, _sys_flow, spell_player_move, current_player_id: int, target_type: String, target_info: Dictionary) -> Array:
	var targets = []
	
	if not sys_board:
		return targets
	
	# target_typeに応じてデフォルトのowner_filterを設定
	var default_owner_filter = "any"
	if target_type == "own_land":
		default_owner_filter = "own"
	elif target_type == "enemy_land":
		default_owner_filter = "enemy"
	var owner_filter = target_info.get("owner_filter", default_owner_filter)
	var target_filter = target_info.get("target_filter", "")
	
	# タイル番号順にソート
	var tile_indices = sys_board.tile_nodes.keys()
	tile_indices.sort()
	
	for tile_index in tile_indices:
		var tile_info = sys_board.get_tile_info(tile_index)
		var tile_owner = tile_info.get("owner", -1)
		var creature = tile_info.get("creature", {})
		
		# 距離制限がある場合は全土地対象
		var has_distance_filter = target_info.has("distance_min") or target_info.has("distance_max")
		
		# 空き地フィルター
		if target_filter == "empty":
			if not creature.is_empty():
				continue
			var tile = sys_board.tile_nodes.get(tile_index)
			if tile and TileHelper.is_special_tile(tile):
				continue
		elif has_distance_filter:
			pass  # 距離制限がある場合は所有者チェックをスキップ
		else:
			# 所有者フィルター（チーム対応）
			var matches_owner = false
			if owner_filter == "own":
				# チーム対応: is_same_team() を使用
				if tile_owner >= 0 and sys_player:
					matches_owner = sys_player.is_same_team(current_player_id, tile_owner)
				else:
					matches_owner = (tile_owner == current_player_id)
			elif owner_filter == "enemy":
				# チーム対応: 敵チームメンバーのみターゲット
				if tile_owner < 0:
					matches_owner = false
				elif sys_player:
					matches_owner = not sys_player.is_same_team(current_player_id, tile_owner)
				else:
					matches_owner = (tile_owner != current_player_id)
			else:
				matches_owner = (tile_owner >= 0)

			if not matches_owner:
				continue
		
		var tile_level = tile_info.get("level", 1)
		var tile_element = tile_info.get("element", "")
		
		# レベル制限チェック
		var max_level = target_info.get("max_level", 999)
		var min_level = target_info.get("min_level", 1)
		var required_level = target_info.get("required_level", -1)
		
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
		
		# 距離制限チェック
		var distance_min = target_info.get("distance_min", -1)
		var distance_max = target_info.get("distance_max", -1)
		if distance_min > 0 or distance_max > 0:
			var tile = sys_board.tile_nodes.get(tile_index)
			if tile and tile.tile_type == "warp":
				continue
			
			var player_tile = -1
			if sys_board and sys_board.movement_controller:
				player_tile = sys_board.get_player_tile(current_player_id)
			elif sys_player and current_player_id >= 0:
				player_tile = sys_player.players[current_player_id].current_tile
			
			if player_tile >= 0 and spell_player_move:
				var dist = spell_player_move.calculate_tile_distance(player_tile, tile_index)
				if distance_min > 0 and dist < distance_min:
					continue
				if distance_max > 0 and dist > distance_max:
					continue
		
		# クリーチャー存在チェック
		if target_filter == "creature":
			if creature.is_empty():
				continue
			
			if target_info.get("has_no_curse", false):
				if not creature.get("curse", {}).is_empty():
					continue
			
			if target_info.get("has_no_mystic_arts", false):
				var mystic_arts = creature.get("ability_parsed", {}).get("mystic_arts", [])
				if not mystic_arts.is_empty():
					continue
			
			if target_info.get("is_down", false):
				var tile = sys_board.tile_nodes.get(tile_index)
				var is_down = tile.is_down() if tile and tile.has_method("is_down") else false
				if not is_down:
					continue
		
		targets.append({
			"type": "land",
			"tile_index": tile_index,
			"element": tile_element,
			"level": tile_level,
			"owner": tile_owner
		})
	
	return targets


## ゲートターゲット検索
static func _find_gate_targets(spell_player_move, current_player_id: int) -> Array:
	var targets = []

	if spell_player_move:
		var gate_tiles = spell_player_move.get_selectable_gate_tiles(current_player_id)
		for gate_info in gate_tiles:
			targets.append({
				"type": "gate",
				"tile_index": gate_info.get("tile_index", -1),
				"gate_key": gate_info.get("gate_key", "")
			})
	
	return targets


# ============================================
# フィルター・ヘルパー
# ============================================

## 隣接する敵ドミニオがあるかチェック（アウトレイジ用）
static func _check_has_adjacent_enemy(board_sys, tile_index: int, current_player_id: int) -> bool:
	if not board_sys or not board_sys.tile_neighbor_system:
		return false
	
	var adjacent_tiles = board_sys.tile_neighbor_system.get_spatial_neighbors(tile_index)
	for adj_tile_index in adjacent_tiles:
		var adj_tile = board_sys.tile_nodes.get(adj_tile_index)
		if not adj_tile:
			continue
		if adj_tile.owner_id != -1 and adj_tile.owner_id != current_player_id:
			return true
	
	return false


## 最多属性でフィルタリング（クラスターバースト用）
static func _filter_by_most_common_element(targets: Array) -> Array:
	var element_counts = {}
	for target in targets:
		var creature = target.get("creature", {})
		var element = creature.get("element", "neutral")
		if not element_counts.has(element):
			element_counts[element] = 0
		element_counts[element] += 1
	
	var max_count = 0
	for element in element_counts.keys():
		if element_counts[element] > max_count:
			max_count = element_counts[element]
	
	var most_common_elements = []
	for element in element_counts.keys():
		if element_counts[element] == max_count:
			most_common_elements.append(element)
	
	var filtered = []
	for target in targets:
		var creature = target.get("creature", {})
		var element = creature.get("element", "neutral")
		if element in most_common_elements:
			filtered.append(target)
	
	print("[TargetFinder] 最多属性: %s (%d体)" % [most_common_elements, filtered.size()])
	return filtered


# ============================================
# ダミーハンドラークラス（SpellProtection用）
# ============================================

class DummyHandler:
	var board_system
	var player_system
	var current_player_id: int
	var game_flow_manager
	
	func _init(systems: Dictionary):
		board_system = systems.get("board_system")
		player_system = systems.get("player_system")
		current_player_id = systems.get("current_player_id", 0)
		game_flow_manager = systems.get("game_flow_manager")
