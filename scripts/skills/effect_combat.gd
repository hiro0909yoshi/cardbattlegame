extends SkillEffectBase
class_name EffectCombat

# 戦闘系効果の実装クラス
# 強打、先制、貫通などの戦闘時効果を処理

# 強打効果の適用
func apply_power_strike(creature_stats: Dictionary, battle_context: Dictionary) -> Dictionary:
	var modified_stats = creature_stats.duplicate()
	var condition_checker = ConditionChecker.new()
	
	# 強打条件を満たしているか確認
	if condition_checker.check_power_strike(creature_stats, battle_context):
		var base_ap = modified_stats.get("ap", 0)
		var multiplier = 1.5  # デフォルトは1.5倍
		
		# ability_parsedから倍率を取得（将来的な拡張用）
		var ability_parsed = creature_stats.get("ability_parsed", {})
		var effects = ability_parsed.get("effects", [])
		for effect in effects:
			if effect.get("effect_type") == "power_strike":
				multiplier = effect.get("multiplier", 1.5)
				break
		
		modified_stats.ap = int(base_ap * multiplier)
		modified_stats.power_strike_applied = true
		
		# ログシステムに記録（安全な方法）
		if battle_context.has("log_system") and battle_context.log_system:
			var condition_text = _get_condition_text(creature_stats)
			battle_context.log_system.log_power_strike(
				creature_stats.get("name", "不明"),
				base_ap,
				modified_stats.ap,
				condition_text
			)
	
	return modified_stats

# 先制攻撃の判定
func check_first_strike(attacker: Dictionary, defender: Dictionary) -> Dictionary:
	var result = {
		"attacker_first": false,
		"defender_first": false,
		"simultaneous": true  # デフォルトは同時攻撃
	}
	
	var attacker_abilities = _get_keywords(attacker)
	var defender_abilities = _get_keywords(defender)
	
	var attacker_has_first = "先制" in attacker_abilities
	var defender_has_first = "先制" in defender_abilities
	
	if attacker_has_first and not defender_has_first:
		result.attacker_first = true
		result.simultaneous = false
	elif defender_has_first and not attacker_has_first:
		result.defender_first = true
		result.simultaneous = false
	# 両方先制持ちなら同時攻撃のまま
	
	return result

# 貫通効果の計算
func apply_penetration(damage: int, defender: Dictionary, battle_field: Dictionary) -> int:
	var attacker_abilities = _get_keywords(defender)  # 攻撃側の能力を確認
	
	if "貫通" in attacker_abilities:
		# 土地によるHP上昇分を無視
		var land_hp_bonus = battle_field.get("hp_bonus", 0)
		if land_hp_bonus > 0:
			print("貫通発動！土地HP上昇分 %d を無視" % land_hp_bonus)
		return damage  # ダメージをそのまま返す
	
	# 貫通なしなら通常計算
	return damage

# 無効化の判定と適用
func apply_nullification(attack_data: Dictionary, defender: Dictionary) -> Dictionary:
	var modified_attack = attack_data.duplicate()
	var condition_checker = ConditionChecker.new()
	
	# 無効化判定用のコンテキスト作成
	var nullify_context = {
		"attack_type": attack_data.get("type", "normal"),
		"attacker_st": attack_data.get("st", 0),
		"attacker_element": attack_data.get("element", ""),
		"attacker_mhp": attack_data.get("mhp", 0)
	}
	
	if condition_checker.check_nullify(defender, nullify_context):
		modified_attack.nullified = true
		modified_attack.damage = 0
		print("攻撃が無効化された！")
	
	return modified_attack

# 反射効果の適用
func apply_reflection(damage: int, defender: Dictionary, attack_type: String = "normal") -> Dictionary:
	var result = {
		"reflected": false,
		"reflected_damage": 0,
		"original_damage": damage
	}
	
	var defender_abilities = _get_keywords(defender)
	
	# 通常攻撃の反射
	if "反射" in defender_abilities and attack_type == "normal":
		result.reflected = true
		result.reflected_damage = int(damage / 2.0)  # 半分を反射
		print("反射発動！ %d ダメージを反射" % result.reflected_damage)
	
	# 巻物の反射
	elif "反射[巻物]" in defender_abilities and attack_type == "scroll":
		result.reflected = true
		result.reflected_damage = damage  # 全部反射
		print("巻物反射発動！ %d ダメージを反射" % result.reflected_damage)
	
	return result

# 再生効果の適用
func apply_regeneration(creature: Dictionary, _turn_context: Dictionary) -> int:
	var heal_amount = 0
	var abilities = _get_keywords(creature)
	
	if "再生" in abilities:
		var max_hp = creature.get("mhp", 0)
		var current_hp = creature.get("hp", 0)
		
		# 再生量を計算（最大HPの20%、または固定値）
		heal_amount = max_hp * 0.2
		
		# ability_parsedから詳細設定を取得
		var ability_parsed = creature.get("ability_parsed", {})
		var effects = ability_parsed.get("effects", [])
		for effect in effects:
			if effect.get("effect_type") == "regenerate":
				heal_amount = effect.get("value", heal_amount)
				break
		
		heal_amount = min(heal_amount, max_hp - current_hp)  # 最大HPを超えない
		
		if heal_amount > 0:
			print("再生発動！ HP %d 回復" % heal_amount)
	
	return int(heal_amount)

