# SpellDamage - ダメージ・回復処理の統合クラス
# スペル・アルカナアーツ共通で使用
class_name SpellDamage

var board_system_ref: Node = null
var spell_cast_notification_ui: Node = null

func _init(board_system: Node):
	board_system_ref = board_system

## 通知UIを設定
func set_notification_ui(ui: Node) -> void:
	spell_cast_notification_ui = ui

# ============================================
# 統合エントリポイント（SpellPhaseHandlerから呼び出し）
# ============================================

## ダメージ・回復スペル効果を適用（統合メソッド）
## 戻り値: 処理したかどうか
func apply_effect(handler: Node, effect: Dictionary, target_data: Dictionary) -> bool:
	var effect_type = effect.get("effect_type", "")
	var tile_index = target_data.get("tile_index", -1)
	
	match effect_type:
		"damage":
			var value = effect.get("value", 0)
			await apply_damage_effect(handler, tile_index, value)
			return true
		"heal":
			var value = effect.get("value", 0)
			await apply_heal_effect(handler, tile_index, value)
			return true
		"full_heal":
			await apply_full_heal_effect(handler, tile_index)
			return true
		"clear_down":
			await apply_clear_down_effect(handler, tile_index)
			return true
	
	return false


# ============================================
# 高レベル効果処理
# ============================================

## 単体ダメージ効果を適用（カメラ、通知、クリック待ち含む）
func apply_damage_effect(handler: Node, tile_index: int, value: int) -> void:
	if tile_index < 0:
		return
	
	# カメラをターゲットにフォーカス
	TargetSelectionHelper.focus_camera_on_tile(handler, tile_index)
	
	# ダメージ処理
	var result = apply_damage(tile_index, value)
	
	if result["success"]:
		var notification_text = format_damage_notification(result, value)
		await _show_notification_and_wait(notification_text)


## 単体固定値回復効果を適用（カメラ、通知、クリック待ち含む）
func apply_heal_effect(handler: Node, tile_index: int, value: int) -> void:
	if tile_index < 0 or value <= 0:
		return
	
	# カメラをターゲットにフォーカス
	TargetSelectionHelper.focus_camera_on_tile(handler, tile_index)
	
	# 回復処理
	var result = apply_heal(tile_index, value)
	
	if result["success"]:
		var notification_text = format_heal_notification(result, value)
		await _show_notification_and_wait(notification_text)


## 単体HP全回復効果を適用（カメラ、通知、クリック待ち含む）
func apply_full_heal_effect(handler: Node, tile_index: int) -> void:
	if tile_index < 0:
		return
	
	# カメラをターゲットにフォーカス
	TargetSelectionHelper.focus_camera_on_tile(handler, tile_index)
	
	# 全回復処理
	var result = apply_full_heal(tile_index)
	
	if result["success"]:
		var notification_text = format_heal_notification(result)
		await _show_notification_and_wait(notification_text)


## ダウン解除効果を適用（カメラ、通知、クリック待ち含む）
func apply_clear_down_effect(handler: Node, tile_index: int) -> void:
	if tile_index < 0 or not board_system_ref:
		return
	
	if not board_system_ref.tile_nodes.has(tile_index):
		return
	
	var tile = board_system_ref.tile_nodes[tile_index]
	if not tile or tile.creature_data.is_empty():
		return
	
	# ダウン状態でなければ何もしない
	if not tile.is_down():
		return
	
	# カメラをターゲットにフォーカス
	TargetSelectionHelper.focus_camera_on_tile(handler, tile_index)
	
	# ダウン解除
	tile.clear_down_state()
	
	var creature_name = tile.creature_data.get("name", "Unknown")
	var notification_text = "%sのダウン状態を解除！" % creature_name
	
	print("[SpellDamage] ダウン解除: %s" % creature_name)
	
	await _show_notification_and_wait(notification_text)


## 全クリーチャー対象のeffects配列を実行（ダメージ/回復を自動判定）
## 戻り値: 処理したかどうか（呪い効果等は未処理でfalse）
func execute_all_creatures_effects(handler: Node, effects: Array, target_info: Dictionary) -> bool:
	# 効果タイプを判定
	for effect in effects:
		var etype = effect.get("effect_type", "")
		if etype == "damage":
			var damage_value = effect.get("value", 0)
			if damage_value > 0:
				await apply_damage_to_all_creatures(handler, target_info, damage_value)
				return true
		elif etype == "full_heal":
			await apply_heal_to_all_creatures(handler, target_info)
			return true
		elif etype == "permanent_hp_change":
			var hp_value = effect.get("value", 0)
			await apply_permanent_hp_to_all_creatures(handler, target_info, hp_value)
			return true
	return false


