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
## - マイコロン (ID: 140): 敵攻撃で生き残った後、ランダム空地にコピー配置
##
## @version 1.1

class_name SkillBattleEndEffects



# =============================================================================
# メインエントリポイント
# =============================================================================

## 両者の戦闘終了時効果を処理
## @param attacker 攻撃側BattleParticipant
## @param defender 防御側BattleParticipant
## @param context 戦闘コンテキスト {board_system, tile_info, spell_world_curse, was_attacked}
## @return Dictionary {attacker_died: bool, defender_died: bool, spawn_info: Dictionary, activated_skills: Array}
static func process_all(attacker, defender, context: Dictionary = {}) -> Dictionary:
	var result = {
		"attacker_died": false,
		"defender_died": false,
		"spawn_info": {},  # マイコロン等のspawn情報
		"activated_skills": []  # 発動したスキル情報
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
		result["activated_skills"].append_array(attacker_result.get("activated_skills", []))
	
	# 防御側の効果を処理（対象: 攻撃側）
	if defender and defender.is_alive():
		var defender_result = _process_effects(defender, attacker, context)
		if defender_result.get("target_died", false):
			result["attacker_died"] = true
		result["activated_skills"].append_array(defender_result.get("activated_skills", []))
	
	# マイコロン: 防御側が敵攻撃で生き残った場合のspawn処理
	var board_system = context.get("board_system")
	var tile_info = context.get("tile_info", {})
	var defender_tile_index = tile_info.get("index", -1)
	var was_attacked = context.get("was_attacked", false)
	
	if defender and defender.is_alive() and was_attacked:
		var spawn_result = SkillCreatureSpawn.check_mycolon_spawn(
			defender.creature_data,
			defender_tile_index,
			was_attacked,
			board_system,
			defender.player_id
		)
		if spawn_result.get("spawned", false):
			result["spawn_info"] = spawn_result
	
	# 衰弱（plague）呪いダメージ処理
	# 攻撃側の衰弱チェック（相手=防御側のナチュラルワールドで無効化）
	if attacker and attacker.is_alive():
		var plague_result = _process_plague_damage(attacker, defender)
		if plague_result.get("triggered", false):
			result["activated_skills"].append({
				"actor": attacker,
				"skill_type": "plague_damage",
				"damage": plague_result.get("damage", 0)
			})
			if plague_result.get("destroyed", false):
				result["attacker_died"] = true
	
	# 防御側の衰弱チェック（相手=攻撃側のナチュラルワールドで無効化）
	if defender and defender.is_alive():
		var plague_result = _process_plague_damage(defender, attacker)
		if plague_result.get("triggered", false):
			result["activated_skills"].append({
				"actor": defender,
				"skill_type": "plague_damage",
				"damage": plague_result.get("damage", 0)
			})
			if plague_result.get("destroyed", false):
				result["defender_died"] = true
	
	return result


# =============================================================================
# 効果処理
# =============================================================================

## 単体の戦闘終了時効果を処理
## @param self_participant 効果発動側
## @param enemy_participant 効果対象側（敵）
## @param context 戦闘コンテキスト
## @return Dictionary {target_died: bool, activated_skills: Array}
static func _process_effects(self_participant, enemy_participant, context: Dictionary) -> Dictionary:
	var result = {"target_died": false, "activated_skills": []}
	
	# クリーチャーのeffectsを取得
	var ability_parsed = self_participant.creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", []).duplicate()
	
	# アイテムのeffectsも追加
	var items = self_participant.creature_data.get("items", [])
	print("【戦闘終了時効果】%sのアイテム数: %d" % [self_participant.creature_data.get("name", "?"), items.size()])
	for item in items:
		var item_effects = item.get("effect_parsed", {}).get("effects", [])
		print("  アイテム: %s, effects数: %d" % [item.get("name", "?"), item_effects.size()])
		for item_effect in item_effects:
			# アイテム情報を付加（表示用）
			var effect_copy = item_effect.duplicate()
			effect_copy["_item_name"] = item.get("name", "")
			effects.append(effect_copy)
			print("    effect_type: %s, trigger: %s, triggers: %s" % [item_effect.get("effect_type", ""), item_effect.get("trigger", ""), item_effect.get("triggers", [])])
	
	for effect in effects:
		# trigger または triggers をチェック
		if not _has_trigger(effect, "on_battle_end"):
			continue
		
		# ムラサメ等による無効化チェック（敵が存在する場合）
		if enemy_participant and _is_effect_nullified_by_enemy(effect, enemy_participant.creature_data):
			var nullified_item_name = effect.get("_item_name", "")
			var skill_name = effect.get("effect_type", "能力")
			if nullified_item_name:
				print("【無効化】%sの%sがムラサメ等により無効化" % [nullified_item_name, skill_name])
			continue
		
		var effect_type = effect.get("effect_type", "")
		var target = effect.get("target", "")
		var item_name = effect.get("_item_name", "")
		
		# 土地対象の効果（レーシィ等）
		if effect_type == "level_up_battle_land":
			if _apply_level_up_battle_land(self_participant, effect, context):
				result["activated_skills"].append({"actor": self_participant, "skill_type": effect_type})
			continue
		
		# シルバープロウ: 戦闘勝利時に土地レベルアップ
		if effect_type == "level_up_on_win":
			var condition = effect.get("condition", "")
			# 勝利条件チェック
			# 攻撃側: 敵を倒した場合
			# 防御側: 敵を倒した場合（攻撃側が死亡）
			var is_winner = false
			var self_name = self_participant.creature_data.get("name", "?")
			var enemy_alive = enemy_participant and enemy_participant.is_alive()
			var self_alive = self_participant.is_alive()
			
			print("【シルバープロウチェック】%s: is_attacker=%s, self_alive=%s, enemy_alive=%s" % [self_name, self_participant.is_attacker, self_alive, enemy_alive])
			
			if self_participant.is_attacker and not enemy_alive:
				is_winner = true
				print("  → 攻撃側勝利判定")
			elif not self_participant.is_attacker and self_alive and not enemy_alive:
				is_winner = true
				print("  → 防御側勝利判定")
			
			if condition == "win" and is_winner:
				print("  → 勝利条件成立、土地レベルアップ実行")
				if _apply_level_up_battle_land(self_participant, effect, context):
					result["activated_skills"].append({"actor": self_participant, "skill_type": effect_type, "item_name": item_name})
			else:
				print("  → 勝利条件不成立 (condition=%s, is_winner=%s)" % [condition, is_winner])
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
					result["activated_skills"].append({"actor": self_participant, "skill_type": effect_type})
					if swap_result.get("target_died", false):
						result["target_died"] = true
			
			"apply_curse":
				if target == "enemy":
					var curse_name = _apply_curse_effect(self_participant, enemy_participant, effect)
					if curse_name:
						result["activated_skills"].append({"actor": self_participant, "skill_type": "apply_curse", "curse_name": curse_name})
			
			"reduce_enemy_mhp":
				if target == "enemy":
					var reduce_result = _apply_reduce_mhp(self_participant, enemy_participant, effect)
					result["activated_skills"].append({"actor": self_participant, "skill_type": effect_type})
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
## @return 呪いを付与できた場合は呪い名、失敗時は空文字
static func _apply_curse_effect(self_participant, enemy_participant, effect: Dictionary) -> String:
	var self_name = self_participant.creature_data.get("name", "?")
	var enemy_data = enemy_participant.creature_data
	var enemy_name = enemy_data.get("name", "?")
	
	var curse_type = effect.get("curse_type", "")
	var curse_name = effect.get("name", curse_type)
	
	if curse_type.is_empty():
		return ""
	
	# 既存の呪いがあるかチェック
	var existing_curse = enemy_data.get("curse", {})
	if not existing_curse.is_empty():
		print("【戦闘終了時効果】%s は既に呪いを持っているため付与できない" % enemy_name)
		return ""
	
	# 呪い付与
	enemy_data["curse"] = {
		"curse_type": curse_type,
		"name": curse_name,
		"params": {}
	}
	
	print("【戦闘終了時効果】%s が %s に呪い\"%s\"を付与" % [self_name, enemy_name, curse_name])
	return curse_name


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
## @return 成功した場合true
static func _apply_level_up_battle_land(self_participant, effect: Dictionary, context: Dictionary) -> bool:
	var self_name = self_participant.creature_data.get("name", "?")
	var level_up_value = effect.get("value", 1)
	
	var board_system = context.get("board_system")
	var tile_info = context.get("tile_info", {})
	var tile_index = tile_info.get("index", -1)
	
	if not board_system or tile_index < 0:
		print("【戦闘終了時効果】%s - 土地レベルアップ失敗（タイル情報なし）" % self_name)
		return false
	
	# 現在のレベルを取得
	var current_level = tile_info.get("level", 1)
	var max_level = 5
	
	if current_level >= max_level:
		print("【戦闘終了時効果】%s - 土地レベルは既に最大（Lv%d）" % [self_name, current_level])
		return false
	
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
	return true


# =============================================================================
# 無効化チェック
# =============================================================================

## ナチュラルワールドによる無効化チェック
static func _is_battle_end_nullified(game_stats: Dictionary) -> bool:
	return SpellWorldCurse.is_trigger_disabled("on_battle_end", game_stats)


# =============================================================================
# ヘルパー関数
# =============================================================================

## 効果が指定したtriggerを持つかチェック
## trigger（単一）またはtriggers（配列）をサポート
static func _has_trigger(effect: Dictionary, target_trigger: String) -> bool:
	# 単一triggerをチェック
	var trigger = effect.get("trigger", "")
	if trigger == target_trigger:
		return true
	
	# 配列triggersをチェック
	var triggers = effect.get("triggers", [])
	return target_trigger in triggers


## 効果が無効化されているかチェック（ムラサメ等）
## 効果のtriggersのいずれかがnullify_triggersに含まれていれば無効化
static func _is_effect_nullified_by_enemy(effect: Dictionary, enemy_data: Dictionary) -> bool:
	# 敵のnullify_triggersを取得（クリーチャー能力 + アイテム）
	var enemy_nullify_triggers = []
	
	# クリーチャー能力
	var enemy_ability = enemy_data.get("ability_parsed", {})
	enemy_nullify_triggers.append_array(enemy_ability.get("nullify_triggers", []))
	
	# アイテム
	var enemy_items = enemy_data.get("items", [])
	for item in enemy_items:
		var item_parsed = item.get("effect_parsed", {})
		enemy_nullify_triggers.append_array(item_parsed.get("nullify_triggers", []))
	
	if enemy_nullify_triggers.is_empty():
		return false
	
	# 効果のtriggersをチェック
	var effect_triggers = effect.get("triggers", [])
	var single_trigger = effect.get("trigger", "")
	if not single_trigger.is_empty():
		effect_triggers = effect_triggers.duplicate()
		effect_triggers.append(single_trigger)
	
	for trigger in effect_triggers:
		if trigger in enemy_nullify_triggers:
			return true
	
	return false


# =============================================================================
# 衰弱（Plague）呪いダメージ処理
# =============================================================================

## 衰弱呪いをチェックしてダメージを適用
## @param self_participant 衰弱を持っている可能性のある参加者
## @param enemy_participant 相手（ナチュラルワールド無効化チェック用）
## @return Dictionary {triggered: bool, damage: int, destroyed: bool, old_hp: int, new_hp: int}
static func _process_plague_damage(self_participant, enemy_participant) -> Dictionary:
	var result = {
		"triggered": false,
		"damage": 0,
		"destroyed": false,
		"old_hp": 0,
		"new_hp": 0,
		"max_hp": 0
	}
	
	if not self_participant:
		return result
	
	var creature_data = self_participant.creature_data
	
	# 呪いチェック
	var curse = creature_data.get("curse", {})
	if curse.get("curse_type") != "plague":
		return result
	
	# 相手がナチュラルワールド等で on_battle_end を無効化していないかチェック
	if enemy_participant:
		var enemy_data = enemy_participant.creature_data
		# 衰弱を擬似的なeffectとして扱い、on_battle_endトリガーを持つとみなす
		var plague_effect = {"triggers": ["on_battle_end"]}
		if _is_effect_nullified_by_enemy(plague_effect, enemy_data):
			print("【衰弱無効化】%sの衰弱が相手のアイテム/能力により無効化" % creature_data.get("name", "?"))
			return result
	
	result["triggered"] = true
	
	# MHP計算
	var base_hp = creature_data.get("hp", 0)
	var base_up_hp = creature_data.get("base_up_hp", 0)
	var max_hp = base_hp + base_up_hp
	result["max_hp"] = max_hp
	
	# ダメージ計算（MHP/2 切り上げ）
	var damage = ceili(float(max_hp) / 2.0)
	result["damage"] = damage
	
	# current_hp取得
	var current_hp = self_participant.current_hp
	result["old_hp"] = current_hp
	
	# ダメージ適用
	var new_hp = max(0, current_hp - damage)
	self_participant.current_hp = new_hp
	creature_data["current_hp"] = new_hp
	result["new_hp"] = new_hp
	
	print("【衰弱ダメージ】%s に %d ダメージ (HP: %d → %d / MHP: %d)" % [
		creature_data.get("name", "?"), damage, current_hp, new_hp, max_hp
	])
	
	# 撃破判定
	if new_hp <= 0:
		result["destroyed"] = true
		print("【衰弱】%s は倒された！" % creature_data.get("name", "?"))
	
	return result
