# SpellCreatureReturn - クリーチャー手札戻しスペル
class_name SpellCreatureReturn

# ============ 参照 ============

var board_system_ref: Object
var player_system_ref: Object
var card_system_ref: Object
var spell_phase_handler_ref: Object


# ============ 初期化 ============

func _init(board_sys: Object, player_sys: Object, card_sys: Object, spell_phase_handler: Object = null) -> void:
	board_system_ref = board_sys
	player_system_ref = player_sys
	card_system_ref = card_sys
	spell_phase_handler_ref = spell_phase_handler


# ============ メイン効果適用 ============

## 効果を適用（effect_typeに応じて分岐）
func apply_effect(effect: Dictionary, target_data: Dictionary, caster_player_id: int) -> Dictionary:
	var effect_type = effect.get("effect_type", "")
	
	match effect_type:
		"return_to_hand":
			return _apply_return_to_hand(effect, target_data, caster_player_id)
		_:
			push_error("[SpellCreatureReturn] 未対応のeffect_type: %s" % effect_type)
			return {"success": false, "reason": "unknown_effect_type"}


# ============ 手札戻し効果実装 ============

## クリーチャーを手札に戻す
func _apply_return_to_hand(effect: Dictionary, target_data: Dictionary, _caster_player_id: int) -> Dictionary:
	var select_by = effect.get("select_by", "")
	
	# フィアー: プレイヤー指定 → 最低MHPクリーチャーを自動選択
	if select_by == "lowest_mhp":
		return _apply_return_lowest_mhp(target_data)
	
	# エグザイル/ホーリーバニッシュ: クリーチャー直接指定
	var tile_index = target_data.get("tile_index", -1)
	if tile_index == -1:
		return {"success": false, "reason": "invalid_tile"}
	
	return _execute_return_to_hand(tile_index)


## フィアー: 最低MHPクリーチャーを手札に戻す
func _apply_return_lowest_mhp(target_data: Dictionary) -> Dictionary:
	var target_player_id = target_data.get("player_id", -1)
	if target_player_id == -1:
		return {"success": false, "reason": "invalid_player"}
	
	# 対象プレイヤーのクリーチャーを取得
	var player_creatures = _get_player_creatures(target_player_id)
	if player_creatures.is_empty():
		return {"success": false, "reason": "no_creature"}
	
	# 最低MHPのクリーチャーを探す
	var lowest_tile_index = -1
	var lowest_mhp = 9999
	
	for tile_index in player_creatures:
		var tile = board_system_ref.tile_nodes.get(tile_index)
		if tile and not tile.creature_data.is_empty():
			var mhp = tile.creature_data.get("hp", 0)
			if mhp < lowest_mhp:
				lowest_mhp = mhp
				lowest_tile_index = tile_index
	
	if lowest_tile_index == -1:
		return {"success": false, "reason": "no_creature"}
	
	return _execute_return_to_hand(lowest_tile_index)


# ============ 手札戻し実行 ============

