class_name SpellMysticArts

# ============ 参照 ============

var board_system_ref: Object
var player_system_ref: Object
var card_system_ref: Object
var spell_phase_handler_ref: Object  # ターゲット取得用


# ============ 初期化 ============

func _init(board_sys: Object, player_sys: Object, card_sys: Object, spell_phase_handler: Object) -> void:
	board_system_ref = board_sys
	player_system_ref = player_sys
	card_system_ref = card_sys
	spell_phase_handler_ref = spell_phase_handler


# ============ 秘術情報取得 ============

## プレイヤーの秘術発動可能クリーチャーを取得
func get_available_creatures(player_id: int) -> Array:
	var available: Array = []
	
	var player_tiles = board_system_ref.get_player_tiles(player_id)
	if player_tiles.is_empty():
		return available
	
	for tile in player_tiles:
		if not tile or not tile.creature_data:
			continue
		
		var mystic_arts = tile.creature_data.get("ability_parsed", {}).get("mystic_arts", [])
		if mystic_arts.size() > 0:
			available.append({
				"tile_index": tile.tile_index,
				"creature_data": tile.creature_data,
				"mystic_arts": mystic_arts
			})
	
	return available


## クリーチャーの秘術一覧を取得
func get_mystic_arts_for_creature(creature_data: Dictionary) -> Array:
	if creature_data.is_empty():
		return []
	
	return creature_data.get("ability_parsed", {}).get("mystic_arts", [])


# ============ 発動判定 ============

## 秘術発動可能か判定
func can_cast_mystic_art(mystic_art: Dictionary, context: Dictionary) -> bool:
	# 魔力確認
	var cost = mystic_art.get("cost", 0)
	var player_magic = context.get("player_magic", 0)
	
	print("[SpellMysticArts] can_cast: cost=%d, player_magic=%d" % [cost, player_magic])
	
	if player_magic < cost:
		print("[SpellMysticArts] 失敗: 魔力不足")
		return false
	
	# スペル未使用確認
	if context.get("spell_used_this_turn", false):
		print("[SpellMysticArts] 失敗: スペル使用済み")
		return false
	
	# クリーチャーが行動可能か確認（ダウン状態チェック）
	var caster_tile_index = context.get("tile_index", -1)
	if caster_tile_index != -1:
		var caster_tile = board_system_ref.tile_nodes.get(caster_tile_index)
		if caster_tile and caster_tile.is_down():
			print("[SpellMysticArts] 失敗: ダウン状態")
			return false  # ダウン状態のクリーチャーは秘術使用不可
	
	# ターゲット有無確認
	if not _has_valid_target(mystic_art, context):
		print("[SpellMysticArts] 失敗: 有効なターゲットなし")
		return false
	
	return true


## 有効なターゲットが存在するか確認
func _has_valid_target(mystic_art: Dictionary, _context: Dictionary) -> bool:
	var target_type = mystic_art.get("target_type", "")
	var target_filter = mystic_art.get("target_filter", "any")
	
	# spell_idがある場合はスペルデータからターゲット情報を取得
	var spell_id = mystic_art.get("spell_id", -1)
	if spell_id > 0:
		var spell_data = CardLoader.get_card_by_id(spell_id)
		if not spell_data.is_empty():
			var effect_parsed = spell_data.get("effect_parsed", {})
			target_type = effect_parsed.get("target_type", target_type)
			var target_info = effect_parsed.get("target_info", {})
			target_filter = target_info.get("owner_filter", target_info.get("target_filter", "any"))
	
	# セルフターゲットは常に有効
	if target_filter == "self":
		return true
	
	# spell_phase_handler._get_valid_targets() を呼び出して確認
	# スペルと秘術で同じターゲット取得ロジックを共用（重複回避）
	if not spell_phase_handler_ref or not spell_phase_handler_ref.has_method("_get_valid_targets"):
		push_error("[SpellMysticArts] spell_phase_handler_ref が無効です")
		return false
	
	var valid_targets = spell_phase_handler_ref._get_valid_targets(target_type, target_filter)
	
	print("[SpellMysticArts] _has_valid_target: type=%s, filter=%s, count=%d" % [target_type, target_filter, valid_targets.size()])
	
	return valid_targets.size() > 0


# ============ 効果適用 ============

## 秘術効果を適用（メインエンジン）
func apply_mystic_art_effect(mystic_art: Dictionary, target_data: Dictionary, context: Dictionary) -> bool:
	if mystic_art.is_empty():
		return false
	
	# spell_idがある場合は既存スペルの効果を使用
	var spell_id = mystic_art.get("spell_id", -1)
	if spell_id > 0:
		return _apply_spell_effect(spell_id, target_data, context)
	
	# spell_idがない場合は秘術独自のeffectsを使用（従来方式）
	var effects = mystic_art.get("effects", [])
	var success = true
	
	for effect in effects:
		var applied = _apply_single_effect(effect, target_data, context)
		if not applied:
			success = false
	
	return success