## 全クリーチャーにダメージを適用（1体ずつカメラフォーカス→ダメージ→クリック待ち）
func apply_damage_to_all_creatures(handler: Node, target_info: Dictionary, damage_value: int) -> void:
	if not board_system_ref or damage_value <= 0:
		return
	
	# 対象クリーチャーを取得
	var targets = TargetSelectionHelper.get_valid_targets(handler, "creature", target_info)
	
	if targets.is_empty():
		print("[SpellDamage] 全体ダメージ: 対象なし")
		return
	
	print("[SpellDamage] 全体ダメージ: %d体に%dダメージ" % [targets.size(), damage_value])
	
	# 1体ずつ処理
	for target in targets:
		var tile_index = target.get("tile_index", -1)
		if tile_index < 0:
			continue
		
		# カメラをターゲットにフォーカス
		TargetSelectionHelper.focus_camera_on_tile(handler, tile_index)
		
		# ダメージ処理
		var result = apply_damage(tile_index, damage_value)
		
		if result["success"]:
			var notification_text = format_damage_notification(result, damage_value)
			await _show_notification_and_wait(notification_text)


## 全クリーチャーにHP全回復を適用（1体ずつカメラフォーカス→回復→クリック待ち）
func apply_heal_to_all_creatures(handler: Node, target_info: Dictionary) -> void:
	if not board_system_ref:
		return
	
	# 対象クリーチャーを取得
	var targets = TargetSelectionHelper.get_valid_targets(handler, "creature", target_info)
	
	if targets.is_empty():
		print("[SpellDamage] 全体回復: 対象なし")
		return
	
	print("[SpellDamage] 全体回復: %d体" % targets.size())
	
	# 1体ずつ処理
	for target in targets:
		var tile_index = target.get("tile_index", -1)
		if tile_index < 0:
			continue
		
		# カメラをターゲットにフォーカス
		TargetSelectionHelper.focus_camera_on_tile(handler, tile_index)
		
		# 全回復処理
		var result = apply_full_heal(tile_index)
		
		if result["success"]:
			var notification_text = format_heal_notification(result)
			await _show_notification_and_wait(notification_text)


## 全クリーチャーに恒久MHP変更を適用（マスグロース等）
func apply_permanent_hp_to_all_creatures(handler: Node, target_info: Dictionary, hp_value: int) -> void:
	if not board_system_ref:
		return
	
	# 対象クリーチャーを取得（全クリーチャー）
	var targets = TargetSelectionHelper.get_valid_targets(handler, "creature", target_info)
	
	if targets.is_empty():
		print("[SpellDamage] 全体MHP変更: 対象なし")
		return
	
	print("[SpellDamage] 全体MHP変更: %d体に MHP%s%d" % [targets.size(), "+" if hp_value >= 0 else "", hp_value])
	
	# 1体ずつ処理
	for target in targets:
		var tile_index = target.get("tile_index", -1)
		if tile_index < 0:
			continue
		
		var tile_info = board_system_ref.get_tile_info(tile_index)
		if tile_info.is_empty() or not tile_info.has("creature"):
			continue
		
		var creature_data = tile_info["creature"]
		if creature_data.is_empty():
			continue
		
		# カメラをターゲットにフォーカス
		TargetSelectionHelper.focus_camera_on_tile(handler, tile_index)
		
		# 旧MHPを保存
		var old_mhp = creature_data.get("hp", 0) + creature_data.get("base_up_hp", 0)
		var old_current_hp = creature_data.get("current_hp", old_mhp)
		
		# MHP変更（EffectManager使用）
		EffectManager.apply_max_hp_effect(creature_data, hp_value)
		
		# 新MHPを取得
		var new_mhp = creature_data.get("hp", 0) + creature_data.get("base_up_hp", 0)
		var new_current_hp = creature_data.get("current_hp", new_mhp)
		
		# 通知テキスト生成
		var creature_name = creature_data.get("name", "クリーチャー")
		var sign_str = "+" if hp_value >= 0 else ""
		var notification_text = "%s MHP%s%d\nMHP: %d → %d / HP: %d → %d" % [
			creature_name, sign_str, hp_value, old_mhp, new_mhp, old_current_hp, new_current_hp
		]
		
		await _show_notification_and_wait(notification_text)
		
		# HP0以下の場合はクリーチャーを破壊
		if new_current_hp <= 0:
			if board_system_ref.tile_nodes.has(tile_index):
				var tile = board_system_ref.tile_nodes[tile_index]
				if not tile.creature_data.is_empty():
					_destroy_creature(tile)
					var destroy_text = "%s は倒された！" % creature_name
					await _show_notification_and_wait(destroy_text)