## クリーチャーを手札に戻す（共通処理）
func _execute_return_to_hand(tile_index: int) -> Dictionary:
	var tile = board_system_ref.tile_nodes.get(tile_index)
	if not tile or tile.creature_data.is_empty():
		return {"success": false, "reason": "no_creature"}
	
	# クリーチャー情報を取得
	var creature = tile.creature_data.duplicate()
	var creature_name = creature.get("name", "クリーチャー")
	var owner_id = tile.owner_id
	
	# 🔧 合成処理による分岐で手札に追加
	if card_system_ref and owner_id >= 0:
		var card_id = creature.get("id", -1)
		var synthesis_type = creature.get("synthesis_type", "")
		var clean_creature: Dictionary
		
		if synthesis_type == "transform":
			# 変身型合成：変身後のカードをそのまま返す
			clean_creature = card_system_ref._get_clean_card_data(card_id)
			if clean_creature.is_empty():
				clean_creature = creature.duplicate(true)
				_clean_creature_fields(clean_creature)
			print("[SpellCreatureReturn] %s を プレイヤー%d の手札に戻す（変身型合成）" % [creature_name, owner_id + 1])
		elif synthesis_type == "stat_boost":
			# ステータスアップ型合成：元のカードをクリーンで返す
			var original_id = creature.get("original_card_id", card_id)
			clean_creature = card_system_ref._get_clean_card_data(original_id)
			if clean_creature.is_empty():
				clean_creature = creature.duplicate(true)
				_clean_creature_fields(clean_creature)
				clean_creature.erase("is_synthesized")
				clean_creature.erase("synthesis_type")
				clean_creature.erase("original_card_id")
				clean_creature.erase("base_ap")
				clean_creature.erase("base_hp")
			print("[SpellCreatureReturn] %s を プレイヤー%d の手札に戻す（ステータス合成リセット）" % [clean_creature.get("name", "?"), owner_id + 1])
		else:
			# 通常：クリーンなカードデータを取得
			clean_creature = card_system_ref._get_clean_card_data(card_id)
			if clean_creature.is_empty():
				clean_creature = creature.duplicate(true)
				_clean_creature_fields(clean_creature)
			print("[SpellCreatureReturn] %s を プレイヤー%d の手札に戻す" % [creature_name, owner_id + 1])
		
		card_system_ref.player_hands[owner_id]["data"].append(clean_creature)
		card_system_ref.emit_signal("hand_updated")
	
	# レベル保存
	var saved_level = tile.level
	
	# クリーチャーを削除（3Dカードも削除される）
	tile.remove_creature()
	
	# 土地を空き地にする（所有権解除、レベルは維持）
	tile.owner_id = -1
	tile.level = saved_level
	
	if tile.has_method("update_visual"):
		tile.update_visual()
	
	print("[SpellCreatureReturn] タイル%d: クリーチャー除去、空き地化（レベル維持）" % tile_index)
	
	return {
		"success": true,
		"tile_index": tile_index,
		"creature_name": creature_name,
		"returned_to_player": owner_id
	}


# ============ ユーティリティ ============

## プレイヤーのクリーチャーがいるタイル一覧を取得
func _get_player_creatures(player_id: int) -> Array:
	var tiles: Array = []
	
	var player_tiles = board_system_ref.get_player_tiles(player_id)
	for tile in player_tiles:
		if tile and not tile.creature_data.is_empty():
			tiles.append(tile.tile_index)
	
	return tiles


# ============ ターゲット条件判定 ============

## エグザイル用: 呪い付き＆召喚条件なしか判定
func is_valid_exile_target(tile_index: int) -> bool:
	var tile = board_system_ref.tile_nodes.get(tile_index)
	if not tile or tile.creature_data.is_empty():
		return false
	
	var creature = tile.creature_data
	
	# 呪い付きチェック
	var has_curse = creature.has("curse") and not creature.curse.is_empty()
	if not has_curse:
		return false
	
	# 召喚条件なしチェック（cost_lands_required がない）
	var has_summon_condition = creature.has("cost_lands_required") and creature.cost_lands_required > 0
	if has_summon_condition:
		return false
	
	return true


## ホーリーバニッシュ用: 属性違いか判定
func is_valid_holy_banish_target(tile_index: int) -> bool:
	var tile = board_system_ref.tile_nodes.get(tile_index)
	if not tile or tile.creature_data.is_empty():
		return false
	
	var creature = tile.creature_data
	var creature_element = creature.get("element", "")
	var tile_element = tile.element if tile.has("element") else tile.get("element", "")
	
	# 属性が異なればターゲット可能
	return creature_element != tile_element


## クリーチャーフィールドをクリーン化
func _clean_creature_fields(creature: Dictionary) -> void:
	creature.erase("current_hp")
	creature.erase("curse")
	creature.erase("is_down")
	creature.erase("base_up_hp")
	creature.erase("base_up_ap")
	creature.erase("permanent_effects")
	creature.erase("temporary_effects")
	creature.erase("map_lap_count")
	creature.erase("items")