## スペル効果を適用（spell_id参照方式）
func _apply_spell_effect(spell_id: int, target_data: Dictionary, _context: Dictionary) -> bool:
	# CardLoaderからスペルデータを取得
	var spell_data = CardLoader.get_card_by_id(spell_id)
	if spell_data.is_empty():
		push_error("[SpellMysticArts] spell_id=%d のスペルが見つかりません" % spell_id)
		return false
	
	print("[SpellMysticArts] スペル参照: %s (ID=%d)" % [spell_data.get("name", "Unknown"), spell_id])
	
	var effect_parsed = spell_data.get("effect_parsed", {})
	var effects = effect_parsed.get("effects", [])
	
	if effects.is_empty():
		push_error("[SpellMysticArts] spell_id=%d のeffectsが空です" % spell_id)
		return false
	
	# spell_phase_handlerに効果適用を委譲
	for effect in effects:
		if spell_phase_handler_ref and spell_phase_handler_ref.has_method("_apply_single_effect"):
			spell_phase_handler_ref._apply_single_effect(effect, target_data)
		else:
			push_error("[SpellMysticArts] spell_phase_handler_refが無効です")
			return false
	
	return true


## 1つの効果を適用
func _apply_single_effect(effect: Dictionary, target_data: Dictionary, context: Dictionary) -> bool:
	if effect.is_empty():
		return false
	
	var effect_type = effect.get("effect_type", "")
	
	print("[SpellMysticArts] effect_type='%s'" % effect_type)
	
	# 秘術固有の処理（秘術専用effect_typeのみここで処理）
	match effect_type:
		"destroy_deck_top":
			return _apply_destroy_deck_top(effect, target_data, context)
		"curse_attack":
			return _apply_curse_attack(effect, target_data, context)
		"steal_magic":
			return _apply_steal_magic(effect, target_data, context)
		"mass_buff":
			return _apply_mass_buff(effect, target_data, context)
		# 共通効果（damage, drain_magic, stat_boost等）はspell_phase_handlerに委譲
		_:
			if spell_phase_handler_ref and spell_phase_handler_ref.has_method("_apply_single_effect"):
				spell_phase_handler_ref._apply_single_effect(effect, target_data)
				return true
			else:
				push_error("[SpellMysticArts] spell_phase_handler_refが無効です")
				return false
			return false


# ============ 秘術専用効果実装 ============

## 効果：デッキ破壊
func _apply_destroy_deck_top(effect: Dictionary, target_data: Dictionary, _context: Dictionary) -> bool:
	var target_player_id = target_data.get("player_id", -1)
	var count = effect.get("value", 1)
	
	if target_player_id == -1 or count <= 0:
		return false
	
	if not card_system_ref or not card_system_ref.has_method("destroy_deck_top_cards"):
		push_error("[SpellMysticArts] card_system_ref が無効です")
		return false
	
	var destroyed = card_system_ref.destroy_deck_top_cards(target_player_id, count)
	return destroyed == count


## 効果：ダメージ
func _apply_damage(effect: Dictionary, target_data: Dictionary, _context: Dictionary) -> bool:
	var target_tile_index = target_data.get("tile_index", -1)
	var value = effect.get("value", 0)
	
	if target_tile_index == -1 or value <= 0:
		print("[SpellMysticArts] ダメージ適用失敗: tile_index=%d, value=%d" % [target_tile_index, value])
		return false
	
	var tile = board_system_ref.tile_nodes.get(target_tile_index)
	if not tile or not tile.creature_data or tile.creature_data.is_empty():
		print("[SpellMysticArts] ダメージ適用失敗: タイル/クリーチャーが無効")
		return false
	
	var creature = tile.creature_data
	var current_hp = creature.get("current_hp", creature.get("hp", 0))
	var new_hp = max(0, current_hp - value)
	creature["current_hp"] = new_hp
	
	print("[SpellMysticArts] ダメージ: %s に %d ダメージ (HP: %d → %d)" % [
		creature.get("name", "Unknown"),
		value,
		current_hp,
		new_hp
	])
	
	# クリーチャーが倒れた場合
	if new_hp <= 0:
		tile.creature_data = {}
		tile.owner_id = -1
		tile.level = 1
		if tile.has_method("update_visual"):
			tile.update_visual()
		print("[SpellMysticArts] クリーチャー撃破: %s" % creature.get("name", "Unknown"))
	
	return true


## 効果：呪いの一撃
func _apply_curse_attack(effect: Dictionary, target_data: Dictionary, _context: Dictionary) -> bool:
	var target_tile_index = target_data.get("tile_index", -1)
	var curse_type = effect.get("curse_type", "")
	var duration = effect.get("duration", 0)
	
	if target_tile_index == -1 or curse_type.is_empty():
		return false
	
	var tile = board_system_ref.tile_nodes.get(target_tile_index)
	if not tile or not tile.creature_data:
		return false
	
	# 呪い効果の追加（effect_system実装時に対応）
	# TODO: 呪いシステム実装後に実装
	
	print("[SpellMysticArts] 呪いの一撃: %s に %s（%d ターン）" % [
		tile.creature_data.get("name", "Unknown"),
		curse_type,
		duration
	])
	
	return true