## 通知表示＋クリック待ち（共通処理）
func _show_notification_and_wait(text: String) -> void:
	if spell_cast_notification_ui:
		spell_cast_notification_ui.show_notification_and_wait(text)
		await spell_cast_notification_ui.click_confirmed

# ============================================
# 低レベルダメージ処理
# ============================================

## ダメージを適用（スペル・アルカナアーツ共通）
## 戻り値: {success: bool, old_hp: int, new_hp: int, max_hp: int, destroyed: bool, creature_name: String}
func apply_damage(tile_index: int, value: int) -> Dictionary:
	var result = {
		"success": false,
		"old_hp": 0,
		"new_hp": 0,
		"max_hp": 0,
		"destroyed": false,
		"creature_name": ""
	}
	
	if not board_system_ref or tile_index < 0:
		return result
	
	if not board_system_ref.tile_nodes.has(tile_index):
		return result
	
	var tile = board_system_ref.tile_nodes[tile_index]
	if not tile or tile.creature_data.is_empty():
		return result
	
	var creature = tile.creature_data
	result["creature_name"] = creature.get("name", "Unknown")
	
	# MHP計算
	var base_hp = creature.get("hp", 0)
	var base_up_hp = creature.get("base_up_hp", 0)
	var max_hp = base_hp + base_up_hp
	result["max_hp"] = max_hp
	
	# current_hp取得（存在しない場合はMHP）
	var current_hp = creature.get("current_hp", max_hp)
	result["old_hp"] = current_hp
	
	# ダメージ適用
	var new_hp = max(0, current_hp - value)
	creature["current_hp"] = new_hp
	result["new_hp"] = new_hp
	result["success"] = true
	
	print("[SpellDamage] %s に %d ダメージ (HP: %d → %d / MHP: %d)" % [
		result["creature_name"], value, current_hp, new_hp, max_hp
	])
	
	# 撃破判定
	if new_hp <= 0:
		_destroy_creature(tile)
		result["destroyed"] = true
	
	return result


## クリーチャー破壊（レベル維持）
## スペル破壊時の死亡効果（遺産、変身）もここで処理
func _destroy_creature(tile: Node) -> void:
	var creature_data = tile.creature_data.duplicate()
	var creature_name = creature_data.get("name", "Unknown")
	var owner_id = tile.owner_id
	var _tile_index = tile.tile_index if "tile_index" in tile else -1
	var saved_level = tile.level  # レベル保存
	
	# スペル破壊時の死亡効果をチェック
	var death_result = _check_spell_death_effects(creature_data, owner_id, tile)
	
	# 変身した場合は破壊しない
	if death_result.get("transformed", false):
		print("[SpellDamage] %s は変身しました" % creature_name)
		return
	
	# 遺産効果（EP獲得）
	var legacy_amount = death_result.get("legacy_amount", 0)
	if legacy_amount > 0 and owner_id >= 0 and board_system_ref and board_system_ref.player_system:
		board_system_ref.player_system.add_magic(owner_id, legacy_amount)
		print("[遺産] プレイヤー%d: G%d を獲得" % [owner_id + 1, legacy_amount])
	
	# クリーチャーを削除（3Dカードも削除される）
	tile.remove_creature()
	
	tile.owner_id = -1
	tile.level = saved_level  # レベル維持（空き地として残る）
	
	if tile.has_method("update_visual"):
		tile.update_visual()
	
	print("[SpellDamage] クリーチャー撃破: %s (土地レベル %d 維持)" % [
		creature_name, saved_level
	])

