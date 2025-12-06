## 戦闘終了時効果スキル
##
## 戦闘終了時（両者の攻撃完了後）に発動する効果を処理
## trigger: "on_battle_end" を持つ効果をチェックし適用
##
## 【担当効果】
## - ルナティックヘア (ID: 443): 敵のAP⇔MHP交換
## - スキュラ (ID: 124): 敵に呪い"通行料無効"
## - サムハイン (ID: 317): 敵のMHP-基本AP（未実装）
## - レーシィ (ID: 245): 戦闘地レベル+1（未実装）
##
## @version 1.0

class_name SkillBattleEndEffects


# =============================================================================
# メインエントリポイント
# =============================================================================

## 両者の戦闘終了時効果を処理
## @param attacker 攻撃側BattleParticipant
## @param defender 防御側BattleParticipant
## @param context 戦闘コンテキスト {board_system, tile_info, spell_world_curse}
## @return Dictionary {attacker_died: bool, defender_died: bool}
static func process_all(attacker, defender, context: Dictionary = {}) -> Dictionary:
	var result = {
		"attacker_died": false,
		"defender_died": false
	}
	
	# ナチュラルワールド無効化チェック
	var game_stats = context.get("game_stats", {})
	if _is_battle_end_nullified(game_stats):
		print("【戦闘終了時効果】ナチュラルワールドにより無効化")
		return result
	
	# 攻撃側の効果を処理（対象: 防御側）
	if attacker and attacker.is_alive():
		var attacker_result = _process_effects(attacker, defender, context)
		if attacker_result.get("target_died", false):
			result["defender_died"] = true
	
	# 防御側の効果を処理（対象: 攻撃側）
	if defender and defender.is_alive():
		var defender_result = _process_effects(defender, attacker, context)
		if defender_result.get("target_died", false):
			result["attacker_died"] = true
	
	return result


# =============================================================================
# 効果処理
# =============================================================================

## 単体の戦闘終了時効果を処理
## @param self_participant 効果発動側
## @param enemy_participant 効果対象側（敵）
## @param context 戦闘コンテキスト
## @return Dictionary {target_died: bool}
static func _process_effects(self_participant, enemy_participant, context: Dictionary) -> Dictionary:
	var result = {"target_died": false}
	
	var ability_parsed = self_participant.creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		var trigger = effect.get("trigger", "")
		if trigger != "on_battle_end":
			continue
		
		var effect_type = effect.get("effect_type", "")
		var target = effect.get("target", "")
		
		# 土地対象の効果（レーシィ等）
		if effect_type == "level_up_battle_land":
			_apply_level_up_battle_land(self_participant, effect, context)
			continue
		
		# 敵対象の効果は敵が生存している場合のみ
		if not enemy_participant or not enemy_participant.is_alive():
			continue
		
		# targetが指定されていない場合はenemyをデフォルトに
		if target.is_empty():
			target = "enemy"
		
		match effect_type:
			"swap_ap_mhp":
				if target == "enemy":
					var swap_result = _apply_swap_ap_mhp(self_participant, enemy_participant)
					if swap_result.get("target_died", false):
						result["target_died"] = true
			
			"apply_curse":
				if target == "enemy":
					_apply_curse_effect(self_participant, enemy_participant, effect)
			
			"reduce_enemy_mhp":
				if target == "enemy":
					var reduce_result = _apply_reduce_mhp(self_participant, enemy_participant, effect)
					if reduce_result.get("target_died", false):
						result["target_died"] = true
	
	return result


# =============================================================================
# 個別効果実装
# =============================================================================

## AP⇔MHP交換（ルナティックヘア）
## @return Dictionary {target_died: bool, old_ap: int, old_mhp: int, new_ap: int, new_mhp: int}
static func _apply_swap_ap_mhp(self_participant, enemy_participant) -> Dictionary:
	var result = {
		"target_died": false,
		"old_ap": 0,
		"old_mhp": 0,
		"new_ap": 0,
		"new_mhp": 0
	}
	
	var self_name = self_participant.creature_data.get("name", "?")
	var enemy_data = enemy_participant.creature_data
	var enemy_name = enemy_data.get("name", "?")
	
	# 現在のAP（基礎AP + base_up_ap）
	var old_ap = enemy_data.get("ap", 0) + enemy_data.get("base_up_ap", 0)
	
	# 現在のMHP（基礎HP + base_up_hp）
	var old_mhp = enemy_data.get("hp", 0) + enemy_data.get("base_up_hp", 0)
	
	# 現在HP（BattleParticipantから取得）
	var old_current_hp = enemy_participant.current_hp
	
	result["old_ap"] = old_ap
	result["old_mhp"] = old_mhp
	
	# 交換実行
	# APをMHPに、MHPをAPに設定
	# 基礎値を交換し、base_up_*はリセット
	var new_ap = old_mhp
	var new_mhp = old_ap
	
	enemy_data["ap"] = new_ap
	enemy_data["base_up_ap"] = 0
	enemy_data["hp"] = new_mhp
	enemy_data["base_up_hp"] = 0
	
	# current_hpも調整（新MHPを超えないように）
	var new_current_hp = mini(old_current_hp, new_mhp)
	enemy_data["current_hp"] = new_current_hp
	enemy_participant.current_hp = new_current_hp
	
	result["new_ap"] = new_ap
	result["new_mhp"] = new_mhp
	
	print("【戦闘終了時効果】%s が %s のAP⇔MHP交換 (AP: %d→%d, MHP: %d→%d, HP: %d→%d)" % [
		self_name, enemy_name, old_ap, new_ap, old_mhp, new_mhp, old_current_hp, new_current_hp
	])
	
	# 死亡判定（MHP=0 または current_hp=0）
	if new_mhp <= 0 or new_current_hp <= 0:
		print("【戦闘終了時効果】%s は死亡" % enemy_name)
		result["target_died"] = true
		enemy_data["current_hp"] = 0
		enemy_participant.current_hp = 0
	
	return result


