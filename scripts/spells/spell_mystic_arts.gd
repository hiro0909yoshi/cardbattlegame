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
				"creature_name": tile.creature_data.get("name", "Unknown")
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
	
	if player_magic < cost:
		return false
	
	# スペル未使用確認
	if context.get("spell_used_this_turn", false):
		return false
	
	# クリーチャーが行動可能か確認（ダウン状態チェック）
	var caster_tile_index = context.get("tile_index", -1)
	if caster_tile_index != -1:
		var caster_tile = board_system_ref.get_tile(caster_tile_index)
		if caster_tile and caster_tile.is_down():
			return false  # ダウン状態のクリーチャーは秘術使用不可
	
	# ターゲット有無確認
	if not _has_valid_target(mystic_art, context):
		return false
	
	return true


## 有効なターゲットが存在するか確認
func _has_valid_target(mystic_art: Dictionary, _context: Dictionary) -> bool:
	var target_type = mystic_art.get("target_type", "")
	var target_filter = mystic_art.get("target_filter", "any")
	
	# セルフターゲットは常に有効
	if target_filter == "self":
		return true
	
	# spell_phase_handler._get_valid_targets() を呼び出して確認
	# スペルと秘術で同じターゲット取得ロジックを共用（重複回避）
	if not spell_phase_handler_ref or not spell_phase_handler_ref.has_method("_get_valid_targets"):
		push_error("[SpellMysticArts] spell_phase_handler_ref が無効です")
		return false
	
	var valid_targets = spell_phase_handler_ref._get_valid_targets(target_type, target_filter)
	
	return valid_targets.size() > 0


# ============ 効果適用 ============

## 秘術効果を適用（メインエンジン）
func apply_mystic_art_effect(mystic_art: Dictionary, target_data: Dictionary, context: Dictionary) -> bool:
	if mystic_art.is_empty():
		return false
	
	var effects = mystic_art.get("effects", [])
	var success = true
	
	for effect in effects:
		var applied = _apply_single_effect(effect, target_data, context)
		if not applied:
			success = false
	
	return success


## 1つの効果を適用
func _apply_single_effect(effect: Dictionary, target_data: Dictionary, context: Dictionary) -> bool:
	if effect.is_empty():
		return false
	
	var effect_type = effect.get("effect_type", "")
	
	# 秘術固有の処理
	match effect_type:
		"destroy_deck_top":
			return _apply_destroy_deck_top(effect, target_data, context)
		"curse_attack":
			return _apply_curse_attack(effect, target_data, context)
		"steal_magic":
			return _apply_steal_magic(effect, target_data, context)
		"mass_buff":
			return _apply_mass_buff(effect, target_data, context)
		# その他は spell_phase_handler に委譲
		_:
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


## 効果：呪いの一撃
func _apply_curse_attack(effect: Dictionary, target_data: Dictionary, _context: Dictionary) -> bool:
	var target_tile_index = target_data.get("tile_index", -1)
	var curse_type = effect.get("curse_type", "")
	var duration = effect.get("duration", 0)
	
	if target_tile_index == -1 or curse_type.is_empty():
		return false
	
	var tile = board_system_ref.get_tile(target_tile_index)
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
	
	# 敵の魔力を消費
	var stolen = player_system_ref.consume_magic(target_player_id, amount)
	
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
	
	var caster_tile = board_system_ref_param.get_tile(caster_tile_index)
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