## スペル破壊時の死亡効果をチェック
## 戻り値: {transformed: bool, legacy_amount: int}
func _check_spell_death_effects(creature_data: Dictionary, owner_id: int, tile: Node) -> Dictionary:
	var result = {"transformed": false, "legacy_amount": 0}
	
	var ability_parsed = creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		var trigger = effect.get("trigger", "")
		var effect_type = effect.get("effect_type", "")
		
		# スペル破壊時の変身（ジャッカロープ等）
		if trigger == "on_spell_death" and effect_type == "transform":
			var transform_to_id = effect.get("transform_to", -1)
			if transform_to_id > 0:
				var success = _apply_spell_death_transform(tile, transform_to_id, owner_id)
				if success:
					result["transformed"] = true
					return result  # 変身したら他の効果は発動しない
		
		# 遺産効果（コーンフォーク等）- on_deathは戦闘・スペル両方で発動
		if trigger == "on_death" and effect_type == "legacy_magic":
			var amount = effect.get("amount", 0)
			result["legacy_amount"] = amount
	
	return result

## スペル破壊時の変身処理
func _apply_spell_death_transform(tile: Node, transform_to_id: int, owner_id: int) -> bool:
	var new_creature_data = CardLoader.get_card_by_id(transform_to_id)
	if new_creature_data.is_empty():
		print("[スペル破壊変身] 変身先クリーチャーID %d が見つかりません" % transform_to_id)
		return false
	
	var new_creature = new_creature_data.duplicate(true)
	var new_name = new_creature.get("name", "?")
	
	# HP/APの初期化
	new_creature["current_hp"] = new_creature.get("hp", 0)
	if "tile_index" in tile:
		new_creature["tile_index"] = tile.tile_index
	
	# クリーチャーを置き換え（3Dカードも更新される）
	tile.place_creature(new_creature)
	
	print("[スペル破壊変身] %s に変身（オーナー: プレイヤー%d）" % [new_name, owner_id + 1])
	return true

# ============================================
# 低レベル回復処理
# ============================================

## HP回復を適用
## 戻り値: {success: bool, old_hp: int, new_hp: int, max_hp: int, creature_name: String}
func apply_heal(tile_index: int, value: int) -> Dictionary:
	var result = {
		"success": false,
		"old_hp": 0,
		"new_hp": 0,
		"max_hp": 0,
		"creature_name": ""
	}
	
	if not board_system_ref or tile_index < 0:
		return result
	
	if not board_system_ref.tile_nodes.has(tile_index):
		return result
	
	var tile = board_system_ref.tile_nodes[tile_index]
	if not tile or tile.creature_data.is_empty():
		return result
	
	var creature = tile.creature_data
	result["creature_name"] = creature.get("name", "Unknown")
	
	# MHP計算
	var base_hp = creature.get("hp", 0)
	var base_up_hp = creature.get("base_up_hp", 0)
	var max_hp = base_hp + base_up_hp
	result["max_hp"] = max_hp
	
	# current_hp取得
	var current_hp = creature.get("current_hp", max_hp)
	result["old_hp"] = current_hp
	
	# 回復適用（MHPを超えない）
	var new_hp = min(current_hp + value, max_hp)
	creature["current_hp"] = new_hp
	result["new_hp"] = new_hp
	result["success"] = true
	
	print("[SpellDamage] %s を %d 回復 (HP: %d → %d / MHP: %d)" % [
		result["creature_name"], value, current_hp, new_hp, max_hp
	])
	
	return result


## HP全回復
## 戻り値: {success: bool, old_hp: int, new_hp: int, max_hp: int, creature_name: String}
func apply_full_heal(tile_index: int) -> Dictionary:
	var result = {
		"success": false,
		"old_hp": 0,
		"new_hp": 0,
		"max_hp": 0,
		"creature_name": ""
	}
	
	if not board_system_ref or tile_index < 0:
		return result
	
	if not board_system_ref.tile_nodes.has(tile_index):
		return result
	
	var tile = board_system_ref.tile_nodes[tile_index]
	if not tile or tile.creature_data.is_empty():
		return result
	
	var creature = tile.creature_data
	result["creature_name"] = creature.get("name", "Unknown")
	
	# MHP計算
	var base_hp = creature.get("hp", 0)
	var base_up_hp = creature.get("base_up_hp", 0)
	var max_hp = base_hp + base_up_hp
	result["max_hp"] = max_hp
	
	# current_hp取得
	var current_hp = creature.get("current_hp", max_hp)
	result["old_hp"] = current_hp
	
	# 全回復
	creature["current_hp"] = max_hp
	result["new_hp"] = max_hp
	result["success"] = true
	
	print("[SpellDamage] %s HP全回復 (HP: %d → %d)" % [
		result["creature_name"], current_hp, max_hp
	])
	
	return result