## 効果：魔力窃取
func _apply_steal_magic(effect: Dictionary, target_data: Dictionary, context: Dictionary) -> bool:
	var target_player_id = target_data.get("player_id", -1)
	var amount = effect.get("value", 10)
	var caster_player_id = context.get("player_id", -1)
	
	if target_player_id == -1 or caster_player_id == -1 or amount <= 0:
		return false
	
	if not player_system_ref:
		push_error("[SpellMysticArts] player_system_ref が無効です")
		return false
	
	# 敵の魔力を取得して奪取量を計算
	var target_magic = player_system_ref.get_magic(target_player_id)
	var stolen = min(amount, target_magic)
	
	# 敵から魔力を減らす
	player_system_ref.add_magic(target_player_id, -stolen)
	
	# 使用者に付与
	player_system_ref.add_magic(caster_player_id, stolen)
	
	print("[SpellMysticArts] 魔力窃取: %dMP 奪取" % stolen)
	
	return true


## 効果：一括バフ（自分の全クリーチャー強化）
func _apply_mass_buff(effect: Dictionary, _target_data: Dictionary, context: Dictionary) -> bool:
	var caster_player_id = context.get("player_id", -1)
	var ap_bonus = effect.get("ap_bonus", 0)
	var hp_bonus = effect.get("hp_bonus", 0)
	
	if caster_player_id == -1:
		return false
	
	var player_tiles = board_system_ref.get_player_tiles(caster_player_id)
	if player_tiles.is_empty():
		return false
	
	var affected_count = 0
	
	for tile in player_tiles:
		if tile and tile.creature_data:
			if ap_bonus > 0:
				tile.creature_data["base_up_ap"] = tile.creature_data.get("base_up_ap", 0) + ap_bonus
			
			if hp_bonus > 0:
				# HPボーナスの追加
				tile.creature_data["current_hp"] = tile.creature_data.get("current_hp", 0) + hp_bonus
			
			affected_count += 1
	
	print("[SpellMysticArts] 一括バフ: %d体に AP+%d HP+%d" % [affected_count, ap_bonus, hp_bonus])
	
	return affected_count > 0


# ============ ダウン状態管理 ============

## 秘術発動後、キャスター（クリーチャー）をダウン状態に設定
func _set_caster_down_state(caster_tile_index: int, board_system_ref_param: Object) -> void:
	if caster_tile_index == -1:
		return
	
	var caster_tile = board_system_ref_param.tile_nodes.get(caster_tile_index)
	if not caster_tile:
		return
	
	var creature_data = caster_tile.creature_data
	if not creature_data:
		return
	
	# 不屈スキルで例外処理（ランドシステム仕様に準拠）
	# 不屈を持つクリーチャーはダウン状態にならない
	if _has_unyielding(creature_data):
		print("[秘術] 不屈により、『%s』はダウン状態になりません" % creature_data.get("name", "Unknown"))
		return
	
	# ダウン状態を設定
	if caster_tile.has_method("set_down"):
		caster_tile.set_down(true)
		print("[秘術] 『%s』はダウン状態になりました" % creature_data.get("name", "Unknown"))
	else:
		push_warning("[SpellMysticArts] タイルに set_down() メソッドがありません")


## 不屈スキルを持つか確認（ランドシステム仕様に準拠）
func _has_unyielding(creature_data: Dictionary) -> bool:
	if creature_data.is_empty():
		return false
	
	var ability_detail = creature_data.get("ability_detail", "")
	return "不屈" in ability_detail


# ============ ユーティリティ ============

## 秘術の情報を整形（UI表示用）
func get_mystic_art_info(mystic_art: Dictionary) -> Dictionary:
	if mystic_art.is_empty():
		return {
			"name": "Unknown",
			"description": "",
			"cost": 0,
			"target_type": "",
			"effects_count": 0
		}
	
	return {
		"name": mystic_art.get("name", "Unknown"),
		"description": mystic_art.get("description", ""),
		"cost": mystic_art.get("cost", 0),
		"target_type": mystic_art.get("target_type", ""),
		"effects_count": mystic_art.get("effects", []).size()
	}


## ターゲットクリーチャー情報を取得（UI表示用）
func get_target_creature_info(target_tile: Object) -> Dictionary:
	if not target_tile or not target_tile.creature_data:
		return {}
	
	var creature_data = target_tile.creature_data
	
	# Max HPの計算（基本HP + 土地ボーナス）
	var base_hp = creature_data.get("hp", 0)
	var land_bonus_hp = creature_data.get("land_bonus_hp", 0)
	var max_hp = base_hp + land_bonus_hp
	
	return {
		"name": creature_data.get("name", "Unknown"),
		"current_hp": creature_data.get("current_hp", max_hp),
		"max_hp": max_hp,
		"ap": creature_data.get("ap", 0)
	}