## 呪い付与（スキュラ等）
static func _apply_curse_effect(self_participant, enemy_participant, effect: Dictionary) -> void:
	var self_name = self_participant.creature_data.get("name", "?")
	var enemy_data = enemy_participant.creature_data
	var enemy_name = enemy_data.get("name", "?")
	
	var curse_type = effect.get("curse_type", "")
	var curse_name = effect.get("name", curse_type)
	
	if curse_type.is_empty():
		return
	
	# 既存の呪いがあるかチェック
	var existing_curse = enemy_data.get("curse", {})
	if not existing_curse.is_empty():
		print("【戦闘終了時効果】%s は既に呪いを持っているため付与できない" % enemy_name)
		return
	
	# 呪い付与
	enemy_data["curse"] = {
		"curse_type": curse_type,
		"name": curse_name,
		"params": {}
	}
	
	print("【戦闘終了時効果】%s が %s に呪い\"%s\"を付与" % [self_name, enemy_name, curse_name])


## MHP減少（サムハイン等）
## @return Dictionary {target_died: bool, damage: int}
static func _apply_reduce_mhp(self_participant, enemy_participant, effect: Dictionary) -> Dictionary:
	var result = {"target_died": false, "damage": 0}
	
	var self_name = self_participant.creature_data.get("name", "?")
	var self_data = self_participant.creature_data
	var enemy_data = enemy_participant.creature_data
	var enemy_name = enemy_data.get("name", "?")
	
	# ダメージ量を取得
	var damage = 0
	var damage_source = effect.get("damage_source", "")
	
	if damage_source == "self_base_ap":
		# サムハイン: これの基本AP分
		damage = self_data.get("ap", 0)
	else:
		damage = effect.get("value", 0)
	
	if damage <= 0:
		return result
	
	result["damage"] = damage
	
	# MHP減少（base_up_hpを減らす）
	var base_hp = enemy_data.get("hp", 0)
	var base_up_hp = enemy_data.get("base_up_hp", 0)
	var current_mhp = base_hp + base_up_hp
	var new_mhp = max(0, current_mhp - damage)
	
	# base_up_hpを調整（基礎hpは変えない）
	enemy_data["base_up_hp"] = new_mhp - base_hp
	
	# current_hpも調整（新MHPを超えないように）
	var current_hp = enemy_participant.current_hp
	var new_current_hp = mini(current_hp, new_mhp)
	enemy_data["current_hp"] = new_current_hp
	enemy_participant.current_hp = new_current_hp
	
	print("【戦闘終了時効果】%s が %s のMHP-%d (MHP: %d→%d, HP: %d→%d)" % [
		self_name, enemy_name, damage, current_mhp, new_mhp, current_hp, new_current_hp
	])
	
	# 死亡判定
	if new_mhp <= 0 or new_current_hp <= 0:
		print("【戦闘終了時効果】%s は死亡" % enemy_name)
		result["target_died"] = true
		enemy_data["current_hp"] = 0
		enemy_participant.current_hp = 0
	
	return result


## 戦闘地レベルアップ（レーシィ等）
static func _apply_level_up_battle_land(self_participant, effect: Dictionary, context: Dictionary) -> void:
	var self_name = self_participant.creature_data.get("name", "?")
	var level_up_value = effect.get("value", 1)
	
	var board_system = context.get("board_system")
	var tile_info = context.get("tile_info", {})
	var tile_index = tile_info.get("index", -1)
	
	if not board_system or tile_index < 0:
		print("【戦闘終了時効果】%s - 土地レベルアップ失敗（タイル情報なし）" % self_name)
		return
	
	# 現在のレベルを取得
	var current_level = tile_info.get("level", 1)
	var max_level = 5
	
	if current_level >= max_level:
		print("【戦闘終了時効果】%s - 土地レベルは既に最大（Lv%d）" % [self_name, current_level])
		return
	
	# レベルアップ
	var new_level = mini(current_level + level_up_value, max_level)
	
	if board_system.has_method("set_tile_level"):
		board_system.set_tile_level(tile_index, new_level)
	elif board_system.tile_data_manager and board_system.tile_data_manager.has_method("set_tile_level"):
		board_system.tile_data_manager.set_tile_level(tile_index, new_level)
	else:
		# 直接tile_nodesを更新
		var tile = board_system.tile_nodes.get(tile_index)
		if tile and "level" in tile:
			tile.level = new_level
	
	print("【戦闘終了時効果】%s - 戦闘地レベルアップ (Lv%d→Lv%d)" % [self_name, current_level, new_level])


# =============================================================================
# 無効化チェック
# =============================================================================

## ナチュラルワールドによる無効化チェック
static func _is_battle_end_nullified(game_stats: Dictionary) -> bool:
	return SpellWorldCurse.is_trigger_disabled("on_battle_end", game_stats)