# ============================================
# 通知テキスト生成
# ============================================

## ダメージ通知テキストを生成
static func format_damage_notification(result: Dictionary, damage_value: int) -> String:
	var text = "%sに%dダメージ！\n" % [result["creature_name"], damage_value]
	text += "HP: %d/%d → %d/%d" % [result["old_hp"], result["max_hp"], result["new_hp"], result["max_hp"]]
	
	if result["destroyed"]:
		text += "\n%sは倒された！" % result["creature_name"]
	
	return text


## 回復通知テキストを生成
static func format_heal_notification(result: Dictionary, heal_value: int = -1) -> String:
	var text = ""
	if heal_value > 0:
		text = "%sのHPが%d回復！\n" % [result["creature_name"], heal_value]
	else:
		text = "%sのHPが全回復！\n" % result["creature_name"]
	
	text += "HP: %d/%d → %d/%d" % [result["old_hp"], result["max_hp"], result["new_hp"], result["max_hp"]]
	return text


# ============================================
# 衰弱（プレイグ）ダメージ処理
# ============================================

## 衰弱呪いをチェックしてダメージを適用（バトル終了後に呼び出す）
## @param tile_index: バトルが行われた土地のインデックス
## @return Dictionary: {triggered: bool, damage: int, destroyed: bool, creature_name: String, ...}
func apply_plague_damage(tile_index: int) -> Dictionary:
	var result = {
		"triggered": false,
		"damage": 0,
		"destroyed": false,
		"creature_name": "",
		"old_hp": 0,
		"new_hp": 0,
		"max_hp": 0
	}
	
	if not board_system_ref or tile_index < 0:
		return result
	
	if not board_system_ref.tile_nodes.has(tile_index):
		return result
	
	var tile = board_system_ref.tile_nodes[tile_index]
	if not tile or tile.creature_data.is_empty():
		return result
	
	var creature = tile.creature_data
	
	# 呪いチェック
	var curse = creature.get("curse", {})
	if curse.get("curse_type") != "plague":
		return result
	
	result["creature_name"] = creature.get("name", "Unknown")
	result["triggered"] = true
	
	# MHP計算
	var base_hp = creature.get("hp", 0)
	var base_up_hp = creature.get("base_up_hp", 0)
	var max_hp = base_hp + base_up_hp
	result["max_hp"] = max_hp
	
	# ダメージ計算（MHP/2 切り上げ）
	var damage = ceili(float(max_hp) / 2.0)
	result["damage"] = damage
	
	# current_hp取得
	var current_hp = creature.get("current_hp", max_hp)
	result["old_hp"] = current_hp
	
	# ダメージ適用
	var new_hp = max(0, current_hp - damage)
	creature["current_hp"] = new_hp
	result["new_hp"] = new_hp
	
	print("[SpellDamage] 衰弱ダメージ: %s に %d ダメージ (HP: %d → %d / MHP: %d)" % [
		result["creature_name"], damage, current_hp, new_hp, max_hp
	])
	
	# 撃破判定
	if new_hp <= 0:
		_destroy_creature(tile)
		result["destroyed"] = true
		print("[SpellDamage] 衰弱により %s は倒された！" % result["creature_name"])
	
	return result


## 衰弱ダメージの通知テキストを生成
static func format_plague_notification(result: Dictionary) -> String:
	var text = "【衰弱】%sに%dダメージ！\n" % [result["creature_name"], result["damage"]]
	text += "HP: %d/%d → %d/%d" % [result["old_hp"], result["max_hp"], result["new_hp"], result["max_hp"]]
	
	if result["destroyed"]:
		text += "\n%sは倒された！" % result["creature_name"]
	
	return text