# 即死効果の判定と適用
func apply_instant_death(attacker: Dictionary, _defender: Dictionary, battle_context: Dictionary) -> bool:
	var condition_checker = ConditionChecker.new()
	var instant_death_result = condition_checker.check_instant_death(attacker, battle_context)
	
	if instant_death_result.can_instant_death:
		var probability = instant_death_result.probability
		var roll = randi() % 100
		
		if roll < probability:
			print("即死発動！（確率 %d%%）" % probability)
			return true
	
	return false

# 援護効果の処理
func apply_support(creature: Dictionary, support_creatures: Array) -> Dictionary:
	var modified_stats = creature.duplicate()
	var abilities = _get_keywords(creature)
	
	if "援護" in abilities:
		for supporter in support_creatures:
			var support_element = supporter.get("element", "")
			var support_ap = supporter.get("ap", 0)
			var support_hp = supporter.get("hp", 0)
			
			# ability_parsedから援護条件を確認
			var ability_parsed = creature.get("ability_parsed", {})
			var effects = ability_parsed.get("effects", [])
			
			for effect in effects:
				if effect.get("effect_type") == "support":
					var allowed_elements = effect.get("elements", [])
					if allowed_elements.is_empty() or support_element in allowed_elements:
						modified_stats.ap += int(support_ap / 2.0)  # 援護は半分の効果
						modified_stats.hp += int(support_hp / 2.0)
						print("援護発動！ %s から AP+%d, HP+%d" % [
							supporter.get("name", ""), int(support_ap/2.0), int(support_hp/2.0)
						])
	
	return modified_stats

# 防御型の効果適用
func apply_defender_bonus(creature: Dictionary, battle_context: Dictionary) -> Dictionary:
	var modified_stats = creature.duplicate()
	var abilities = _get_keywords(creature)
	
	if "防御型" in abilities and not battle_context.get("is_attacker", false):
		# 防御時のボーナスを適用
		var ability_parsed = creature.get("ability_parsed", {})
		var effects = ability_parsed.get("effects", [])
		
		for effect in effects:
			if effect.get("effect_type") == "defender":
				var ap_bonus = effect.get("ap_bonus", 0)
				var hp_bonus = effect.get("hp_bonus", 0)
				var ap_override = effect.get("ap_override", -1)
				
				if ap_override > 0:
					modified_stats.ap = ap_override
				else:
					modified_stats.ap += ap_bonus
				
				modified_stats.hp += hp_bonus
				print("防御型発動！")
				break
	
	return modified_stats

# 条件をテキストに変換（ログ用）
func _get_condition_text(creature_stats: Dictionary) -> String:
	var ability_parsed = creature_stats.get("ability_parsed", {})
	var keyword_conditions = ability_parsed.get("keyword_conditions", {})
	var keyword_cond_data = keyword_conditions.get("強打", {})
	
	var cond_type = keyword_cond_data.get("condition_type", "")
	match cond_type:
		"mhp_below":
			return "MHP%d以下" % keyword_cond_data.get("value", 0)
		"mhp_above":
			return "MHP%d以上" % keyword_cond_data.get("value", 0)
		"enemy_element":
			return "%s属性の敵" % keyword_cond_data.get("element", "")
		"on_element_land":
			var elements = keyword_cond_data.get("elements", [])
			return "%s土地" % "/".join(elements)
		"has_all_elements":
			return "火水地風全て"
		"enemy_no_item":
			return "敵アイテムなし"
		"with_weapon":
			return "武器使用時"
		"adjacent_ally_land":
			return "隣が自領地"
		_:
			return "特殊条件"

# キーワード能力の取得（ヘルパー関数）
func _get_keywords(creature: Dictionary) -> Array:
	var ability_parsed = creature.get("ability_parsed", {})
	return ability_parsed.get("keywords", [])

# 戦闘ダメージの最終計算
func calculate_battle_damage(attacker: Dictionary, defender: Dictionary, 
							 battle_context: Dictionary) -> Dictionary:
	var result = {
		"attacker_damage": 0,
		"defender_damage": 0,
		"attacker_destroyed": false,
		"defender_destroyed": false,
		"battle_log": []
	}
	
	# 先制判定
	var first_strike = check_first_strike(attacker, defender)
	
	# 攻撃側のステータス計算（強打含む）
	var attacker_stats = apply_power_strike(attacker, battle_context)
	var defender_stats = apply_defender_bonus(defender, battle_context)
	
	# ダメージ計算
	var attacker_ap = attacker_stats.get("ap", 0)
	var defender_ap = defender_stats.get("ap", 0)
	var attacker_hp = attacker_stats.get("hp", 0)
	var defender_hp = defender_stats.get("hp", 0)
	
	# 先制攻撃の処理
	if first_strike.attacker_first:
		result.defender_damage = attacker_ap
		result.battle_log.append("先制攻撃！")
		if defender_hp <= attacker_ap:
			result.defender_destroyed = true
			return result  # 防御側が倒れたら戦闘終了
	elif first_strike.defender_first:
		result.attacker_damage = defender_ap
		result.battle_log.append("防御側が先制攻撃！")
		if attacker_hp <= defender_ap:
			result.attacker_destroyed = true
			return result
	else:
		# 同時攻撃
		result.attacker_damage = defender_ap
		result.defender_damage = attacker_ap
	
	# 破壊判定
	result.attacker_destroyed = attacker_hp <= result.attacker_damage
	result.defender_destroyed = defender_hp <= result.defender_damage
	
	return result
